import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AddFriendsScreen extends StatefulWidget {
  const AddFriendsScreen({super.key});

  @override
  State<AddFriendsScreen> createState() => _AddFriendsScreenState();
}

class _AddFriendsScreenState extends State<AddFriendsScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String _searchQuery = '';
  final bool _isLoading = false;
  final Map<String, String> _requestStatus = {}; // userId -> status
  final Map<String, String> _processingRequests = {}; // Track ongoing requests

  @override
  void initState() {
    super.initState();
    _loadExistingRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Load existing friend requests and friendships
  Future<void> _loadExistingRequests() async {
    if (_currentUser == null) return;

    try {
      // Load sent requests
      final sentRequests = await _firestore
          .collection('friend_requests')
          .where('senderId', isEqualTo: _currentUser.uid)
          .get();

      for (final doc in sentRequests.docs) {
        final data = doc.data();
        setState(() {
          _requestStatus[data['receiverId']] = data['status'];
        });
      }

      // Load received requests
      final receivedRequests = await _firestore
          .collection('friend_requests')
          .where('receiverId', isEqualTo: _currentUser.uid)
          .where('status', isEqualTo: 'accepted')
          .get();

      for (final doc in receivedRequests.docs) {
        final data = doc.data();
        setState(() {
          _requestStatus[data['senderId']] = 'accepted';
        });
      }

      // Load existing friendships
      final friendsDoc = await _firestore
          .collection('friends')
          .doc(_currentUser.uid)
          .get();

      if (friendsDoc.exists) {
        final friends = friendsDoc.data()?['friends'] as Map<String, dynamic>? ?? {};
        for (final friendId in friends.keys) {
          setState(() {
            _requestStatus[friendId] = 'accepted';
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading existing requests: $e');
      }
    }
  }

  Future<void> _sendFriendRequest(String receiverId) async {
    if (_isLoading || _currentUser == null || _processingRequests.containsKey(receiverId)) return;

    setState(() {
      _processingRequests[receiverId] = 'sending';
    });

    try {
      // Check if request already exists
      final existingRequest = await _firestore
          .collection('friend_requests')
          .where('senderId', isEqualTo: _currentUser.uid)
          .where('receiverId', isEqualTo: receiverId)
          .limit(1)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        _showSnackBar('Friend request already sent', isError: true);
        return;
      }

      // Get sender info for notification
      final senderDoc = await _firestore.collection('users').doc(_currentUser.uid).get();
      final senderData = senderDoc.data();
      if (senderData == null) return;
      
      final senderName = '${senderData['firstName']} ${senderData['lastName']}'.trim();

      // Create friend request
      await _firestore.collection('friend_requests').add({
        'senderId': _currentUser.uid,
        'receiverId': receiverId,
        'senderName': senderName,
        'senderImage': senderData['profilePictureUrl'] ?? '',
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Create notification for receiver
      await _firestore.collection('notifications').add({
        'type': 'friend_request',
        'targetUserId': receiverId,
        'triggeredByUserId': _currentUser.uid,
        'triggeredByName': senderName,
        'title': 'New Friend Request',
        'body': '$senderName sent you a friend request',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        'friendRequestId': existingRequest.docs.isNotEmpty ? existingRequest.docs.first.id : null,
      });

      // Update receiver's unread count
      await _firestore.collection('users').doc(receiverId).update({
        'unreadNotificationCount': FieldValue.increment(1),
      });

      setState(() {
        _requestStatus[receiverId] = 'pending';
      });

      _showSnackBar('Friend request sent to $senderName');
    } catch (e) {
      _showSnackBar('Failed to send request: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        _processingRequests.remove(receiverId);
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildUserListItem(DocumentSnapshot user) {
    final data = user.data()! as Map<String, dynamic>;
    final userId = user.id;
    final profilePictureUrl = data['profilePictureUrl'] as String?;
    final firstName = data['firstName'] as String? ?? '';
    final lastName = data['lastName'] as String? ?? '';
    final email = data['email'] as String? ?? '';
    final displayName = '$firstName $lastName'.trim();
    final isCurrentUser = userId == _currentUser?.uid;
    final requestStatus = _requestStatus[userId];
    final isProcessing = _processingRequests.containsKey(userId);

    if (isCurrentUser) return const SizedBox();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: GestureDetector(
          onTap: () => _navigateToProfile(userId),
          child: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.blue.shade100,
            backgroundImage: profilePictureUrl?.isNotEmpty == true
                ? CachedNetworkImageProvider(profilePictureUrl!)
                : null,
            child: profilePictureUrl?.isEmpty != false
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
        ),
        title: Text(
          displayName.isNotEmpty ? displayName : 'Unknown User',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          email,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
        trailing: _buildActionButton(userId, requestStatus, isProcessing),
        onTap: () => _navigateToProfile(userId),
      ),
    );
  }

  Widget _buildActionButton(String userId, String? status, bool isProcessing) {
    if (isProcessing) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    switch (status) {
      case 'pending':
        return FilledButton.tonal(
          onPressed: null,
          child: const Text(
            'Request Sent',
            style: TextStyle(fontSize: 12),
          ),
        );
      case 'accepted':
        return FilledButton.tonal(
          onPressed: null,
          child: const Text(
            'Friends',
            style: TextStyle(fontSize: 12),
          ),
        );
      default:
        return FilledButton(
          onPressed: () => _sendFriendRequest(userId),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
          ),
          child: const Text(
            'Add Friend',
            style: TextStyle(fontSize: 12),
          ),
        );
  }
}

  void _navigateToProfile(String userId) {
    try {
      context.push('/userProfile/$userId'); 
    } catch (e) {
      _showSnackBar('Profile navigation not available', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Disable default back behavior
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        // Navigate to friends screen when back button is pressed
        context.go('/friends');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Add Friends',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/friends'),
          ),
          elevation: 0,
        ),
        body: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    border: InputBorder.none,
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                ),
              ),
            ),

            // Users List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _searchQuery.isEmpty
                    ? _firestore.collection('users').limit(100).snapshots()
                    : _firestore
                        .collection('users')
                        .where('searchIndex', arrayContains: _searchQuery)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading users',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final users = snapshot.data?.docs ?? [];
                  final filteredUsers = users.where((user) => user.id != _currentUser?.uid).toList();

                  if (filteredUsers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No other users found'
                                : 'No users found for "$_searchQuery"',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      return _buildUserListItem(filteredUsers[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}