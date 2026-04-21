import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:arina_cave/screens/post_detail_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_linkify/flutter_linkify.dart';

// ----------------------- Constants -----------------------
class NewsConstants {
  static const int postsPerPage = 15;
  static const int maxPostLength = 2000;
  static const int maxCommentLength = 500;
  static const Duration refreshDuration = Duration(seconds: 30);
  static const Duration adInterval = Duration(minutes: 5);
  static const Duration postAutoDeleteDuration = Duration(days: 30); // Auto delete after 30 days

  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorNetwork = 'Please check your internet connection.';
  static const String errorPostCreate = 'Failed to create post.';
  static const String errorImageUpload = 'Failed to upload image.';
  static const String errorLike = 'Failed to like post.';
  static const String errorComment = 'Failed to add comment.';
  static const String errorDelete = 'Failed to delete post.';
  static const String errorShare = 'Failed to share post.';

  static const String successPostCreate = 'Post created successfully!';
  static const String successPostDelete = 'Post deleted successfully!';
  static const String successComment = 'Comment added!';
  static const String successShare = 'Link copied to clipboard!';

  static const String bannerAdUnitId = 'ca-app-pub-1472609237394607/7118264698';
  static const String interstitialAdUnitId = 'ca-app-pub-1472609237394607/3819175757';
}

// ----------------------- Auto Delete Service -----------------------
class PostAutoDeleteService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static void initializeAutoDelete() {
    // Schedule periodic cleanup
    Timer.periodic(const Duration(hours: 24), (timer) async {
      await _deleteOldPosts();
    });
  }

  static Future<void> _deleteOldPosts() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(NewsConstants.postAutoDeleteDuration);
      
      final query = _firestore
          .collection('posts')
          .where('timestamp', isLessThan: Timestamp.fromDate(thirtyDaysAgo));

      final snapshot = await query.get();
      
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      if (snapshot.docs.isNotEmpty) {
        if (kDebugMode) {
          print('Auto-deleted ${snapshot.docs.length} posts older than 30 days');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error auto-deleting posts: $e');
      }
    }
  }

  // Call this when creating a post to schedule auto-delete
  static Future<void> schedulePostAutoDelete(String postId) async {
    try {
      final deleteTime = DateTime.now().add(NewsConstants.postAutoDeleteDuration);
      
      await _firestore.collection('scheduledDeletes').doc(postId).set({
        'postId': postId,
        'deleteAt': Timestamp.fromDate(deleteTime),
        'scheduledAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error scheduling auto-delete: $e');
      }
    }
  }
}

// ----------------------- Linkable Text Widget -----------------------
class LinkableText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool selectable;

  const LinkableText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.selectable = true,
  });

  @override
  Widget build(BuildContext context) {
    final linkifyWidget = Linkify(
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
    );

    // If selectable is true, wrap with SelectableText
    if (selectable) {
      return SelectableLinkify(
        text: text,
        onOpen: (link) async {
          if (await canLaunchUrl(Uri.parse(link.url))) {
            await launchUrl(Uri.parse(link.url));
          }
        },
        style: style ?? const TextStyle(fontSize: 16, height: 1.4),
        textAlign: textAlign,
        linkStyle: TextStyle(
          color: Colors.blue.shade700,
          decoration: TextDecoration.underline,
        ),
      );
    }

    return linkifyWidget;
  }
}

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<NewsScreen> {
  @override
  void initState() {
    super.initState();
    _handleInitialLink();
  }

  void _handleInitialLink() {
    // Check if app was opened with a shared link
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = Uri.base;
      final postId = uri.queryParameters['post'];
      
      if (postId != null && postId.isNotEmpty) {
        // Navigate to post detail
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(postId: postId),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Your existing home screen content
      body: Container(),
    );
  }
}

// ----------------------- NewsFeedScreen -----------------------
class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  NewsFeedScreenState createState() => NewsFeedScreenState();
}

class NewsFeedScreenState extends State<NewsFeedScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final ScrollController _scrollController = ScrollController();
  final List<DocumentSnapshot> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  Timer? _refreshTimer;
  Timer? _adTimer;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  @override
  void initState() {
    super.initState();
    _loadInitialPosts();
    _scrollController.addListener(_onScroll);
    _refreshTimer = Timer.periodic(NewsConstants.refreshDuration, (_) => _refreshPosts());
    _setupAds();
    PostAutoDeleteService.initializeAutoDelete(); // Initialize auto-delete service
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _refreshTimer?.cancel();
    _adTimer?.cancel();
    _interstitialAd?.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  // ----------------------- Firestore post loading -----------------------
  Future<void> _loadInitialPosts() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final q = _firestore
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(NewsConstants.postsPerPage);

      final snap = await q.get();
      if (mounted) {
        _posts.clear();
        _posts.addAll(snap.docs);
        _lastDocument = snap.docs.isNotEmpty ? snap.docs.last : null;
        _hasMore = snap.docs.length == NewsConstants.postsPerPage;
        setState(() {});
      }
    } catch (e) {
      if (mounted) _showError(NewsConstants.errorGeneric);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    try {
      final q = _firestore
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(NewsConstants.postsPerPage);

      final snap = await q.get();
      if (mounted) {
        _posts.addAll(snap.docs);
        _lastDocument = snap.docs.isNotEmpty ? snap.docs.last : _lastDocument;
        _hasMore = snap.docs.length == NewsConstants.postsPerPage;
        setState(() {});
      }
    } catch (e) {
      if (mounted) _showError(NewsConstants.errorGeneric);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshPosts() async {
    await _loadInitialPosts();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoading) _loadMorePosts();
    }
  }

  // ----------------------- Ads Setup -----------------------
  void _setupAds() {
    _loadBannerAd();
    _setupInterstitialAds();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: NewsConstants.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _isBannerAdReady = false;
          // Retry after delay
          Future.delayed(const Duration(seconds: 3), _loadBannerAd);
        },
      ),
    )..load();
  }

  void _setupInterstitialAds() {
    _loadInterstitial();

    _adTimer = Timer.periodic(NewsConstants.adInterval, (_) async {
      if (_isInterstitialReady) {
        _interstitialAd?.show();
      } else {
        await _loadInterstitial();
      }
    });
  }

  Future<void> _loadInterstitial() async {
    _interstitialAd?.dispose();
    _isInterstitialReady = false;

    InterstitialAd.load(
      adUnitId: NewsConstants.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialReady = true;
          _interstitialAd?.setImmersiveMode(true);
          _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) async {
              ad.dispose();
              await _loadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, error) async {
              ad.dispose();
              await _loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isInterstitialReady = false;
        },
      ),
    );
  }

  // ----------------------- Helpers -----------------------
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ----------------------- Navigation / Actions -----------------------
  void _navigateToCreatePost() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const CreatePostScreen()),
    );

    if (created == true) {
      await _loadInitialPosts();
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
    }
  }

  void _navigateToUserProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UserProfileScreen(userId: userId)),
    );
  }

  void _navigateToComments(String postId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CommentsScreen(postId: postId)),
    );
  }

  Future<void> _sharePost(DocumentSnapshot post) async {
    try {
      final postId = post.id;
      final shareLink = 'https://maarav1.github.io/denis-marav/post/$postId';
      await Clipboard.setData(ClipboardData(text: shareLink));
      await SharePlus.instance.share('Check out this post: $shareLink' as ShareParams);
      _showSuccess(NewsConstants.successShare);
    } catch (e) {
      _showError(NewsConstants.errorShare);
    }
  }

  Future<void> _deletePost(DocumentSnapshot post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestore.collection('posts').doc(post.id).delete();
      // Also remove from scheduled deletes if it exists
      await _firestore.collection('scheduledDeletes').doc(post.id).delete();
      _showSuccess(NewsConstants.successPostDelete);
      await _loadInitialPosts();
    } catch (e) {
      _showError(NewsConstants.errorDelete);
    }
  }

  Future<void> _toggleLike(DocumentSnapshot post) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Unauthenticated');
      final postRef = _firestore.collection('posts').doc(post.id);

      await _firestore.runTransaction((tx) async {
        final snapshot = await tx.get(postRef);
        final likedBy = List<String>.from(snapshot.data()?['likedBy'] ?? []);
        int likes = snapshot.data()?['likes'] ?? 0;
        if (likedBy.contains(user.uid)) {
          likedBy.remove(user.uid);
          likes = (likes - 1).clamp(0, 999999999);
        } else {
          likedBy.add(user.uid);
          likes = likes + 1;
        }
        tx.update(postRef, {'likedBy': likedBy, 'likes': likes, 'updatedAt': FieldValue.serverTimestamp()});
      });
      
      // Force UI update
      if (mounted) setState(() {});
    } catch (e) {
      _showError(NewsConstants.errorLike);
    }
  }

  // ----------------------- UI -----------------------
  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Arina Feed', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      backgroundColor: Colors.blue,
      elevation: 1,
      actions: [
        IconButton(
          onPressed: _refreshPosts,
          icon: const Icon(Icons.refresh, color: Colors.white),
          tooltip: 'Refresh',
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: _navigateToCreatePost,
      backgroundColor: Colors.blue,
      child: const Icon(Icons.add, color: Colors.white),
    ),
    body: SafeArea(
      child: Container(
        color: Colors.black, // THIS MAKES THE BACKGROUND BLACK
        child: Column(
          children: [
            Expanded(child: _buildBody()),
            // Banner Ad at bottom
            if (_isBannerAdReady)
              Container(
                color: Colors.white, // Ad container also white
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                alignment: Alignment.center,
                child: AdWidget(ad: _bannerAd!),
              ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildBody() {
  if (_isLoading && _posts.isEmpty) return _buildLoadingState();
  if (_posts.isEmpty) return _buildEmptyState();

  return RefreshIndicator(
    onRefresh: _refreshPosts,
    child: Container(
      color: Colors.black,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _posts.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _posts.length) return _buildLoadingTile();
          final doc = _posts[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: PostCard(
              key: ValueKey(doc.id),
              post: doc,
              currentUserId: _auth.currentUser?.uid ?? '',
              onDelete: () => _deletePost(doc),
              onLike: () => _toggleLike(doc),
              onComment: () => _navigateToComments(doc.id),
              onShare: () => _sharePost(doc),
              onProfileTap: (userId) => _navigateToUserProfile(userId),
            ),
          );
        },
      ),
    ),
  );
}

  Widget _buildLoadingState() => const Center(child: CircularProgressIndicator());

  Widget _buildLoadingTile() => const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.feed_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('No posts yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Be the first to share something!', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Create Post'),
            onPressed: _navigateToCreatePost,
          ),
        ],
      ),
    );
  }
}

// ----------------------- PostCard Widget -----------------------
class PostCard extends StatefulWidget {
  final DocumentSnapshot post;
  final String currentUserId;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final void Function(String userId) onProfileTap;

  const PostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onDelete,
    required this.onProfileTap,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic> _userData = {};
  bool _localLiked = false;
  int _localLikes = 0;

  @override
  void initState() {
    super.initState();
    _fetchUser();
    _localLiked = _isPostLiked();
  _localLikes = (widget.post.data() as Map<String, dynamic>)['likes'] ?? 0;
  }

  Future<void> _fetchUser() async {
    try {
      final userId = widget.post['userId'] as String? ?? '';
      if (userId.isEmpty) return;
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && mounted) {
        setState(() {
          _userData = doc.data()!;
        });
      }
    } catch (e) {
      // ignore and show defaults
    }
  }

  bool _isPostLiked() {
    final likedBy = List<String>.from(widget.post['likedBy'] ?? []);
    final userId = widget.currentUserId;
    return userId.isNotEmpty && likedBy.contains(userId);
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.post.data() as Map<String, dynamic>;
    final timestamp = data['timestamp'] as Timestamp?;
    final content = data['content'] as String? ?? '';
    final imageUrl = data['imageUrl'] as String? ?? '';
    final _ = (data['likes'] ?? 0) as int;
    final comments = List<Map<String, dynamic>>.from(data['comments'] ?? []);
    final userName = _userData['fullName'] ?? data['userName'] ?? 'User';
    final profileImageUrl = _userData['profilePictureUrl'] ?? '';
    final isOnline = _userData['isOnline'] ?? false;

    final _ = _isPostLiked();
    final topLevelCommentsCount = comments.length;

    return Card(
  margin: const EdgeInsets.symmetric(vertical: 0),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  elevation: 2,
  child: Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // Header
          ListTile(
            leading: GestureDetector(
              onTap: () {
                final uid = widget.post['userId'] as String? ?? '';
                widget.onProfileTap(uid);
              },
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundImage: profileImageUrl.isNotEmpty
                        ? CachedNetworkImageProvider(profileImageUrl)
                        : null,
                    backgroundColor: Colors.blueGrey.shade200,
                    child: profileImageUrl.isEmpty
                        ? Text(userName.isNotEmpty ? userName[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  if (isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            title: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(_formatTimestamp(timestamp), style: TextStyle(color: Colors.grey.shade600)),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) {
                if (v == 'delete') widget.onDelete();
                if (v == 'share') widget.onShare();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'share', child: Row(children: [Icon(Icons.share), SizedBox(width: 8), Text('Share')])),
                if (widget.post['userId'] == widget.currentUserId)
                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
              ],
            ),
          ),

          // Content - NOW WITH CLICKABLE LINKS
          if (content.isNotEmpty)
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: SelectionArea(
      child: LinkableText(text: content),
    ),
  ),
          // Image - Increased size
          if (imageUrl.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 350,
                  placeholder: (context, url) => Container(
                    height: 350,
                    color: Colors.grey.shade200,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 350,
                    color: Colors.grey.shade200,
                    child: const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey)),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),

          // Actions
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 8),
  child: Row(
    children: [
      // Like button
      IconButton(
        icon: Icon(
          _localLiked ? Icons.favorite : Icons.favorite_border,
          color: _localLiked ? Colors.red : Colors.grey,
        ),
        onPressed: () {
          // Immediate UI update
          setState(() {
            if (_localLiked) {
              _localLikes--;
            } else {
              _localLikes++;
            }
            _localLiked = !_localLiked;
          });
          
          // Then call the actual like function
          widget.onLike();
        },
      ),
      Text(
        _formatCount(_localLikes),
        style: TextStyle(
          color: _localLiked ? Colors.red : Colors.grey,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(width: 16),
      
      // Comment button
      IconButton(
        icon: const Icon(Icons.comment_outlined),
        onPressed: widget.onComment,
        color: Colors.grey,
      ),
      Text(
        _formatCount(topLevelCommentsCount),
        style: const TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(width: 16),
      
      // Share button
      IconButton(
        icon: const Icon(Icons.share_outlined),
        onPressed: widget.onShare,
        color: Colors.grey,
      ),
      const Text(
        'Share',
        style: TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  ),
),
          const SizedBox(height: 8),
        ],
      ),
  ),
    );
  }
}

// ----------------------- CreatePostScreen -----------------------
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _controller = TextEditingController();
  File? _image;
  bool _isUploading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (pickedFile != null && mounted) {
        setState(() => _image = File(pickedFile.path));
      }
    } catch (e) {
      _showError('Failed to pick image');
    }
  }

  Future<String?> _uploadImage() async {
    if (_image == null) return null;

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('generateCloudinarySignature');
      final results = await callable();

      final signature = results.data['signature'];
      final timestamp = results.data['timestamp'].toString();
      final apiKey = results.data['api_key'];
      final cloudName = results.data['cloud_name'];
      final folder = results.data['folder'];

      final uploadUrl = 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl))
        ..fields['api_key'] = apiKey
        ..fields['timestamp'] = timestamp
        ..fields['signature'] = signature
        ..fields['folder'] = folder
        ..files.add(await http.MultipartFile.fromPath('file', _image!.path));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseData);

      if (response.statusCode == 200) {
        return jsonResponse['secure_url'];
      } else {
        throw Exception('Upload failed: ${jsonResponse['error']?['message']}');
      }
    } catch (e) {
      _showError(NewsConstants.errorImageUpload);
      return null;
    }
  }

  Future<void> _submitPost() async {
    if (_controller.text.trim().isEmpty && _image == null) {
      _showError('Please add text or image');
      return;
    }

    if (_isUploading) return;

    setState(() => _isUploading = true);

    try {
      final imageUrl = await _uploadImage();
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final postRef = await _firestore.collection('posts').add({
        'content': _controller.text.trim(),
        'imageUrl': imageUrl ?? '',
        'userId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': 0,
        'likedBy': [],
        'comments': [],
        'commentsCount': 0,
        'userName': user.displayName ?? 'User',
        'userEmail': user.email ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Schedule auto-delete for this post
      await PostAutoDeleteService.schedulePostAutoDelete(postRef.id);

      if (mounted) {
        _showSuccess(NewsConstants.successPostCreate);
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError(NewsConstants.errorPostCreate);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _controller,
                  maxLength: NewsConstants.maxPostLength,
                  minLines: 3,
                  maxLines: 8,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'What\'s happening?',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                if (_image != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_image!, height: 250, width: double.infinity, fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => setState(() => _image = null),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove photo'),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo),
                      label: const Text('Add Photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        foregroundColor: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _submitPost,
                        icon: _isUploading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                        label: Text(_isUploading ? 'Posting...' : 'Post'),
                      ),
                    ),
                  ],
                ),
                if (_isUploading) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('Uploading...', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------- Comments Screen (Full Page) -----------------------
class CommentsScreen extends StatefulWidget {
  final String postId;

  const CommentsScreen({super.key, required this.postId});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
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

  String _generateCommentId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${UniqueKey().toString().replaceAll('[#]', '').replaceAll(']', '')}';
  }

  Map<String, dynamic> _createComment({
    required String text,
    required String userId,
    required String userName,
    required String userEmail,
    required String profilePictureUrl,
    String? parentCommentId,
    int depth = 0,
  }) {
    return {
      'id': _generateCommentId(),
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
      'isExpanded': true,
    };
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty || _currentUser == null) return;
    
    if (_commentController.text.length > NewsConstants.maxCommentLength) {
      _showError('Comment is too long. Maximum ${NewsConstants.maxCommentLength} characters allowed.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(_currentUser.uid)
          .get();

      final String profilePictureUrl = userDoc.data()?['profilePictureUrl'] ?? '';
      final String fullName = userDoc.data()?['fullName'] ?? _currentUser.email?.split('@')[0] ?? 'Unknown User';

      final comment = _createComment(
        text: _commentController.text.trim(),
        userId: _currentUser.uid,
        userName: fullName,
        userEmail: _currentUser.email ?? '',
        profilePictureUrl: profilePictureUrl,
      );

      final postRef = _firestore.collection('posts').doc(widget.postId);
      final postDoc = await postRef.get();
      
      if (!postDoc.exists) throw Exception('Post not found');

      final currentComments = List<Map<String, dynamic>>.from(postDoc['comments'] ?? []);
      currentComments.add(comment);

      await postRef.update({
        'comments': currentComments,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _commentController.clear();
      _showSuccess('Comment added!');
    } catch (e) {
      _showError(NewsConstants.errorComment);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _toggleCommentExpansion(Map<String, dynamic> comment) async {
    try {
      final postRef = _firestore.collection('posts').doc(widget.postId);
      final postDoc = await postRef.get();
      
      if (!postDoc.exists) throw Exception('Post not found');

      final currentComments = List<Map<String, dynamic>>.from(postDoc['comments'] ?? []);
      final updatedComments = _updateCommentExpansionInTree(currentComments, comment['id'], !(comment['isExpanded'] ?? false));
      
      await postRef.update({'comments': updatedComments});
    } catch (e) {
      _showError('Failed to toggle replies');
    }
  }

  List<Map<String, dynamic>> _updateCommentExpansionInTree(
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

  List<Map<String, dynamic>> _flattenComments(List<Map<String, dynamic>> comments) {
    final List<Map<String, dynamic>> flattened = [];
    
    void addComments(List<Map<String, dynamic>> commentList, int currentDepth) {
      for (final comment in commentList) {
        flattened.add({...comment, 'displayDepth': currentDepth});
        if (comment['replies'] != null && comment['replies'].isNotEmpty && comment['isExpanded'] == true) {
          addComments(List<Map<String, dynamic>>.from(comment['replies']), currentDepth + 1);
        }
      }
    }
    
    addComments(comments, 0);
    return flattened;
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
      final currentComments = List<Map<String, dynamic>>.from(postDoc['comments'] ?? []);

      final updatedComments = _updateCommentInTree(currentComments, updatedComment);
      await postRef.update({'comments': updatedComments});
    } catch (e) {
      _showError('Failed to like comment');
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _navigateToReplyScreen(Map<String, dynamic> comment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReplyScreen(
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
              stream: _firestore
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

                final flattenedComments = _flattenComments(comments);

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

                    return CommentTile(
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

// ----------------------- Reply Screen (Full Page) -----------------------
class ReplyScreen extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> parentComment;

  const ReplyScreen({super.key, required this.postId, required this.parentComment});

  @override
  State<ReplyScreen> createState() => _ReplyScreenState();
}

class _ReplyScreenState extends State<ReplyScreen> {
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

  String _generateCommentId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${UniqueKey().toString().replaceAll('[#]', '').replaceAll(']', '')}';
  }

  Map<String, dynamic> _createComment({
    required String text,
    required String userId,
    required String userName,
    required String userEmail,
    required String profilePictureUrl,
    String? parentCommentId,
    int depth = 0,
  }) {
    return {
      'id': _generateCommentId(),
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
      'isExpanded': true,
    };
  }

  Future<void> _addReply() async {
    if (_replyController.text.trim().isEmpty || _currentUser == null) return;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(_currentUser.uid)
          .get();

      final String profilePictureUrl = userDoc.data()?['profilePictureUrl'] ?? '';
      final String fullName = userDoc.data()?['fullName'] ?? _currentUser.email?.split('@')[0] ?? 'Unknown User';

      final reply = _createComment(
        text: _replyController.text.trim(),
        userId: _currentUser.uid,
        userName: fullName,
        userEmail: _currentUser.email ?? '',
        profilePictureUrl: profilePictureUrl,
        parentCommentId: widget.parentComment['id'],
        depth: (widget.parentComment['depth'] ?? 0) + 1,
      );

      final postRef = _firestore.collection('posts').doc(widget.postId);
      final postDoc = await postRef.get();
      
      if (!postDoc.exists) throw Exception('Post not found');

      final currentComments = List<Map<String, dynamic>>.from(postDoc['comments'] ?? []);
      final updatedComments = _addReplyToComment(currentComments, reply);
      
      await postRef.update({'comments': updatedComments});

      _replyController.clear();
      _showSuccess('Reply added!');
      
      // Navigate back after successful reply
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Failed to add reply');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  List<Map<String, dynamic>> _addReplyToComment(
    List<Map<String, dynamic>> comments,
    Map<String, dynamic> newReply,
  ) {
    return comments.map((comment) {
      if (comment['id'] == newReply['parentCommentId']) {
        final replies = List<Map<String, dynamic>>.from(comment['replies'] ?? []);
        // Add new reply at the beginning (latest first)
        replies.insert(0, newReply);
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
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

                    return CommentTile(
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
                  color: Colors.black.withAlpha(30),
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

// ----------------------- Comment Tile -----------------------
class CommentTile extends StatelessWidget {
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

  const CommentTile({
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
             SelectionArea(
  child: LinkableText(
    text: comment['text'],
    style: const TextStyle(fontSize: 14, height: 1.4),
  ),),

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


// ----------------------- UserProfileScreen -----------------------
class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUser();
  }

  Future<void> _fetchUser() async {
    try {
      final doc = await _firestore.collection('users').doc(widget.userId).get();
      if (doc.exists) _userData = doc.data()!;
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildProfileHeader(String fullName, String profileImageUrl, bool isOnline, DateTime? lastSeen, String email) {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: profileImageUrl.isNotEmpty ? CachedNetworkImageProvider(profileImageUrl) : null,
              backgroundColor: Colors.blueGrey.shade300,
              child: profileImageUrl.isEmpty
                  ? Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))
                  : null,
            ),
            if (isOnline)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(width: 20, height: 20, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3))),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(fullName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        if (email.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(email, style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
        ],
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: isOnline ? Colors.green : Colors.grey, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(isOnline ? 'Online' : lastSeen != null ? 'Last seen ${DateFormat('MMM d, h:mm a').format(lastSeen)}' : 'Offline', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final fullName = _userData['fullName'] ?? 'User';
    final profileImageUrl = _userData['profilePictureUrl'] ?? '';
    final isOnline = _userData['isOnline'] ?? false;
    final lastSeen = _userData['lastSeen'] != null ? (_userData['lastSeen'] as Timestamp).toDate() : null;
    final email = _userData['email'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(fullName),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProfileHeader(fullName, profileImageUrl, isOnline, lastSeen, email),
              const SizedBox(height: 24),
              const Text('Posts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('posts').where('userId', isEqualTo: widget.userId).orderBy('timestamp', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No posts yet', style: TextStyle(color: Colors.grey)));
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: snapshot.data!.docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      return PostCard(
                        post: doc,
                        currentUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
                        onComment: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CommentsScreen(postId: doc.id))),
                        onDelete: () async {
                          await FirebaseFirestore.instance.collection('posts').doc(doc.id).delete();
                        },
                        onLike: () async {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) return;
                          final postRef = FirebaseFirestore.instance.collection('posts').doc(doc.id);
                          await FirebaseFirestore.instance.runTransaction((tx) async {
                            final snap = await tx.get(postRef);
                            final likedBy = List<String>.from(snap.data()?['likedBy'] ?? []);
                            int likes = snap.data()?['likes'] ?? 0;
                            if (likedBy.contains(user.uid)) {
                              likedBy.remove(user.uid);
                              likes = (likes - 1).clamp(0, 999999999);
                            } else {
                              likedBy.add(user.uid);
                              likes = likes + 1;
                            }
                            tx.update(postRef, {'likedBy': likedBy, 'likes': likes, 'updatedAt': FieldValue.serverTimestamp()});
                          });
                        },
                        onShare: () async {
                          final shareLink = 'https://maarav1.github.io/post/${doc.id}';
                          await Clipboard.setData(ClipboardData(text: shareLink));
                          await SharePlus.instance.share('Check out this post: $shareLink' as ShareParams);
                        },
                        onProfileTap: (uid) {},
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
