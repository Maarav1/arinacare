// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';

class MessageDetailScreen extends StatefulWidget {
  final String conversationId;
  final String recipientName;
  final String? recipientPhotoUrl;

  const MessageDetailScreen({
    super.key,
    required this.conversationId,
    required this.recipientName,
    this.recipientPhotoUrl,
    required String id,
    required String messageId,
  });

  @override
  State<MessageDetailScreen> createState() => _MessageDetailScreenState();
}

class _MessageDetailScreenState extends State<MessageDetailScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late final Stream<QuerySnapshot> _messagesStream;
  bool _isSending = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setupMessagesStream();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupMessagesStream() {
    setState(() => _isLoading = true);

    _messagesStream =
        _firestore
            .collection('conversations')
            .doc(widget.conversationId)
            .collection('messages')
            .orderBy('timestamp', descending: false)
            .snapshots();

    setState(() => _isLoading = false);
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      // Use Cloud Function instead of direct Firestore writes
      final HttpsCallable callable = _functions.httpsCallable('sendMessage');
      final result = await callable.call({
        'conversationId': widget.conversationId,
        'content': message,
      });

      if (result.data['success'] == true) {
        _scrollToBottom();
      } else {
        if (!mounted) return;
        setState(
          () => _error = 'Failed to send message: ${result.data['message']}',
        );
        if (kDebugMode) {
          print('Error sending message: ${result.data['message']}');
        }
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to send message: ${e.message}');
      if (kDebugMode) print('Firebase Functions error: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to send message');
      if (kDebugMode) print('Error sending message: $e');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildMessageBubble(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final isMe = data['senderId'] == _auth.currentUser?.uid;
    final timestamp = data['timestamp'] as Timestamp?;
    final timeString =
        timestamp != null ? DateFormat.jm().format(timestamp.toDate()) : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isMe ? Theme.of(context).primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft:
                isMe ? const Radius.circular(12) : const Radius.circular(0),
            bottomRight:
                isMe ? const Radius.circular(0) : const Radius.circular(12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['content'],
              style: TextStyle(color: isMe ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 4),
            Text(
              timeString,
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.grey[600],
                fontSize: 10,
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
        titleSpacing: 0,
        title: Row(
          children: [
            if (widget.recipientPhotoUrl != null)
              CircleAvatar(
                backgroundImage: NetworkImage(widget.recipientPhotoUrl!),
                radius: 16,
              )
            else
              CircleAvatar(radius: 16, child: Text(widget.recipientName[0])),
            const SizedBox(width: 12),
            Text(widget.recipientName),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed:
                () => context.push(
                  '/conversation-settings/${widget.conversationId}',
                ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(child: Text(_error!))
                    : StreamBuilder<QuerySnapshot>(
                      stream: _messagesStream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }

                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _scrollToBottom();
                        });

                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            return _buildMessageBubble(
                              snapshot.data!.docs[index],
                            );
                          },
                        );
                      },
                    ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {}, // Add attachment functionality
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon:
                _isSending
                    ? const CircularProgressIndicator()
                    : const Icon(Icons.send),
            onPressed: _isSending ? null : _sendMessage,
          ),
        ],
      ),
    );
  }
}
