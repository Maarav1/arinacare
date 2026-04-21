import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'comments_screen.dart';
import 'package:share_plus/share_plus.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic>? _currentPostData;
  Map<String, dynamic>? _currentUserData;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              _handlePostAction(value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 20),
                    SizedBox(width: 8),
                    Text('Share'),
                  ],
                ),
              ),
              if (_currentUser != null)
                const PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.flag, size: 20),
                      SizedBox(width: 8),
                      Text('Report'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('posts').doc(widget.postId).snapshots(),
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
                  const Text('Error loading post'),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.post_add, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Post not found',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This post may have been deleted',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final post = snapshot.data!;
          final postData = post.data() as Map<String, dynamic>;
          _currentPostData = postData;

          return FutureBuilder<Map<String, dynamic>?>(
            future: _getUserData(postData['authorId'] ?? postData['userId']),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final userData = userSnapshot.data ?? {};
              _currentUserData = userData;
              return _buildPostDetail(post, postData, userData);
            },
          );
        },
      ),
    );
  }

  Widget _buildPostDetail(
    DocumentSnapshot post,
    Map<String, dynamic> postData,
    Map<String, dynamic> userData,
  ) {
    final isLiked = (postData['likes'] as List? ?? []).contains(_currentUser?.uid);
    final timestamp = postData['timestamp'] != null
        ? (postData['timestamp'] as Timestamp).toDate()
        : DateTime.now();
    final firstName = userData['firstName'] ?? '';
    final lastName = userData['lastName'] ?? '';
    final fullName = '$firstName $lastName'.trim().isNotEmpty
        ? '$firstName $lastName'.trim()
        : userData['displayName'] ?? 'Unknown User';
    final profileImageUrl = userData['profilePictureUrl'] ?? '';
    final content = postData['content'] ?? '';
    final imageUrl = postData['imageUrl'];
    final likes = postData['likes'] is List ? (postData['likes'] as List).length : (postData['likes'] ?? 0);
    final comments = postData['comments'] ?? [];

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author section
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: profileImageUrl.isNotEmpty
                      ? CachedNetworkImageProvider(profileImageUrl)
                      : null,
                  child: profileImageUrl.isEmpty
                      ? Text(
                          fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                          style: const TextStyle(fontSize: 16),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _formatTimestamp(timestamp),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Content section
            if (content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  content,
                  style: const TextStyle(fontSize: 16, height: 1.4),
                ),
              ),

            // Image section
            if (imageUrl != null && imageUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) => Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Failed to load image'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Stats section
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  _buildStatItem(Icons.favorite, '$likes'),
                  const SizedBox(width: 16),
                  _buildStatItem(Icons.comment, '${comments.length}'),
                ],
              ),
            ),

            const Divider(),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionButton(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  'Like',
                  () => _likePost(post.id),
                  isActive: isLiked,
                ),
                _buildActionButton(
                  Icons.comment,
                  'Comment',
                  () => _showComments(post.id, postData, fullName),
                ),
                _buildActionButton(
                  Icons.share,
                  'Share',
                  () => _sharePost(postData, fullName),
                ),
              ],
            ),

            const Divider(),

            // Comments preview
            if (comments.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Comments (${comments.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              ...comments.take(3).map((comment) => _buildCommentPreview(comment)),
              if (comments.length > 3)
                TextButton(
                  onPressed: () => _showComments(post.id, postData, fullName),
                  child: const Text('View all comments'),
                ),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No comments yet',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String count) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          count,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap, {bool isActive = false}) {
    return Expanded(
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(
          icon,
          size: 20,
          color: isActive ? Colors.blue : Colors.grey[700],
        ),
        label: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.blue : Colors.grey[700],
          ),
        ),
        style: TextButton.styleFrom(
          foregroundColor: isActive ? Colors.blue : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildCommentPreview(dynamic comment) {
    final commentText = comment is Map ? comment['text'] ?? '' : comment.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        commentText,
        style: const TextStyle(fontSize: 14),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    
    return DateFormat('MMM d, y • h:mm a').format(timestamp);
  }

  Future<Map<String, dynamic>?> _getUserData(String? userId) async {
    if (userId == null) return null;
    
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.data();
    } catch (e) {
      return null;
    }
  }

  void _handlePostAction(String action) {
    switch (action) {
      case 'share':
        if (_currentPostData != null && _currentUserData != null) {
          final firstName = _currentUserData!['firstName'] ?? '';
          final lastName = _currentUserData!['lastName'] ?? '';
          final fullName = '$firstName $lastName'.trim().isNotEmpty
              ? '$firstName $lastName'.trim()
              : _currentUserData!['displayName'] ?? 'Unknown User';
          _sharePost(_currentPostData!, fullName);
        }
        break;
      case 'report':
        _reportPost();
        break;
    }
  }

  Future<void> _likePost(String postId) async {
    if (_currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to like posts')),
        );
      }
      return;
    }

    try {
      final toggleLike = FirebaseFunctions.instance.httpsCallable('toggleLikePost');
      final result = await toggleLike.call({'postId': postId});

      if (result.data['success'] == true && mounted) {
        final message = result.data['liked'] ? 'Post liked' : 'Post unliked';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showComments(String postId, Map<String, dynamic> postData, String authorName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentsScreen(
          postId: postId,
          postData: {
            'content': postData['content'],
            'authorName': authorName,
          },
        ),
      ),
    );
  }

  Future<void> _sharePost(Map<String, dynamic> postData, String authorName) async {
  try {
    final content = postData['content'] ?? '';
    final postId = widget.postId;
    
    // Create shareable content
    final shareText = 'Check out this post by $authorName:\n\n$content\n\n';
    
    // Create deep link
    final deepLink = 'arina://cave/post/$postId';
    final webLink = 'https://maarav1.github.io/post/$postId';
    
    final fullShareString = '$shareText\nApp: $deepLink\nWeb: $webLink';

    // CORRECT: Use SharePlus.instance.share() without subject
    await SharePlus.instance.share(fullShareString as ShareParams);
    
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
  void _reportPost() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Post'),
        content: const Text('Why are you reporting this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Post reported')),
                );
              }
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }
}