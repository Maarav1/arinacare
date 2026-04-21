import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  late Stream<QuerySnapshot> _messagesStream;
  int _unreadCount = 0;
  final Map<String, bool> _deletingMessages = {};

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadUnreadCount();
  }

  void _loadMessages() {
    if (_currentUser == null) return;

    _messagesStream = _firestore
        .collection('messages')
        .where('recipientId', isEqualTo: _currentUser.uid)
        .orderBy('timestamp', descending: true)
        .snapshots(includeMetadataChanges: true);
  }

  void _loadUnreadCount() {
    if (_currentUser == null) return;

    _firestore
        .collection('messages')
        .where('recipientId', isEqualTo: _currentUser.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen(
          (snapshot) {
            if (mounted) {
              setState(() => _unreadCount = snapshot.docs.length);
            }
          },
          onError: (error) {
            debugPrint('Unread count error: $error');
            if (mounted) {
              setState(() => _unreadCount = 0);
            }
          },
        );
  }

  Future<void> _markAsRead(String messageId) async {
    try {
      final callable = _functions.httpsCallable('markMessageAsRead');
      await callable.call({'messageId': messageId});
    } catch (e) {
      debugPrint('Error marking message as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    if (_currentUser == null || _unreadCount == 0) return;

    try {
      final unreadMessages =
          await _firestore
              .collection('messages')
              .where('recipientId', isEqualTo: _currentUser.uid)
              .where('isRead', isEqualTo: false)
              .get();

      final batch = _firestore.batch();
      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      if (mounted) {
        setState(() => _unreadCount = 0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All messages marked as read')),
        );
      }
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      setState(() => _deletingMessages[messageId] = true);

      final callable = _functions.httpsCallable('deleteMessage');
      final result = await callable.call({'messageId': messageId});

      if (mounted && result.data['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: ${result.data['message']}'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting message: $e');
    } finally {
      if (mounted) {
        setState(() => _deletingMessages.remove(messageId));
      }
    }
  }

  void _replyToMessage(Map<String, dynamic> messageData) {
    final senderId = messageData['senderId'];
    final senderName = messageData['senderName'] ?? 'Unknown';

    context.push(
      '/messages/new',
      extra: {
        'recipientId': senderId,
        'recipientName': senderName,
        'replyTo': messageData['content'],
      },
    );
  }

  String _formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return DateFormat('MMM d, yyyy').format(timestamp);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildMessageTile(DocumentSnapshot messageDoc) {
    final data = messageDoc.data() as Map<String, dynamic>;
    final messageId = messageDoc.id;
    final isRead = data['isRead'] ?? false;
    final timestamp = (data['timestamp'] as Timestamp).toDate();
    final isDeleting = _deletingMessages[messageId] == true;

    return Dismissible(
      key: Key(messageId),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 24),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Delete Message'),
                content: const Text(
                  'Are you sure you want to delete this message?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
        );
      },
      onDismissed: (direction) => _deleteMessage(messageId),
      child: ListTile(
        onTap: () async {
          if (!isRead) await _markAsRead(messageId);
          // ignore: use_build_context_synchronously
          context.push('/message/$messageId', extra: data);
        },
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: isRead ? Colors.grey : Colors.blue,
          backgroundImage:
              data['senderAvatar'] != null && data['senderAvatar'].isNotEmpty
                  ? CachedNetworkImageProvider(data['senderAvatar'])
                  : null,
          child:
              data['senderAvatar'] == null
                  ? Icon(
                    isRead ? Icons.person : Icons.person_outline,
                    color: Colors.white,
                  )
                  : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                data['senderName'] ?? 'Unknown',
                style: TextStyle(
                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['content'] ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatMessageTime(timestamp),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing:
            isDeleting
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    switch (value) {
                      case 'reply':
                        _replyToMessage(data);
                        break;
                      case 'delete':
                        _deleteMessage(messageId);
                        break;
                      case 'mark_read':
                        if (!isRead) _markAsRead(messageId);
                        break;
                    }
                  },
                  itemBuilder:
                      (context) => [
                        if (!isRead)
                          const PopupMenuItem(
                            value: 'mark_read',
                            child: ListTile(
                              leading: Icon(Icons.mark_email_read),
                              title: Text('Mark as read'),
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'reply',
                          child: ListTile(
                            leading: Icon(Icons.reply),
                            title: Text('Reply'),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete, color: Colors.red),
                            title: Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        centerTitle: true,
        actions: [
          if (_unreadCount > 0)
            IconButton(
              icon: Badge(
                label: Text(
                  _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                ),
                child: const Icon(Icons.mark_email_read),
              ),
              onPressed: _markAllAsRead,
              tooltip: 'Mark all as read',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed:
                () => setState(() {
                  _loadMessages();
                  _loadUnreadCount();
                }),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body:
          _currentUser == null
              ? _buildLoginPrompt()
              : StreamBuilder<QuerySnapshot>(
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingState();
                  }

                  if (!snapshot.hasData || snapshot.data == null) {
                    return _buildEmptyState();
                  }

                  final messages = snapshot.data!.docs;

                  if (messages.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    separatorBuilder:
                        (context, index) => const Divider(height: 1),
                    itemBuilder:
                        (context, index) => _buildMessageTile(messages[index]),
                  );
                },
              ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.message, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Please sign in to view messages'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.push('/login'),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No messages yet'),
          const SizedBox(height: 8),
          Text(
            'Your messages will appear here',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
