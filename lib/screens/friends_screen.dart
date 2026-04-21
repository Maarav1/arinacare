import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shimmer/shimmer.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  bool _isLoading = false;
  bool _showFriendsList = true;
  final Map<String, String> _requestStatus = {};
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_searchFocusNode.hasFocus && _searchQuery.isEmpty) {
      setState(() => _showFriendsList = true);
    }
  }

  void _onSearchChanged() {
    if (_searchDebounceTimer?.isActive ?? false) {
      _searchDebounceTimer?.cancel();
    }

    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.trim();
          _showFriendsList = _searchQuery.isEmpty;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.removeListener(_onFocusChange);
    _searchFocusNode.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  // FIXED: Added permission check and better error handling
  Future<void> _sendFriendRequest(String recipientId) async {
    if (_isLoading || _currentUser == null) return;
    
    // Don't send request to yourself
    if (recipientId == _currentUser.uid) {
      _showErrorSnackBar('You cannot send friend request to yourself');
      return;
    }

    setState(() {
      _isLoading = true;
      _requestStatus[recipientId] = 'sending';
    });

    try {
      final HttpsCallable callable = _functions.httpsCallable('sendFriendRequest');
      final result = await callable.call({
        'toUserId': recipientId,
        'currentUserId': _currentUser.uid,
      });

      if (result.data['success'] == true) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Friend request sent successfully! 🎉'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );

        setState(() {
          _requestStatus[recipientId] = 'sent';
        });
      } else {
        if (!mounted) return;
        _showErrorSnackBar('Error: ${result.data['message']}');
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error sending request: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Unexpected error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  Widget _buildFriendListItem(
    DocumentSnapshot friend, {
    required bool isCurrentFriend,
  }) {
    final data = friend.data() as Map<String, dynamic>;
    final profilePictureUrl = data['profilePictureUrl'] ?? '';
    final firstName = data['firstName'] ?? '';
    final lastName = data['lastName'] ?? '';
    final displayName = '$firstName $lastName'.trim();
    final email = data['email'] ?? '';
    final userId = friend.id;
    final requestStatus = _requestStatus[userId] ?? '';
    final isOnline = data['isOnline'] ?? false;
    final lastSeen = data['lastSeen'] != null 
        ? (data['lastSeen'] as Timestamp).toDate() 
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(),
              backgroundImage: profilePictureUrl.isNotEmpty
                  ? CachedNetworkImageProvider(profilePictureUrl)
                  : null,
              child: profilePictureUrl.isEmpty
                  ? Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    )
                  : null,
            ),
            if (isCurrentFriend && isOnline)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          displayName.isNotEmpty ? displayName : 'Unknown User',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (email.isNotEmpty)
              Text(
                email,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(),
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (isCurrentFriend)
              Text(
                isOnline 
                    ? 'Online now' 
                    : lastSeen != null 
                        ? 'Last seen ${_formatLastSeen(lastSeen)}'
                        : 'Offline',
                style: TextStyle(
                  color: isOnline ? Colors.green : Colors.grey,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: isCurrentFriend
            ? _buildFriendOptions(userId)
            : _buildFriendRequestButton(userId, requestStatus),
        onTap: () => context.push('/userProfile/${friend.id}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${(difference.inDays / 7).floor()}w ago';
  }

  Widget _buildFriendOptions(String userId) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: Theme.of(context).colorScheme.onSurface.withValues(),
      ),
      onSelected: (value) {
        if (value == 'remove') {
          _removeFriend(userId);
        } else if (value == 'message') {
          context.push('/messages?userId=$userId');
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'message',
          child: Row(
            children: [
              Icon(Icons.message, size: 20),
              SizedBox(width: 8),
              Text('Send Message'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'remove',
          child: Row(
            children: [
              Icon(Icons.person_remove, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text('Remove Friend', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFriendRequestButton(String userId, String requestStatus) {
    final buttonColor = Theme.of(context).colorScheme.primary;

    switch (requestStatus) {
      case 'sending':
        return SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(buttonColor),
          ),
        );
      case 'sent':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withValues(),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check, color: Colors.green, size: 16),
              const SizedBox(width: 4),
              Text(
                'Sent',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      case 'error':
        return IconButton(
          icon: const Icon(Icons.refresh, color: Colors.orange),
          onPressed: () => _sendFriendRequest(userId),
          tooltip: 'Retry',
        );
      default:
        return FilledButton.tonal(
          onPressed: () => _sendFriendRequest(userId),
          style: FilledButton.styleFrom(
            backgroundColor: buttonColor.withValues(),
            foregroundColor: buttonColor,
          ),
          child: const Text('Add Friend'),
        );
    }
  }

  Future<void> _removeFriend(String friendId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: const Text('Are you sure you want to remove this friend?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final batch = _firestore.batch();
        
        batch.delete(
          _firestore.collection('users').doc(_currentUser?.uid).collection('friends').doc(friendId)
        );
        batch.delete(
          _firestore.collection('users').doc(friendId).collection('friends').doc(_currentUser?.uid)
        );
        
        await batch.commit();
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Friend removed successfully'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        _showErrorSnackBar('Error removing friend: $e');
      }
    }
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: 'Search friends by name or email...',
            prefixIcon: Icon(
              Icons.search,
              color: Theme.of(context).colorScheme.onSurface.withValues(),
            ),
            border: InputBorder.none,
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: Theme.of(context).colorScheme.onSurface.withValues(),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _searchFocusNode.unfocus();
                      setState(() {
                        _searchQuery = '';
                        _showFriendsList = true;
                      });
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsCount(int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.people,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count ${count == 1 ? 'Friend' : 'Friends'}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                count == 0 
                    ? 'Start building your network!'
                    : 'Your amazing friend circle',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoader() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 16,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 120,
                        height: 12,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isSearch) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearch ? Icons.search_off : Icons.people_outline,
            size: 80,
            color: Theme.of(context).colorScheme.onSurface.withValues(),
          ),
          const SizedBox(height: 16),
          Text(
            isSearch ? 'No users found' : 'No friends yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearch 
                ? 'Try searching with different keywords'
                : 'Search for friends to start connecting!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(),
            ),
          ),
          if (!isSearch) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _showFriendsList = false;
                });
                _searchFocusNode.requestFocus();
              },
              icon: const Icon(Icons.search),
              label: const Text('Find Friends'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Friends',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          // FIXED: Changed to route to /add
          IconButton(
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: () => context.go('/add'),
            tooltip: 'Add Friends',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchField(),
          
          // Friends count section
          if (_showFriendsList)
            StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(_currentUser?.uid)
                  .collection('friends')
                  .snapshots(),
              builder: (context, friendsSnapshot) {
                final friendsCount = friendsSnapshot.data?.docs.length ?? 0;
                return _buildFriendsCount(friendsCount);
              },
            ),

          // Main content
          Expanded(
            child: _showFriendsList
                ? _buildFriendsList()
                : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .doc(_currentUser?.uid)
          .collection('friends')
          .snapshots(),
      builder: (context, friendsSnapshot) {
        if (friendsSnapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerLoader();
        }

        if (friendsSnapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading friends',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          );
        }

        final friends = friendsSnapshot.data?.docs ?? [];
        if (friends.isEmpty) {
          return _buildEmptyState(false);
        }

        return FutureBuilder<List<DocumentSnapshot>>(
          future: Future.wait(
            friends.map((friendDoc) async {
              return await _firestore
                  .collection('users')
                  .doc(friendDoc.id)
                  .get();
            }),
          ),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return _buildShimmerLoader();
            }

            if (userSnapshot.hasError) {
              return Center(child: Text('Error: ${userSnapshot.error}'));
            }

            final users = userSnapshot.data ?? [];
            return RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: users.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  return _buildFriendListItem(
                    users[index],
                    isCurrentFriend: true,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_searchQuery.isEmpty) {
      return _buildEmptyState(true);
    }

    final normalizedQuery = _searchQuery.toLowerCase();
    
    // FIXED: This is the core fix for search
    // We need to query multiple fields
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerLoader();
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.data?.docs.isEmpty ?? true) {
          return _buildEmptyState(true);
        }

        // Filter locally for better flexibility
        final allUsers = snapshot.data!.docs;
        
        final filteredUsers = allUsers.where((userDoc) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final firstName = (userData['firstName'] ?? '').toString().toLowerCase();
          final lastName = (userData['lastName'] ?? '').toString().toLowerCase();
          final email = (userData['email'] ?? '').toString().toLowerCase();
          final displayName = (userData['displayName'] ?? '').toString().toLowerCase();
          
          // Search in multiple fields
          return firstName.contains(normalizedQuery) ||
                 lastName.contains(normalizedQuery) ||
                 email.contains(normalizedQuery) ||
                 displayName.contains(normalizedQuery);
        }).toList();

        if (filteredUsers.isEmpty) {
          return _buildEmptyState(true);
        }

        return FutureBuilder<QuerySnapshot>(
          future: _firestore
              .collection('users')
              .doc(_currentUser?.uid)
              .collection('friends')
              .get(),
          builder: (context, friendsSnapshot) {
            if (friendsSnapshot.connectionState == ConnectionState.waiting) {
              return _buildShimmerLoader();
            }

            final existingFriendIds = friendsSnapshot.data?.docs
                    .map((doc) => doc.id)
                    .toList() ?? [];
            existingFriendIds.add(_currentUser?.uid ?? '');

            // Remove current user and existing friends
            final finalResults = filteredUsers
                .where((user) => !existingFriendIds.contains(user.id))
                .toList();

            if (finalResults.isEmpty) {
              return _buildEmptyState(true);
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: finalResults.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return _buildFriendListItem(
                  finalResults[index],
                  isCurrentFriend: false,
                );
              },
            );
          },
        );
      },
    );
  }
}