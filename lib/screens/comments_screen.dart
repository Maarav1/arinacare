import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class CommentsScreen extends StatefulWidget {
  final String postId;
  final Map<String, dynamic>? postData;

  const CommentsScreen({super.key, required this.postId, this.postData});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream:
                  _firestore.collection('posts').doc(widget.postId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Center(child: Text('Post not found'));
                }

                final postData = snapshot.data!.data() as Map<String, dynamic>;
                final comments =
                    (postData['comments'] as List? ?? [])
                        .cast<Map<String, dynamic>>()
                        .toList();

                // Sort comments by timestamp (newest first)
                comments.sort((a, b) {
                  final timeA =
                      (a['timestamp'] as Timestamp).millisecondsSinceEpoch;
                  final timeB =
                      (b['timestamp'] as Timestamp).millisecondsSinceEpoch;
                  return timeB.compareTo(timeA);
                });

                return Column(
                  children: [
                    // Post preview
                    if (widget.postData != null) _buildPostPreview(),

                    // Comments list
                    Expanded(
                      child:
                          comments.isEmpty
                              ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.comment,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No comments yet',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Be the first to comment!',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : ListView.builder(
                                controller: _scrollController,
                                reverse: true,
                                itemCount: comments.length,
                                itemBuilder: (context, index) {
                                  return _buildCommentItem(comments[index]);
                                },
                              ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Comment input
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildPostPreview() {
    final postData = widget.postData!;
    final content = postData['content'] ?? '';
    final authorName = postData['authorName'] ?? 'Unknown User';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.grey.shade300,
                child: Text(
                  authorName.isNotEmpty ? authorName[0].toUpperCase() : 'U',
                ),
              ),
              const SizedBox(width: 12),
              Text(
                authorName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (content.isNotEmpty)
            Text(
              content,
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final userName = comment['userName'] ?? 'Unknown User';
    final userImage = comment['userImage'] ?? '';
    final text = comment['text'] ?? '';
    final timestamp = comment['timestamp'] as Timestamp?;
    final isCurrentUser = comment['userId'] == _currentUser?.uid;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage:
                userImage.isNotEmpty
                    ? CachedNetworkImageProvider(userImage)
                    : null,
            child:
                userImage.isEmpty
                    ? Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                    )
                    : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        isCurrentUser
                            ? Colors.blue.shade50
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:
                              isCurrentUser
                                  ? Colors.blue.shade800
                                  : Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(text),
                    ],
                  ),
                ),
                if (timestamp != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Text(
                      _formatTimestamp(timestamp),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
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
          IconButton(
            icon: const Icon(Icons.send, color: Colors.blue),
            onPressed: _addComment,
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final time = timestamp.toDate();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return DateFormat('MMM d, y • h:mm a').format(time);
  }

  Future<void> _addComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty || _currentUser == null) return;

    try {
      final addComment = _functions.httpsCallable('addCommentToPost');
      final result = await addComment.call({
        'postId': widget.postId,
        'commentText': commentText,
      });

      if (!mounted) return;

      if (result.data['success'] == true) {
        _commentController.clear();
        // Scroll to top (newest comment)
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.data['message'] ?? 'Failed to add comment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding comment: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
