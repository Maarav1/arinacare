import 'dart:async';
// ignore: unused_import
import 'package:arina_cave/screens/feed_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_linkify/flutter_linkify.dart';

// Constants for better maintainability
class AppConstants {
  static const String appName = 'ArinaCave';
  static const Duration adRefreshInterval = Duration(minutes: 5);
  static const Duration buttonLoadingDelay = Duration(milliseconds: 300);
  static const int maxPostsInitialLoad = 20;
  static const int postsPerPage = 10;
  static const int maxCommentLength = 500;
  static const int maxPostLength = 2000;
  static const int maxNestedCommentDepth = 5;

  static const String bannerAdId = 'ca-app-pub-1472609237394607/7118264698';
  static const String interstitialAdId = 'ca-app-pub-1472609237394607/5863485201';

  // Error messages
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorNetwork = 'Network error. Please check your connection.';
  static const String errorPostDelete = 'Unable to delete post. Please try again.';
  static const String errorLikePost = 'Unable to like post. Please try again.';
  static const String errorAddComment = 'Unable to add comment. Please try again.';
  static const String errorLikeComment = 'Unable to like comment. Please try again.';
  static const String successPostDelete = 'Post deleted successfully';

  // Notification types
  static const String notificationLikePost = 'like_post';
  static const String notificationLikeComment = 'like_comment';
  static const String notificationCommentPost = 'comment_post';
  static const String notificationCommentComment = 'comment_comment';
  static const String notificationMention = 'mention';
}

class NewsConstants {
  static const String bannerAdUnitId = 'ca-app-pub-1472609237394607/8084106825';
  static const String interstitialAdUnitId = 'ca-app-pub-1472609237394607/3819175757';
}

// Enhanced utility functions
class AppUtils {
  static String formatTimeAgo(Timestamp timestamp) {
    final now = DateTime.now();
    final postTime = timestamp.toDate();
    final difference = now.difference(postTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    }
    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    }
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static bool isTextTooLong(String text, int maxLength) {
    return text.length > maxLength;
  }

  static String generateCommentId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${UniqueKey().toString().replaceAll('[#]', '').replaceAll(']', '')}';
  }

  static List<String> extractMentions(String text) {
    final mentionRegex = RegExp(r'@(\w+)');
    return mentionRegex
        .allMatches(text)
        .map((match) => match.group(1)!)
        .toList();
  }
}

// ----------------------- Linkable Text Widget -----------------------
class LinkableText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  const LinkableText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Linkify(
        onOpen: (link) async {
          if (await canLaunchUrl(Uri.parse(link.url))) {
            await launchUrl(Uri.parse(link.url));
          }
        },
        text: text,
        style: style ?? const TextStyle(fontSize: 16, height: 1.4),
        textAlign: textAlign,
        linkStyle: TextStyle(
          color: Colors.blue.shade700,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
// App Lifecycle Handler
class LifecycleEventHandler extends WidgetsBindingObserver {
  final AsyncCallback resumeCallBack;
  final AsyncCallback suspendCallBack;

  LifecycleEventHandler({
    required this.resumeCallBack,
    required this.suspendCallBack,
  });

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        await resumeCallBack();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        await suspendCallBack();
        break;
    }
  }
}

class AdManager {
  static BannerAd? _bannerAd;
  static InterstitialAd? _interstitialAd;
  static bool _isBannerAdLoaded = false;
  static bool _isInterstitialAdLoaded = false;
  static bool _isInterstitialLoading = false;

  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    // Pre-load an interstitial ad on app start
    _loadInterstitialAd();
  }

  static Future<BannerAd?> loadBannerAd() async {
    try {
      _bannerAd?.dispose();
      _isBannerAdLoaded = false;

      _bannerAd = BannerAd(
        adUnitId: AppConstants.bannerAdId,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (Ad ad) {
            _isBannerAdLoaded = true;
          },
          onAdFailedToLoad: (Ad ad, LoadAdError error) {
            _isBannerAdLoaded = false;
            ad.dispose();
            Future.delayed(const Duration(seconds: 3), () => loadBannerAd());
          },
        ),
      );

      await _bannerAd?.load();
      return _bannerAd;
    } catch (e) {
      _isBannerAdLoaded = false;
      return null;
    }
  }

static Future<void> _loadInterstitialAd() async {
    // Prevent multiple simultaneous loading attempts
    if (_isInterstitialLoading || _isInterstitialAdLoaded) {
      return;
    }

    _isInterstitialLoading = true;
    
    try {
      await InterstitialAd.load(
        adUnitId: AppConstants.interstitialAdId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            _interstitialAd = ad;
            _isInterstitialAdLoaded = true;
            _isInterstitialLoading = false;

            // Set up full screen content callbacks
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (InterstitialAd ad) {
                // Ad displayed successfully
              },
              onAdDismissedFullScreenContent: (InterstitialAd ad) {
                ad.dispose();
                _interstitialAd = null;
                _isInterstitialAdLoaded = false;
                // Load a new ad for next time
                _loadInterstitialAd();
              },
              onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
                ad.dispose();
                _interstitialAd = null;
                _isInterstitialAdLoaded = false;
                _isInterstitialLoading = false;
                // Retry loading after delay
                Future.delayed(const Duration(seconds: 30), _loadInterstitialAd);
              },
            );
          },
          onAdFailedToLoad: (LoadAdError error) {
            _interstitialAd = null;
            _isInterstitialAdLoaded = false;
            _isInterstitialLoading = false;
            // Retry loading after delay
            Future.delayed(const Duration(seconds: 30), _loadInterstitialAd);
          },
        ),
      );
    } catch (e) {
      _isInterstitialAdLoaded = false;
      _isInterstitialLoading = false;
      // Retry loading after delay
      Future.delayed(const Duration(seconds: 30), _loadInterstitialAd);
    }
  }

  static void showInterstitialAd() {
    if (_isInterstitialAdLoaded && _interstitialAd != null) {
      try {
        _interstitialAd!.show();
      } catch (e) {
        // If showing fails, try to load a new one
        _loadInterstitialAd();
      }
    } else {
      // If no ad is ready, load one for next time
      _loadInterstitialAd();
    }
  }

  static Widget getBannerAdWidget() {
    if (_isBannerAdLoaded && _bannerAd != null) {
      return Container(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        alignment: Alignment.center,
        child: AdWidget(ad: _bannerAd!),
      );
    } else {
      // If banner isn't loaded, try to load it and show placeholder
      if (!_isBannerAdLoaded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          loadBannerAd();
        });
      }
      return _buildAdPlaceholder();
    }
  }

  static Widget _buildAdPlaceholder() {
    return Container(
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: const Center(
        child: Text(
          'Welcome to ArinaCave',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  static bool get isBannerAdLoaded => _isBannerAdLoaded;
  static bool get isInterstitialAdLoaded => _isInterstitialAdLoaded;

  static void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _isBannerAdLoaded = false;
    _isInterstitialAdLoaded = false;
    _isInterstitialLoading = false;
  }
}

// Enhanced notification system
class NotificationManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> sendNotification({
    required String type,
    required String targetUserId,
    required String triggeredByUserId,
    required String postId,
    String? commentId,
    String? parentCommentId,
    String? message,
  }) async {
    try {
      if (targetUserId == triggeredByUserId) return;

      final triggeredByUserDoc =
          await _firestore.collection('users').doc(triggeredByUserId).get();
      final triggeredByName =
          triggeredByUserDoc.data()?['fullName'] ?? 'Someone';

      String notificationTitle = '';
      String notificationBody = '';

      switch (type) {
        case AppConstants.notificationLikePost:
          notificationTitle = 'New Like';
          notificationBody = '$triggeredByName liked your post';
          break;
        case AppConstants.notificationLikeComment:
          notificationTitle = 'New Like';
          notificationBody = '$triggeredByName liked your comment';
          break;
        case AppConstants.notificationCommentPost:
          notificationTitle = 'New Comment';
          notificationBody = '$triggeredByName commented on your post';
          break;
        case AppConstants.notificationCommentComment:
          notificationTitle = 'New Reply';
          notificationBody = '$triggeredByName replied to your comment';
          break;
        case AppConstants.notificationMention:
          notificationTitle = 'You were mentioned';
          notificationBody = '$triggeredByName mentioned you in a comment';
          break;
      }

      await _firestore.collection('notifications').add({
        'type': type,
        'targetUserId': targetUserId,
        'triggeredByUserId': triggeredByUserId,
        'triggeredByName': triggeredByName,
        'postId': postId,
        'commentId': commentId,
        'parentCommentId': parentCommentId,
        'title': notificationTitle,
        'body': notificationBody,
        'message': message,
        'isRead': false,
        'timestamp': DateTime.now(),
      });

      await _firestore.collection('users').doc(targetUserId).update({
        'unreadNotificationCount': FieldValue.increment(1),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error sending notification: $e');
      }
    }
  }

  static Future<void> markAllNotificationsAsRead(String userId) async {
    final querySnapshot =
        await _firestore
            .collection('notifications')
            .where('targetUserId', isEqualTo: userId)
            .where('isRead', isEqualTo: false)
            .get();

    final batch = _firestore.batch();
    for (final doc in querySnapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();

    await _firestore.collection('users').doc(userId).update({
      'unreadNotificationCount': 0,
    });
  }
}

class CommentManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Map<String, dynamic> createComment({
    required String text,
    required String userId,
    required String userName,
    required String userEmail,
    required String profilePictureUrl,
    String? parentCommentId,
    int depth = 0,
  }) {
    return {
      'id': AppUtils.generateCommentId(),
      'text': text,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'profilePictureUrl': profilePictureUrl,
      'parentCommentId': parentCommentId,
      'depth': depth,
      'timestamp': DateTime.now().toIso8601String(),
      'likes': 0,
      'likedBy': [],
      'replies': [],
      'replyCount': 0,
      'isExpanded': false,
    };
  }

  static Future<void> updateCommentExpansion({
    required String postId,
    required String commentId,
    required bool isExpanded,
  }) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);
      final postDoc = await postRef.get();

      if (!postDoc.exists) throw Exception('Post not found');

      final currentComments = List<Map<String, dynamic>>.from(
        postDoc['comments'] ?? [],
      );
      final updatedComments = _updateCommentExpansionInTree(
        currentComments,
        commentId,
        isExpanded,
      );

      await postRef.update({'comments': updatedComments});
    } catch (e) {
      if (kDebugMode) {
        print('Error updating comment expansion: $e');
      }
      rethrow;
    }
  }

  static List<Map<String, dynamic>> _updateCommentExpansionInTree(
    List<Map<String, dynamic>> comments,
    String commentId,
    bool isExpanded,
  ) {
    return comments.map((comment) {
      if (comment['id'] == commentId) {
        return {...comment, 'isExpanded': isExpanded};
      } else if (comment['replies'] != null && comment['replies'].isNotEmpty) {
        return {
          ...comment,
          'replies': _updateCommentExpansionInTree(
            List<Map<String, dynamic>>.from(comment['replies']),
            commentId,
            isExpanded,
          ),
        };
      }
      return comment;
    }).toList();
  }

  static Future<void> addCommentToPost({
    required String postId,
    required Map<String, dynamic> comment,
    required String triggeredByUserId,
  }) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);
      final postDoc = await postRef.get();

      if (!postDoc.exists) throw Exception('Post not found');

      final currentComments = List<Map<String, dynamic>>.from(
        postDoc['comments'] ?? [],
      );

      if (comment['parentCommentId'] != null) {
        final updatedComments = _addReplyToComment(currentComments, comment);
        await postRef.update({'comments': updatedComments});

        final parentComment = _findCommentById(
          currentComments,
          comment['parentCommentId']!,
        );
        if (parentComment != null &&
            parentComment['userId'] != triggeredByUserId) {
          await NotificationManager.sendNotification(
            type: AppConstants.notificationCommentComment,
            targetUserId: parentComment['userId'],
            triggeredByUserId: triggeredByUserId,
            postId: postId,
            commentId: comment['id'],
            parentCommentId: comment['parentCommentId'],
            message: comment['text'],
          );
        }
      } else {
        currentComments.add(comment);
        await postRef.update({'comments': currentComments});

        final postOwnerId = postDoc['userId'];
        if (postOwnerId != triggeredByUserId) {
          await NotificationManager.sendNotification(
            type: AppConstants.notificationCommentPost,
            targetUserId: postOwnerId,
            triggeredByUserId: triggeredByUserId,
            postId: postId,
            commentId: comment['id'],
            message: comment['text'],
          );
        }
      }

      final mentions = AppUtils.extractMentions(comment['text']);
      for (final mention in mentions) {
        final mentionedUserQuery =
            await _firestore
                .collection('users')
                .where('userName', isEqualTo: mention)
                .get();

        if (mentionedUserQuery.docs.isNotEmpty) {
          final mentionedUser = mentionedUserQuery.docs.first;
          if (mentionedUser.id != triggeredByUserId) {
            await NotificationManager.sendNotification(
              type: AppConstants.notificationMention,
              targetUserId: mentionedUser.id,
              triggeredByUserId: triggeredByUserId,
              postId: postId,
              commentId: comment['id'],
              message: comment['text'],
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error adding comment: $e');
      }
      rethrow;
    }
  }

  static List<Map<String, dynamic>> _addReplyToComment(
    List<Map<String, dynamic>> comments,
    Map<String, dynamic> newReply,
  ) {
    return comments.map((comment) {
      if (comment['id'] == newReply['parentCommentId']) {
        final replies = List<Map<String, dynamic>>.from(
          comment['replies'] ?? [],
        );
        replies.insert(0, newReply); // Add at beginning for newest first
        return {
          ...comment,
          'replies': replies,
          'replyCount': (comment['replyCount'] ?? 0) + 1,
        };
      } else if (comment['replies'] != null && comment['replies'].isNotEmpty) {
        return {
          ...comment,
          'replies': _addReplyToComment(
            List<Map<String, dynamic>>.from(comment['replies']),
            newReply,
          ),
        };
      }
      return comment;
    }).toList();
  }

  static Map<String, dynamic>? _findCommentById(
    List<Map<String, dynamic>> comments,
    String commentId,
  ) {
    for (final comment in comments) {
      if (comment['id'] == commentId) return comment;
      if (comment['replies'] != null && comment['replies'].isNotEmpty) {
        final found = _findCommentById(
          List<Map<String, dynamic>>.from(comment['replies']),
          commentId,
        );
        if (found != null) return found;
      }
    }
    return null;
  }

  static int getTopLevelCommentCount(List<Map<String, dynamic>> comments) {
    return comments.length;
  }

  static int getNestedCommentCount(Map<String, dynamic> comment) {
    int count = comment['replyCount'] ?? 0;
    final replies = List<Map<String, dynamic>>.from(comment['replies'] ?? []);
    for (final reply in replies) {
      count += getNestedCommentCount(reply);
    }
    return count;
  }

  static List<Map<String, dynamic>> flattenComments(
    List<Map<String, dynamic>> comments,
  ) {
    final List<Map<String, dynamic>> flattened = [];

    void addComments(List<Map<String, dynamic>> commentList, int currentDepth) {
      for (final comment in commentList) {
        flattened.add({...comment, 'displayDepth': currentDepth});
        if (comment['replies'] != null &&
            comment['replies'].isNotEmpty &&
            comment['isExpanded'] == true) {
          addComments(
            List<Map<String, dynamic>>.from(comment['replies']),
            currentDepth + 1,
          );
        }
      }
    }

    addComments(comments, 0);
    return flattened;
  }
}

class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: AppConstants.bannerAdId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _isBannerAdReady = false;
          Future.delayed(const Duration(seconds: 3), _loadBannerAd);
        },
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      width: double.infinity,
      alignment: Alignment.center,
      child: _isBannerAdReady && _bannerAd != null
          ? AdWidget(ad: _bannerAd!)
          : _buildAdPlaceholder(),
    );
  }

  Widget _buildAdPlaceholder() {
    return Container(
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: const Center(
        child: Text(
          'Welcome to ArinaCave',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
}

// Enhanced Home Screen with notification badge
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _scaffoldKey = GlobalKey<ScaffoldMessengerState>();

  bool _isLoading = false;
  Timer? _adTimer;
  final ScrollController _scrollController = ScrollController();
  final Set<String> _expandedPosts = <String>{};

  BannerAd? _bannerAd;

  // Local state for likes to prevent screen refresh
  final Map<String, bool> _localLikeStates = {};
  final Map<String, int> _localLikeCounts = {};

    @override
  void initState() {
    super.initState();
    _initializeApp();
    _setupNotificationListener();
    _loadBannerAd();
    _setupAds(); // Direct loading, no AdManager
  }

  Future<void> _initializeApp() async {
    await MobileAds.instance.initialize(); // Initialize directly
    _startAdTimer();
    _setupOnlineStatus();
  }

  void _setupAds() {
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: NewsConstants.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          // No setState here - we'll use a different approach
          if (mounted) {
            // Use a more targeted approach to update just the banner
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
              });
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          // Retry after delay without rebuilding entire screen
          Future.delayed(const Duration(seconds: 30), _loadBannerAd);
        },
      ),
    )..load();
  }

   void _startAdTimer() {
    _adTimer?.cancel();

    // Show ad every 5 minutes
    _adTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      AdManager.showInterstitialAd();
    });
  }

  void _setupOnlineStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _firestore.collection('users').doc(user.uid).update({
        'isOnline': true,
        'lastSeen': DateTime.now(),
      });

      WidgetsBinding.instance.addObserver(
        LifecycleEventHandler(
          resumeCallBack: () async {
            await _firestore.collection('users').doc(user.uid).update({
              'isOnline': true,
              'lastSeen': DateTime.now(),
            });
          },
          suspendCallBack: () async {
            await _firestore.collection('users').doc(user.uid).update({
              'isOnline': false,
              'lastSeen': DateTime.now(),
            });
          },
        ),
      );
    }
  }

  void _setupNotificationListener() {
    if (_currentUser == null) return;

    _firestore
        .collection('notifications')
        .where('targetUserId', isEqualTo: _currentUser.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            setState(() {});
          }
        });
  }

  void _handleButtonAction(String routeName) {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    Future.delayed(AppConstants.buttonLoadingDelay, () {
      if (mounted) {
        setState(() => _isLoading = false);
        context.push(routeName);
      }
    });
  }

  // Fixed like function - no screen refresh
  Future<void> _toggleLike(DocumentSnapshot post) async {
    final postId = post.id;
    
    // Immediate local update for better UX
    final currentLiked = _localLikeStates[postId] ?? 
        List<String>.from(post['likedBy'] ?? []).contains(_currentUser?.uid);
    final currentLikes = _localLikeCounts[postId] ?? post['likes'] ?? 0;
    
    // Update local state only - no setState to prevent screen refresh
    _localLikeStates[postId] = !currentLiked;
    _localLikeCounts[postId] = currentLiked ? currentLikes - 1 : currentLikes + 1;

    try {
      final postRef = _firestore.collection('posts').doc(postId);
      
      await postRef.update({
        'likedBy': currentLiked
            ? FieldValue.arrayRemove([_currentUser?.uid])
            : FieldValue.arrayUnion([_currentUser?.uid]),
        'likes': FieldValue.increment(currentLiked ? -1 : 1),
      });

      // Send notification if liked (not if unliked)
      if (!currentLiked && post['userId'] != _currentUser?.uid) {
        await NotificationManager.sendNotification(
          type: AppConstants.notificationLikePost,
          targetUserId: post['userId'],
          triggeredByUserId: _currentUser!.uid,
          postId: postId,
        );
      }

    } catch (e) {
      // Revert local changes on error
      _localLikeStates[postId] = currentLiked;
      _localLikeCounts[postId] = currentLikes;
      
      if (mounted) {
        AppUtils.showSnackBar(
          context,
          AppConstants.errorLikePost,
          isError: true,
        );
      }
    }
  }

  void _navigateToComments(String postId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HomeCommentsScreen(postId: postId)),
    );
  }

  void _togglePostExpansion(String postId) {
    setState(() {
      if (_expandedPosts.contains(postId)) {
        _expandedPosts.remove(postId);
      } else {
        _expandedPosts.add(postId);
      }
    });
  }

  Widget _buildFeatureButton({
    required IconData icon,
    required String label,
    required String route,
    MaterialColor? color,
  }) {
    final buttonColor = color ?? Colors.blue;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [buttonColor.shade100, buttonColor.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, size: 24),
            onPressed: () => _handleButtonAction(route),
            color: buttonColor.shade700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: buttonColor.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileButton() {
  return FutureBuilder<DocumentSnapshot>(
    future: _firestore.collection('users').doc(_currentUser?.uid).get(),
    builder: (context, snapshot) {
      String? profileImageUrl;
      bool isOnline = false;

      if (snapshot.hasData && snapshot.data!.exists) {
        profileImageUrl = snapshot.data!['profilePictureUrl'];
        isOnline = snapshot.data!['isOnline'] ?? false;
      }

      return Column(
        children: [
          GestureDetector(
            onTap: () => _handleButtonAction('/profile'),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade100, Colors.blue.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.transparent,
                    backgroundImage: profileImageUrl != null
                        ? CachedNetworkImageProvider(profileImageUrl)
                        : null,
                    child: profileImageUrl == null
                        ? Icon(
                            Icons.person,
                            size: 24,
                            color: Colors.blue.shade700,
                          )
                        : null,
                  ),
                  if (isOnline) _buildOnlineIndicator(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Profile',
            style: TextStyle(
              fontSize: 10,
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    },
  );
}

Widget _buildOnlineIndicator() {
  return Positioned(
    bottom: 0,
    right: 0,
    child: Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: Colors.green,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(), // ✅ Fixed
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    ),
  );
}



  Widget _buildInboxButton() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('notifications')
              .where('targetUserId', isEqualTo: _currentUser?.uid)
              .where('isRead', isEqualTo: false)
              .snapshots(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data?.docs.length ?? 0;

        return Stack(
          children: [
            _buildFeatureButton(
              icon: Icons.inbox,
              label: 'Inbox',
              route: '/inbox',
              color: Colors.blue,
            ),
            if (unreadCount > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildFriendsButton() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade100, Colors.purple.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withValues(),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.people_alt, size: 24),
                onPressed: () => _handleButtonAction('/friends'),
                color: Colors.purple.shade700,
              ),
              StreamBuilder<QuerySnapshot>(
                stream:
                    _firestore
                        .collection('friendRequests')
                        .where('receiverId', isEqualTo: _currentUser?.uid)
                        .where('status', isEqualTo: 'pending')
                        .snapshots(),
                builder: (context, snapshot) {
                  final requestCount = snapshot.data?.docs.length ?? 0;

                  if (requestCount > 0) {
                    return Positioned(
                      top: 5,
                      right: 5,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          requestCount > 9 ? '9+' : requestCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Friends',
          style: TextStyle(
            fontSize: 10,
            color: Colors.purple.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _adTimer?.cancel();
    _bannerAd?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldKey,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 80,
                child: ElevatedButton.icon(
                  onPressed: () => _handleButtonAction('/feed'),
                  icon: const Icon(Icons.article, size: 16),
                  label: const Text('Posts', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Arina',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  Text(
                    'Cave',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _showMoreOptions(context),
                tooltip: 'Menu',
              ),
            ],
          ),
          automaticallyImplyLeading: false,
          elevation: 2,
          backgroundColor: Colors.white,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFriendsButton(),
                  _buildFeatureButton(
                    icon: Icons.message,
                    label: 'Messages',
                    route: '/messages',
                    color: Colors.blue,
                  ),
                  _buildFeatureButton(
                    icon: Icons.online_prediction,
                    label: 'Online',
                    route: '/online',
                    color: Colors.green,
                  ),
                  _buildInboxButton(),
                  _buildProfileButton(),
                ],
              ),
            ),
            const Divider(thickness: 1, height: 1),
            Expanded(
              child: Stack(
                children: [
                  _PostsStreamBuilder(
                    scrollController: _scrollController,
                    expandedPosts: _expandedPosts,
                    onToggleExpansion: _togglePostExpansion,
                    onLike: _toggleLike,
                    onComment: _navigateToComments,
                    onDelete: _handleDeletePost,
                    localLikeStates: _localLikeStates,
                    localLikeCounts: _localLikeCounts,
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: AdBannerWidget(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleDeletePost(BuildContext context, DocumentSnapshot post) {
    _showDeleteDialog(post);
  }

  void _showMoreOptions(BuildContext context) {
  // Navigate to full screen MenuScreen instead of showing bottom sheet
  context.push('/menu');
}

  Future<void> _showDeleteDialog(DocumentSnapshot post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Post'),
            content: const Text(
              'Are you sure you want to delete this post? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _deletePost(post);
    }
  }

  Future<void> _deletePost(DocumentSnapshot post) async {
    try {
      await post.reference.delete();
      if (mounted) {
        AppUtils.showSnackBar(context, AppConstants.successPostDelete);
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(
          context,
          AppConstants.errorPostDelete,
          isError: true,
        );
      }
    }
  }
}

// Enhanced Posts Stream Builder
class _PostsStreamBuilder extends StatefulWidget {
  final ScrollController scrollController;
  final Set<String> expandedPosts;
  final Function(String) onToggleExpansion;
  final Function(DocumentSnapshot) onLike;
  final Function(String) onComment;
  final Function(BuildContext, DocumentSnapshot) onDelete;
  final Map<String, bool> localLikeStates;
  final Map<String, int> localLikeCounts;

  const _PostsStreamBuilder({
    required this.scrollController,
    required this.expandedPosts,
    required this.onToggleExpansion,
    required this.onLike,
    required this.onComment,
    required this.onDelete,
    required this.localLikeStates,
    required this.localLikeCounts,
  });

  @override
  State<_PostsStreamBuilder> createState() => _PostsStreamBuilderState();
}

class _PostsStreamBuilderState extends State<_PostsStreamBuilder> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerLoader();
        }

        if (snapshot.hasError) {
          return _buildErrorWidget(
            'Failed to load posts. Please pull to refresh.',
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final posts = snapshot.data!.docs;

        return RefreshIndicator(
  onRefresh: () async {
    setState(() {});
  },
  child: Container(
    color: Colors.black, //  background for the entire posts area
    child: ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final postId = post.id;
        
        // Use local state if available, otherwise use post data
        final isLiked = widget.localLikeStates[postId] ?? 
            List<String>.from(post['likedBy'] ?? []).contains(_currentUser?.uid);
        final likes = widget.localLikeCounts[postId] ?? post['likes'] ?? 0;
        
        final comments = List<Map<String, dynamic>>.from(
          post['comments'] ?? [],
        );
        final topLevelCommentsCount = 
            CommentManager.getTopLevelCommentCount(comments);
        final isCurrentUser = post['userId'] == _currentUser?.uid;
        final isExpanded = widget.expandedPosts.contains(post.id);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced margin to show more blue
          child: _PostCard(
            post: post,
            isLiked: isLiked,
            likes: likes,
            commentsCount: topLevelCommentsCount,
            isCurrentUser: isCurrentUser,
            isExpanded: isExpanded,
            onToggleExpansion: () => widget.onToggleExpansion(post.id),
            onLike: () => widget.onLike(post),
            onComment: () => widget.onComment(post.id),
            onDelete: () => widget.onDelete(context, post),
          ),
        );
      }
    ),
  ),
);
      },
    );
  }

  Widget _buildShimmerLoader() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(radius: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              height: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 100,
                              height: 12,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    height: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Container(width: 200, height: 14, color: Colors.white),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {});
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.feed, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Loading posts .\nTap "Feed" to create your first post!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// Post Header Component
class _PostHeader extends StatelessWidget {
  final DocumentSnapshot post;
  final bool isCurrentUser;
  final VoidCallback onDelete;

  const _PostHeader({
    required this.post,
    required this.isCurrentUser,
    required this.onDelete,
  });

  @override
Widget build(BuildContext context) {
  return Row(
    children: [
      FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(post['userId'])
            .get(),
        builder: (context, userSnapshot) {
          String? profileImageUrl;
          String userName = 'Anonymous';

          if (userSnapshot.hasData && userSnapshot.data!.exists) {
            final userData = userSnapshot.data!;
            profileImageUrl = userData['profilePictureUrl'];
            userName = userData['firstName'] ??
                userData['email']?.toString().split('@')[0] ??
                'Anonymous';
          }

          return GestureDetector(
            onTap: () {
              context.push('/userProfile?userId=${post['userId']}');
            },
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blue.shade100,
              backgroundImage: profileImageUrl != null
                  ? CachedNetworkImageProvider(profileImageUrl)
                  : null,
              child: profileImageUrl == null
                  ? Text(
                      userName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          );
        },
      ),
      const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<DocumentSnapshot>(
                future:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(post['userId'])
                        .get(),
                builder: (context, userSnapshot) {
                  String userName = 'Anonymous';
                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    final userData = userSnapshot.data!;
                    userName =
                        userData['fullName'] ??
                        userData['email']?.toString().split('@')[0] ??
                        'Anonymous';
                  }
                  return Text(
                    userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
              Text(
                post['timestamp'] != null
                    ? AppUtils.formatTimeAgo(post['timestamp'] as Timestamp)
                    : '',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),

        if (isCurrentUser)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete Post'),
                      ],
                    ),
                  ),
                ],
          ),
      ],
    );
  }
}

// Post Actions Component
class _PostActions extends StatelessWidget {
  final bool isLiked;
  final int likes;
  final int commentsCount;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final String postId;

  const _PostActions({
    required this.isLiked,
    required this.likes,
    required this.commentsCount,
    required this.onLike,
    required this.onComment,
    required this.postId,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            color: isLiked ? Colors.red : Colors.grey,
          ),
          onPressed: onLike,
        ),
        Text(
          _formatCount(likes),
          style: TextStyle(
            color: isLiked ? Colors.red : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.comment),
          onPressed: onComment,
          color: Colors.grey,
        ),
        Text(
          _formatCount(commentsCount),
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        IconButton(
  icon: const Icon(Icons.share),
  onPressed: () async {
    try {
      final shareLink = 'https://maarav1.github.io/post/$postId';
      await Clipboard.setData(ClipboardData(text: shareLink));
      await SharePlus.instance.share('Check out this post: $shareLink' as ShareParams);
    } catch (e) {
      if (kDebugMode) {
        print('Error sharing post: $e');
      }
    }
  },
  color: Colors.grey,
),
      ],
    );
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
}

class _PostCard extends StatelessWidget {
  final DocumentSnapshot post;
  final bool isLiked;
  final int likes;
  final int commentsCount;
  final bool isCurrentUser;
  final bool isExpanded;
  final VoidCallback onToggleExpansion;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onDelete;

  const _PostCard({
    required this.post,
    required this.isLiked,
    required this.likes,
    required this.commentsCount,
    required this.isCurrentUser,
    required this.isExpanded,
    required this.onToggleExpansion,
    required this.onLike,
    required this.onComment,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final content = post['content'] ?? '';
    final shouldShowReadMore = content.length > 150 && !isExpanded;
    final imageUrl = post['imageUrl'] as String?;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PostHeader(
              post: post,
              isCurrentUser: isCurrentUser,
              onDelete: onDelete,
            ),
            const SizedBox(height: 16),
            
            // Text content - NOW WITH CLICKABLE LINKS
            if (content.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinkableText(
                    text: isExpanded
                        ? content
                        : content.substring(
                            0,
                            shouldShowReadMore ? 150 : content.length,
                          ),
                  ),
                  if (shouldShowReadMore)
                    GestureDetector(
                      onTap: onToggleExpansion,
                      child: Text(
                        'Read more',
                        style: TextStyle(
                          color: Colors.blue.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            
            // Image - only show if URL exists and is not empty
            if (imageUrl != null && imageUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    placeholder: (context, url) => Container(
                      height: 400,
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 400,
                      color: Colors.grey[200],
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Failed to load image'),
                        ],
                      ),
                    ),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 400,
                  ),
                ),
              ),
            
            _PostActions(
              isLiked: isLiked,
              likes: likes,
              commentsCount: commentsCount,
              onLike: onLike,
              onComment: onComment,
              postId: post.id,
            ),
          ],
        ),
      ),
    );
  }
}

// Home Comments Screen (Full Page) - UNCHANGED
class HomeCommentsScreen extends StatefulWidget {
  final String postId;

  const HomeCommentsScreen({super.key, required this.postId});

  @override
  State<HomeCommentsScreen> createState() => _HomeCommentsScreenState();
}

class _HomeCommentsScreenState extends State<HomeCommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FocusNode _commentFocusNode = FocusNode();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Don't auto-focus keyboard on init
  }

  Future<void> _addComment() async {
  if (_commentController.text.trim().isEmpty || _currentUser == null) return;

  if (AppUtils.isTextTooLong(
    _commentController.text,
    AppConstants.maxCommentLength,
  )) {
    // Check mounted before using context
    if (mounted) {
      AppUtils.showSnackBar(
        context,
        'Comment is too long. Maximum ${AppConstants.maxCommentLength} characters allowed.',
        isError: true,
      );
    }
    return;
  }

  setState(() => _isSubmitting = true);

  try {
    final userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser.uid)
            .get();

    final String profilePictureUrl =
        userDoc.data()?['profilePictureUrl'] ?? '';
    final String fullName =
        userDoc.data()?['fullName'] ??
        _currentUser.email?.split('@')[0] ??
        'Unknown User';

    final comment = CommentManager.createComment(
      text: _commentController.text.trim(),
      userId: _currentUser.uid,
      userName: fullName,
      userEmail: _currentUser.email ?? '',
      profilePictureUrl: profilePictureUrl,
    );

    await CommentManager.addCommentToPost(
      postId: widget.postId,
      comment: comment,
      triggeredByUserId: _currentUser.uid,
    );

    _commentController.clear();
    
    // Check mounted before using context
    if (mounted) {
      AppUtils.showSnackBar(context, 'Comment added!');
    }
  } catch (e) {
    // Check mounted before using context
    if (mounted) {
      AppUtils.showSnackBar(
        context,
        AppConstants.errorAddComment,
        isError: true,
      );
    }
  } finally {
    // Check mounted before using setState
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }
}

  Future<void> _toggleCommentExpansion(Map<String, dynamic> comment) async {
  try {
    final newExpansionState = !(comment['isExpanded'] ?? false);
    await CommentManager.updateCommentExpansion(
      postId: widget.postId,
      commentId: comment['id'],
      isExpanded: newExpansionState,
    );
  } catch (e) {
    // Check if mounted before using context
    if (mounted) {
      AppUtils.showSnackBar(
        context,
        'Failed to toggle replies',
        isError: true,
      );
    }
  }
}

  Future<void> _toggleCommentLike(Map<String, dynamic> comment) async {
  try {
    final postRef = _firestore.collection('posts').doc(widget.postId);
    final likedBy = List<String>.from(comment['likedBy'] ?? []);
    final isLiked = likedBy.contains(_currentUser?.uid);

    final updatedComment = Map<String, dynamic>.from(comment);
    final currentLikedBy = List<String>.from(comment['likedBy'] ?? []);

    if (isLiked) {
      currentLikedBy.remove(_currentUser?.uid);
    } else {
      if (_currentUser?.uid != null) {
        currentLikedBy.add(_currentUser!.uid);
      }
    }

    updatedComment['likedBy'] = currentLikedBy;
    updatedComment['likes'] = isLiked ? (comment['likes'] ?? 1) - 1 : (comment['likes'] ?? 0) + 1;

    final postDoc = await postRef.get();
    final currentComments = List<Map<String, dynamic>>.from(
      postDoc['comments'] ?? [],
    );

    final updatedComments = _updateCommentInTree(currentComments, updatedComment);
    await postRef.update({'comments': updatedComments});

    if (!isLiked && comment['userId'] != _currentUser?.uid) {
      await NotificationManager.sendNotification(
        type: AppConstants.notificationLikeComment,
        targetUserId: comment['userId'],
        triggeredByUserId: _currentUser!.uid,
        postId: widget.postId,
        commentId: comment['id'],
      );
    }
  } catch (e) {
    // Check if mounted before using context
    if (mounted) {
      AppUtils.showSnackBar(
        context,
        AppConstants.errorLikeComment,
        isError: true,
      );
    }
  }
}
  List<Map<String, dynamic>> _updateCommentInTree(
    List<Map<String, dynamic>> comments,
    Map<String, dynamic> updatedComment,
  ) {
    return comments.map((comment) {
      if (comment['id'] == updatedComment['id']) {
        return updatedComment;
      } else if (comment['replies'] != null) {
        return {
          ...comment,
          'replies': _updateCommentInTree(
            List<Map<String, dynamic>>.from(comment['replies']),
            updatedComment,
          ),
        };
      }
      return comment;
    }).toList();
  }

  void _navigateToReplyScreen(Map<String, dynamic> comment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomeReplyScreen(
          postId: widget.postId,
          parentComment: comment,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('posts')
                      .doc(widget.postId)
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final comments = List<Map<String, dynamic>>.from(
                  snapshot.data!['comments'] ?? [],
                );

                // Sort comments by timestamp (newest first)
                comments.sort((a, b) {
                  final timeA = DateTime.parse(a['timestamp']);
                  final timeB = DateTime.parse(b['timestamp']);
                  return timeB.compareTo(timeA);
                });

                final flattenedComments = CommentManager.flattenComments(
                  comments,
                );

                if (flattenedComments.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No comments yet',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        Text(
                          'Be the first to comment!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: flattenedComments.length,
                  itemBuilder: (context, index) {
                    final comment = flattenedComments[index];
                    final timestamp = DateTime.parse(comment['timestamp']);
                    final isLiked = List<String>.from(comment['likedBy'] ?? []).contains(_currentUser?.uid);
                    final likes = comment['likes'] ?? 0;
                    final depth = comment['displayDepth'] ?? 0;
                    final hasReplies = (comment['replyCount'] ?? 0) > 0;
                    final isExpanded = comment['isExpanded'] ?? false;
                    final replyCount = comment['replyCount'] ?? 0;

                    if (depth > 0 && !_isParentExpanded(flattenedComments, index)) {
                      return const SizedBox.shrink();
                    }

                    return HomeCommentTile(
                      comment: comment,
                      timestamp: timestamp,
                      isLiked: isLiked,
                      likes: likes,
                      depth: depth,
                      hasReplies: hasReplies,
                      isExpanded: isExpanded,
                      replyCount: replyCount,
                      onLike: () => _toggleCommentLike(comment),
                      onReply: () => _navigateToReplyScreen(comment),
                      onToggleExpansion: () => _toggleCommentExpansion(comment),
                    );
                  },
                );
              },
            ),
          ),
          
          // Comment input at bottom
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, -2),
                  blurRadius: 4,
                  color: Colors.black.withValues(),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _commentFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _addComment(),
                  ),
                ),
                const SizedBox(width: 8),
                _isSubmitting
                    ? const CircularProgressIndicator()
                    : IconButton(
                        icon: const Icon(Icons.send, color: Colors.blue),
                        onPressed: _addComment,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isParentExpanded(List<Map<String, dynamic>> comments, int index) {
    int currentDepth = comments[index]['displayDepth'] ?? 0;
    for (int i = index - 1; i >= 0; i--) {
      if (comments[i]['displayDepth'] == currentDepth - 1) {
        return comments[i]['isExpanded'] ?? false;
      }
    }
    return false;
  }
}

// Home Reply Screen (Full Page) - UNCHANGED
class HomeReplyScreen extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> parentComment;

  const HomeReplyScreen({super.key, required this.postId, required this.parentComment});

  @override
  State<HomeReplyScreen> createState() => _HomeReplyScreenState();
}

class _HomeReplyScreenState extends State<HomeReplyScreen> {
  final TextEditingController _replyController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FocusNode _replyFocusNode = FocusNode();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Don't auto-focus keyboard on init
  }

  Future<void> _addReply() async {
  if (_replyController.text.trim().isEmpty || _currentUser == null) return;

  setState(() => _isSubmitting = true);

  try {
    final userDoc = await _firestore
        .collection('users')
        .doc(_currentUser.uid)
        .get();

    final String profilePictureUrl = userDoc.data()?['profilePictureUrl'] ?? '';
    final String fullName = userDoc.data()?['fullName'] ?? _currentUser.email?.split('@')[0] ?? 'Unknown User';

    final reply = CommentManager.createComment(
      text: _replyController.text.trim(),
      userId: _currentUser.uid,
      userName: fullName,
      userEmail: _currentUser.email ?? '',
      profilePictureUrl: profilePictureUrl,
      parentCommentId: widget.parentComment['id'],
      depth: (widget.parentComment['depth'] ?? 0) + 1,
    );

    await CommentManager.addCommentToPost(
      postId: widget.postId,
      comment: reply,
      triggeredByUserId: _currentUser.uid,
    );

    _replyController.clear();
    
    // Check if mounted before using context
    if (!mounted) return;
    
    AppUtils.showSnackBar(context, 'Reply added!');
    
    // Navigate back after successful reply
    Navigator.pop(context);
  } catch (e) {
    // Check if mounted before using context
    if (mounted) {
      AppUtils.showSnackBar(
        context,
        'Failed to add reply. Please try again.',
        isError: true,
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }
}

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reply'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Column(
        children: [
          // Parent comment at top
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: widget.parentComment['profilePictureUrl'] != null &&
                              widget.parentComment['profilePictureUrl'].isNotEmpty
                          ? CachedNetworkImageProvider(widget.parentComment['profilePictureUrl'])
                          : null,
                      backgroundColor: Colors.blueGrey.shade200,
                      child: widget.parentComment['profilePictureUrl'] == null ||
                              widget.parentComment['profilePictureUrl'].isEmpty
                          ? Text(
                              (widget.parentComment['userName'] ?? 'U')[0].toUpperCase(),
                              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.parentComment['userName'] ?? 'Unknown User',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(widget.parentComment['text']),
              ],
            ),
          ),
          
          // Replies list
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('posts').doc(widget.postId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final comments = List<Map<String, dynamic>>.from(snapshot.data!['comments'] ?? []);
                final parentComment = _findCommentWithReplies(comments, widget.parentComment['id']);
                final replies = List<Map<String, dynamic>>.from(parentComment?['replies'] ?? []);

                // Sort replies by timestamp (newest first)
                replies.sort((a, b) {
                  final timeA = DateTime.parse(a['timestamp']);
                  final timeB = DateTime.parse(b['timestamp']);
                  return timeB.compareTo(timeA);
                });

                if (replies.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No replies yet', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: replies.length,
                  itemBuilder: (context, index) {
                    final reply = replies[index];
                    final timestamp = DateTime.parse(reply['timestamp']);
                    final isLiked = List<String>.from(reply['likedBy'] ?? []).contains(_currentUser?.uid);
                    final likes = reply['likes'] ?? 0;

                    return HomeCommentTile(
                      comment: reply,
                      timestamp: timestamp,
                      isLiked: isLiked,
                      likes: likes,
                      depth: 1,
                      hasReplies: false,
                      isExpanded: false,
                      replyCount: 0,
                      onLike: () {}, // Implement like functionality if needed
                      onReply: () {}, // No nested replies in reply screen
                      onToggleExpansion: () {},
                      showReplyButton: false,
                    );
                  },
                );
              },
            ),
          ),
          
          // Reply input at bottom
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
              boxShadow: [
                BoxShadow(
                  offset: const Offset(0, -2),
                  blurRadius: 4,
                  color: Colors.black.withValues(),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    focusNode: _replyFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Write a reply...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _addReply(),
                  ),
                ),
                const SizedBox(width: 8),
                _isSubmitting
                    ? const CircularProgressIndicator()
                    : IconButton(
                        icon: const Icon(Icons.send, color: Colors.blue),
                        onPressed: _addReply,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _findCommentWithReplies(List<Map<String, dynamic>> comments, String commentId) {
    for (final comment in comments) {
      if (comment['id'] == commentId) {
        return comment;
      }
      if (comment['replies'] != null && comment['replies'].isNotEmpty) {
        final found = _findCommentWithReplies(List<Map<String, dynamic>>.from(comment['replies']), commentId);
        if (found != null) return found;
      }
    }
    return null;
  }
}

class HomeCommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  final DateTime timestamp;
  final bool isLiked;
  final int likes;
  final int depth;
  final bool hasReplies;
  final bool isExpanded;
  final int replyCount;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final VoidCallback onToggleExpansion;
  final bool showReplyButton;

  const HomeCommentTile({
    super.key,
    required this.comment,
    required this.timestamp,
    required this.isLiked,
    required this.likes,
    required this.depth,
    required this.hasReplies,
    required this.isExpanded,
    required this.replyCount,
    required this.onLike,
    required this.onReply,
    required this.onToggleExpansion,
    this.showReplyButton = true,
  });

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  @override
  Widget build(BuildContext context) {
    final leftPadding = 16.0 + (depth * 16.0);

    return Container(
      margin: EdgeInsets.only(left: leftPadding, right: 8, top: 4, bottom: 4),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: comment['profilePictureUrl'] != null &&
                            comment['profilePictureUrl'].isNotEmpty
                        ? CachedNetworkImageProvider(comment['profilePictureUrl'])
                        : null,
                    backgroundColor: Colors.blueGrey.shade200,
                    child: comment['profilePictureUrl'] == null ||
                            comment['profilePictureUrl'].isEmpty
                        ? Text(
                            (comment['userName'] ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comment['userName'] ?? 'Unknown User',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          DateFormat('MMM d, h:mm a').format(timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // REPLACED: Text widget with LinkableText for clickable links
              LinkableText(
                text: comment['text'],
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Like button
                  IconButton(
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: isLiked ? Colors.red : Colors.grey,
                    ),
                    onPressed: onLike,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                  Text(
                    likes > 0 ? _formatCount(likes) : '',
                    style: TextStyle(
                      fontSize: 12,
                      color: isLiked ? Colors.red : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Reply button
                  if (showReplyButton)
                    GestureDetector(
                      onTap: onReply,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.reply, size: 16, color: Colors.blue.shade700),
                            const SizedBox(width: 4),
                            Text(
                              'Reply',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  const SizedBox(width: 16),
                  
                  // Replies count
                  if (hasReplies && showReplyButton)
                    GestureDetector(
                      onTap: onToggleExpansion,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: isExpanded ? Colors.blue.shade100 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$replyCount ${replyCount == 1 ? 'reply' : 'replies'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isExpanded ? Colors.blue.shade700 : Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              isExpanded ? Icons.expand_less : Icons.expand_more,
                              size: 14,
                              color: isExpanded ? Colors.blue.shade700 : Colors.grey.shade700,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}