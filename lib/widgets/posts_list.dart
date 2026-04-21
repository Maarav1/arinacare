// posts_list.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class PostsList extends StatefulWidget {
  const PostsList({super.key});

  @override
  State<PostsList> createState() => _PostsListState();
}

class _PostsListState extends State<PostsList> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();

  Future<void> _toggleLike(DocumentSnapshot post) async {
    try {
      final postRef = _firestore.collection('posts').doc(post.id);
      final likedBy = List<String>.from(post['likedBy'] ?? []);
      final isLiked = likedBy.contains(_currentUser?.uid);

      await postRef.update({
        'likedBy':
            isLiked
                ? FieldValue.arrayRemove([_currentUser?.uid])
                : FieldValue.arrayUnion([_currentUser?.uid]),
        'likes': isLiked ? (post['likes'] ?? 1) - 1 : (post['likes'] ?? 0) + 1,
      });
    } catch (e) {
      _scaffoldKey.currentState?.showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _showComments(BuildContext context, String postId) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CommentsBottomSheet(postId: postId),
    );
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    DocumentSnapshot post,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Post'),
            content: const Text('Are you sure you want to delete this post?'),
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
      try {
        await post.reference.delete();
        _scaffoldKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Post deleted successfully')),
        );
      } catch (e) {
        _scaffoldKey.currentState?.showSnackBar(
          SnackBar(content: Text('Error deleting post: ${e.toString()}')),
        );
      }
    }
  }

  String _formatTimeAgo(Timestamp timestamp) {
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('posts')
              .orderBy('timestamp', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No posts yet.\nTap "Share Your Thoughts" to begin!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final post = snapshot.data!.docs[index];
            final likedBy = List<String>.from(post['likedBy'] ?? []);
            final isLiked = likedBy.contains(_currentUser?.uid);
            final likes = post['likes'] ?? 0;
            final commentsCount = (post['comments'] as List?)?.length ?? 0;
            final isCurrentUser = post['userId'] == _currentUser?.uid;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        FutureBuilder<DocumentSnapshot>(
                          future:
                              _firestore
                                  .collection('users')
                                  .doc(post['userId'])
                                  .get(),
                          builder: (context, userSnapshot) {
                            String? profileImageUrl;
                            String userName = 'Anonymous';

                            if (userSnapshot.hasData &&
                                userSnapshot.data!.exists) {
                              final userData = userSnapshot.data!;
                              profileImageUrl = userData['profilePictureUrl'];
                              userName =
                                  userData['firstName'] ??
                                  userData['email']?.toString().split('@')[0] ??
                                  'Anonymous';
                            }

                            return CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.blue.shade100,
                              backgroundImage:
                                  profileImageUrl != null
                                      ? CachedNetworkImageProvider(
                                        profileImageUrl,
                                      )
                                      : null,
                              child:
                                  profileImageUrl == null
                                      ? Text(
                                        userName[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                      : null,
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
                                    _firestore
                                        .collection('users')
                                        .doc(post['userId'])
                                        .get(),
                                builder: (context, userSnapshot) {
                                  String userName = 'Anonymous';
                                  if (userSnapshot.hasData &&
                                      userSnapshot.data!.exists) {
                                    final userData = userSnapshot.data!;
                                    userName =
                                        userData['firstName'] ??
                                        userData['email']?.toString().split(
                                          '@',
                                        )[0] ??
                                        'Anonymous';
                                  }
                                  return Text(
                                    userName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  );
                                },
                              ),
                              Text(
                                post['timestamp'] != null
                                    ? _formatTimeAgo(
                                      post['timestamp'] as Timestamp,
                                    )
                                    : '',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isCurrentUser)
                          IconButton(
                            icon: const Icon(Icons.more_vert),
                            onPressed: () => _showDeleteDialog(context, post),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (post['content'] != null && post['content'].isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          post['content'],
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    if (post['imageUrl'] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: post['imageUrl'],
                            placeholder:
                                (context, url) => Container(
                                  height: 200,
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                            errorWidget:
                                (context, url, error) => Container(
                                  height: 200,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.error),
                                ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.red : null,
                          ),
                          onPressed: () => _toggleLike(post),
                        ),
                        Text('$likes'),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.comment),
                          onPressed: () => _showComments(context, post.id),
                        ),
                        Text('$commentsCount'),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class CommentsBottomSheet extends StatefulWidget {
  final String postId;

  const CommentsBottomSheet({super.key, required this.postId});

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty || _currentUser == null) return;

    try {
      final comment = {
        'text': _commentController.text.trim(),
        'userId': _currentUser.uid,
        'userEmail': _currentUser.email,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .update({
            'comments': FieldValue.arrayUnion([comment]),
          });

      _commentController.clear();
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding comment: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Text(
                      'Comments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
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

                    final comments = List<dynamic>.from(
                      snapshot.data!['comments'] ?? [],
                    )..sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

                    if (comments.isEmpty) {
                      return const Center(child: Text('No comments yet'));
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        final timestamp = DateTime.parse(comment['timestamp']);
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              (comment['userEmail'] ?? 'U')[0].toUpperCase(),
                            ),
                          ),
                          title: Text(comment['text']),
                          subtitle: Text(
                            '${comment['userEmail']} • ${DateFormat('MMM d, h:mm a').format(timestamp)}',
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          hintText: 'Write a comment...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _addComment,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
