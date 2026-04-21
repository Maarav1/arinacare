import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'post_detail_screen.dart';
import 'friend_requests_screen.dart';
import 'notification_provider.dart'; // Make sure this import exists

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read),
            onPressed: _markAllAsRead,
            tooltip: 'Mark all as read',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear_all') {
                _clearAllNotifications();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, size: 20),
                    SizedBox(width: 8),
                    Text('Clear All'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildNotificationsList(),
    );
  }

  Widget _buildNotificationsList() {
    if (_currentUser == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Please sign in to view notifications'),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('notifications')
          .where('targetUserId', isEqualTo: _currentUser.uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('Error loading notifications'),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No notifications yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Notifications will appear here',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final notifications = snapshot.data!.docs;
        final unreadCount = notifications
            .where((doc) => !(doc.data() as Map<String, dynamic>)['isRead'])
            .length;

        return Column(
          children: [
            if (unreadCount > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: Colors.blue.shade50,
                child: Row(
                  children: [
                    Icon(Icons.circle, color: Colors.blue.shade600, size: 12),
                    const SizedBox(width: 8),
                    Text(
                      '$unreadCount unread notification${unreadCount > 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  // Force refresh by rebuilding the stream
                  setState(() {});
                },
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    return _buildNotificationItem(notifications[index]);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNotificationItem(DocumentSnapshot notification) {
    final data = notification.data() as Map<String, dynamic>;
    final isRead = data['isRead'] ?? false;
    final type = data['type'] ?? 'unknown';
    final title = data['title'] ?? 'Notification';
    final body = data['body'] ?? '';
    final timestamp = data['timestamp'] as Timestamp?;
    final triggeredByName = data['triggeredByName'] ?? 'Someone';
    final postId = data['postId'];
    final commentId = data['commentId'];
    final friendRequestId = data['friendRequestId'];

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmation(notification.id);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: isRead ? null : Colors.blue.shade50.withValues(),
        child: ListTile(
          leading: _getNotificationIcon(type),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                body,
                style: TextStyle(
                  color: isRead ? Colors.grey.shade700 : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              if (timestamp != null)
                Text(
                  _formatTimestamp(timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
          trailing: isRead 
              ? IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _showDeleteConfirmation(notification.id),
                  tooltip: 'Delete notification',
                )
              : const Icon(Icons.circle, color: Colors.blue, size: 12),
          onTap: () => _handleNotificationTap(
            notification, 
            type, 
            triggeredByName, 
            postId, 
            commentId, 
            friendRequestId
          ),
          onLongPress: () => _showNotificationOptions(notification.id),
        ),
      ),
    );
  }

  Widget _getNotificationIcon(String type) {
    Color iconColor;
    IconData iconData;

    switch (type) {
      case 'like_post':
        iconData = Icons.favorite;
        iconColor = Colors.red;
        break;
      case 'like_comment':
        iconData = Icons.favorite;
        iconColor = Colors.red;
        break;
      case 'comment_post':
        iconData = Icons.comment;
        iconColor = Colors.blue;
        break;
      case 'comment_comment':
        iconData = Icons.reply;
        iconColor = Colors.green;
        break;
      case 'mention':
        iconData = Icons.alternate_email;
        iconColor = Colors.orange;
        break;
      case 'friend_request':
        iconData = Icons.person_add;
        iconColor = Colors.purple;
        break;
      case 'friend_request_accepted':
        iconData = Icons.person;
        iconColor = Colors.green;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.grey;
    }

    return CircleAvatar(
      backgroundColor: iconColor.withAlpha(30),
      child: Icon(iconData, color: iconColor, size: 20),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final time = timestamp.toDate();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(time);
    }
  }

  void _handleNotificationTap(
    DocumentSnapshot notification, 
    String type, 
    String triggeredByName,
    String? postId, 
    String? commentId, 
    String? friendRequestId
  ) {
    final data = notification.data() as Map<String, dynamic>;
    
    // Mark as read if not already read
    if (!(data['isRead'] ?? false)) {
      _markAsRead(notification.id);
    }

    // Navigate based on notification type
    switch (type) {
      case 'friend_request':
        _showFriendRequestDialog(friendRequestId, triggeredByName);
        break;
      case 'friend_request_accepted':
        _showSuccessSnackBar('$triggeredByName accepted your friend request!');
        break;
      case 'like_post':
      case 'comment_post':
        if (postId != null) {
          _navigateToPost(postId);
        } else {
          _showSuccessSnackBar('Notification: $type');
        }
        break;
      default:
        _showSuccessSnackBar('Notification: $type');
    }
  }

  void _navigateToPost(String postId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(postId: postId),
      ),
    );
  }

  void _navigateToFriendRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FriendRequestsScreen(),
      ),
    );
  }

  void _showFriendRequestDialog(String? friendRequestId, String userName) {
    if (friendRequestId == null) {
      _navigateToFriendRequests();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Friend Request'),
        content: Text('$userName sent you a friend request'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToFriendRequests();
            },
            child: const Text('View Requests'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(String notificationId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification'),
        content: const Text('Are you sure you want to delete this notification?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _deleteNotification(notificationId);
      return true;
    }
    return false;
  }

  void _showNotificationOptions(String notificationId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(notificationId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.mark_email_read),
              title: const Text('Mark as read'),
              onTap: () {
                Navigator.pop(context);
                _markAsRead(notificationId);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
        
      // The provider will automatically update via the stream
    } catch (e) {
      if (kDebugMode) {
        print('Error marking notification as read: $e');
      }
    }
  }

  Future<void> _markAllAsRead() async {
  if (_currentUser == null) return;

  try {
    final querySnapshot = await _firestore
        .collection('notifications')
        .where('targetUserId', isEqualTo: _currentUser.uid)
        .where('isRead', isEqualTo: false)
        .get();

    if (querySnapshot.docs.isEmpty) {
      if (mounted) {
        _showSuccessSnackBar('All notifications are already read');
      }
      return;
    }

    final batch = _firestore.batch();
    for (final doc in querySnapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();

    // Update user's notification count in Firestore
    await _firestore
        .collection('users')
        .doc(_currentUser.uid)
        .update({'unreadNotificationCount': 0});

    // Check if widget is still mounted before using context
    if (!mounted) return;
    
    // Update the provider
    final notificationProvider = context.read<NotificationProvider>();
    notificationProvider.markAllAsRead();
    
    _showSuccessSnackBar('All notifications marked as read');
  } catch (e) {
    if (mounted) {
      _showErrorSnackBar('Failed to mark all as read: ${e.toString()}');
    }
  }
}

  Future<void> _clearAllNotifications() async {
  if (_currentUser == null) return;

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Clear All Notifications'),
      content: const Text('Are you sure you want to delete all notifications? This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Clear All'),
        ),
      ],
    ),
  );

  if (result == true) {
    try {
      final querySnapshot = await _firestore
          .collection('notifications')
          .where('targetUserId', isEqualTo: _currentUser.uid)
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Check if widget is still mounted before using context
      if (!mounted) return;

      // Update the provider
      final notificationProvider = context.read<NotificationProvider>();
      notificationProvider.markAllAsRead();

      _showSuccessSnackBar('All notifications cleared');
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to clear notifications: ${e.toString()}');
      }
    }
  }
}

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .delete();
          
      _showSuccessSnackBar('Notification deleted');
    } catch (e) {
      _showErrorSnackBar('Failed to delete notification');
    }
  }
}