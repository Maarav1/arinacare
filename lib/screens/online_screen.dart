import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

class OnlineUsersScreen extends StatefulWidget {
  const OnlineUsersScreen({super.key});

  @override
  State<OnlineUsersScreen> createState() => _OnlineUsersScreenState();
}

class _OnlineUsersScreenState extends State<OnlineUsersScreen> 
    with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = 
      GlobalKey<RefreshIndicatorState>();
  
  @override
  void initState() {
    super.initState();
    _updateUserOnlineStatus(true);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateUserOnlineStatus(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _updateUserOnlineStatus(false);
    } else if (state == AppLifecycleState.resumed) {
      _updateUserOnlineStatus(true);
    }
  }

  Future<void> _updateUserOnlineStatus(bool isOnline) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'isOnline': isOnline,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error updating online status: $e');
    }
  }

  Stream<QuerySnapshot> get _onlineUsersStream {
    return _firestore
        .collection('users')
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .handleError((error) {
      debugPrint('Firestore stream error: $error');
      throw error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Online Now',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
            tooltip: 'Info',
          ),
        ],
      ),
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: () async {
          setState(() {});
        },
        child: StreamBuilder<QuerySnapshot>(
          stream: _onlineUsersStream,
          builder: (context, snapshot) {
            return Column(
              children: [
                _buildConnectionStatus(snapshot),
                Expanded(
                  child: _buildContent(snapshot),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(AsyncSnapshot<QuerySnapshot> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: Colors.blue.shade50,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Checking online users...',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (snapshot.hasError) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: Colors.orange.shade100,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 16, color: Colors.orange.shade800),
            const SizedBox(width: 8),
            Text(
              'Connection issue - Pull to refresh',
              style: TextStyle(
                color: Colors.orange.shade800,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox();
  }

  Widget _buildContent(AsyncSnapshot<QuerySnapshot> snapshot) {
    debugPrint('Connection state: ${snapshot.connectionState}');
    debugPrint('Has error: ${snapshot.hasError}');
    debugPrint('Error: ${snapshot.error}');
    debugPrint('Has data: ${snapshot.hasData}');
    debugPrint('Data length: ${snapshot.data?.docs.length ?? 0}');

    if (snapshot.connectionState == ConnectionState.waiting) {
      return _buildShimmerLoader();
    }

    if (snapshot.hasError) {
      debugPrint('Stream error: ${snapshot.error}');
      return _buildErrorState(snapshot.error.toString());
    }

    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
      return _buildEmptyState();
    }

    final onlineUsers = snapshot.data!.docs;
    final currentUserId = _auth.currentUser?.uid;

    final otherOnlineUsers = onlineUsers
        .where((user) => user.id != currentUserId)
        .toList();

    if (otherOnlineUsers.isEmpty) {
      return _buildEmptyState();
    }

    return _buildUserList(otherOnlineUsers);
  }

  Widget _buildShimmerLoader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
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
                        const SizedBox(height: 8),
                        Container(
                          width: 100,
                          height: 14,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(String error) {
    String errorMessage = 'Please check your internet connection';
    String errorTitle = 'Connection Error';

    if (error.contains('PERMISSION_DENIED')) {
      errorTitle = 'Permission Denied';
      errorMessage = 'You don\'t have permission to view online users. Please check Firestore security rules.';
    } else if (error.contains('UNAVAILABLE')) {
      errorTitle = 'Service Unavailable';
      errorMessage = 'Firestore service is temporarily unavailable. Please try again later.';
    } else if (error.contains('isOnline')) {
      errorTitle = 'Data Error';
      errorMessage = 'The "isOnline" field might not exist in your Firestore database.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              errorTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Technical details: ${error.substring(0, error.length < 100 ? error.length : 100)}...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => _refreshIndicatorKey.currentState?.show(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    if (mounted) {
                      context.pop();
                    }
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 20),
            const Text(
              'No Users Online',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'When users come online, they\'ll appear here',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later to connect with others',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _refreshIndicatorKey.currentState?.show(),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserList(List<QueryDocumentSnapshot> users) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey.shade50,
          child: Row(
            children: [
              Text(
                '${users.length} user${users.length == 1 ? '' : 's'} online',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final userData = user.data() as Map<String, dynamic>;
              return _buildUserCard(user.id, userData);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(String userId, Map<String, dynamic> userData) {
    final firstName = userData['firstName'] ?? 'User';
    final lastName = userData['lastName'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final email = userData['userEmail'] ?? userData['email'] ?? '';
    final displayName = fullName.isNotEmpty ? fullName : email.split('@')[0];
    final profilePictureUrl = userData['profilePictureUrl'];
    final lastSeen = userData['lastSeen'] != null 
        ? (userData['lastSeen'] as Timestamp).toDate()
        : DateTime.now();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToUserProfile(userId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Profile Picture with online indicator
              GestureDetector(
                onTap: () => _navigateToUserProfile(userId),
                child: Stack(
                  children: [
                    Hero(
                      tag: 'profile_image_$userId',
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: profilePictureUrl != null
                            ? CachedNetworkImageProvider(profilePictureUrl)
                            : null,
                        child: profilePictureUrl == null
                            ? const Icon(
                                Icons.person,
                                size: 24,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                    ),
                    // Online indicator
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.green.shade200,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Online now',
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatLastSeen(lastSeen),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // Action Buttons
              Row(
                children: [
                  // Message Button
                  IconButton(
                    onPressed: () async => await _startChat(userId, userData),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.message,
                        size: 20,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    tooltip: 'Send Message',
                  ),
                  // More Options
                  PopupMenuButton<String>(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.more_vert,
                        size: 20,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    onSelected: (value) => _handleMenuAction(value, userId, userData),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'message',
                        child: Row(
                          children: [
                            Icon(Icons.message, size: 20, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Send Message'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'profile',
                        child: Row(
                          children: [
                            Icon(Icons.person, size: 20, color: Colors.green),
                            SizedBox(width: 8),
                            Text('View Profile'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share, size: 20, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Share Profile'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMenuAction(String action, String userId, Map<String, dynamic> userData) {
    switch (action) {
      case 'message':
        _startChat(userId, userData);
        break;
      case 'profile':
        _navigateToUserProfile(userId);
        break;
      case 'share':
        _shareUserProfile(userId, userData);
        break;
    }
  }

  Future<void> _startChat(String userId, Map<String, dynamic> userData) async {
  final currentUser = _auth.currentUser;
  if (currentUser == null) {
    _showSnackBar('Please login to start a chat');
    return;
  }

  if (currentUser.uid == userId) {
    _showSnackBar('You cannot message yourself');
    return;
  }

  final participants = [currentUser.uid, userId]..sort();
  final chatRoomId = participants.join('_');

  try {
    if (!mounted) return;
    
    await _firestore.collection('chatRooms').doc(chatRoomId).set({
      'participants': participants,
      'participantNames': {
        currentUser.uid: _getCurrentUserName(),
        userId: userData['firstName'] ?? 'User',
      },
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    
    context.push('/chat/$chatRoomId', extra: {
      'otherUserName': userData['firstName'] ?? 'User',
      'otherUserId': userId,
    });
  } catch (e) {
    debugPrint('Error starting chat: $e');
    if (mounted) {
      _showSnackBar('Failed to start chat');
    }
  }
}

  String _getCurrentUserName() {
    final user = _auth.currentUser;
    return user?.displayName ?? user?.email?.split('@')[0] ?? 'You';
  }

  void _shareUserProfile(String userId, Map<String, dynamic> userData) {
    final firstName = userData['firstName'] ?? 'User';
    final lastName = userData['lastName'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    
    // In a real app, you would use the share package
    _showSnackBar('Share profile feature would open for $fullName');
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'Active now';
    } else if (difference.inMinutes < 60) {
      return 'Active ${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return 'Active ${difference.inHours}h ago';
    } else {
      return 'Active ${difference.inDays}d ago';
    }
  }

  void _navigateToUserProfile(String userId) {
    try {
      if (mounted) {
        context.push('/profile/$userId', extra: {
          'userId': userId,
        });
      }
    } catch (e) {
      debugPrint('Error navigating to profile: $e');
      _showSnackBar('Failed to open profile');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info, color: Colors.blue),
            SizedBox(width: 8),
            Text('Online Users Info'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This screen shows all users who are currently online.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              'Features:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Tap any user to view their profile'),
            Text('• Message button to start chatting'),
            Text('• Online status updates in real-time'),
            Text('• Pull down to refresh the list'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}