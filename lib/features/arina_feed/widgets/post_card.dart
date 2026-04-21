import 'package:arina_cave/core/models/post_model.dart';
import 'package:arina_cave/core/services/firestore_service.dart';
import 'package:arina_cave/screens/home_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class PostCard extends StatefulWidget {
  final PostModel post;
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
  Map<String, dynamic> _userData = {};
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final data = await FirestoreService.getUserData(widget.post.userId);
      if (mounted) {
        setState(() {
          _userData = data;
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUser = false);
      }
    }
  }

  String _formatTimestamp(DateTime date) {
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

  bool get _isLiked {
    return widget.currentUserId.isNotEmpty &&
        widget.post.likedBy.contains(widget.currentUserId);
  }

  bool get _canDelete {
    return widget.post.userId == widget.currentUserId;
  }

  @override
  Widget build(BuildContext context) {
    final userName = _userData['fullName'] ?? widget.post.userName;
    final profileImageUrl = _userData['profilePictureUrl'] ?? '';
    final isOnline = _userData['isOnline'] ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: GestureDetector(
                onTap: () => widget.onProfileTap(widget.post.userId),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage:
                          profileImageUrl.isNotEmpty
                              ? CachedNetworkImageProvider(profileImageUrl)
                              : null,
                      backgroundColor: Colors.blueGrey.shade200,
                      child:
                          _isLoadingUser
                              ? const CircularProgressIndicator(strokeWidth: 2)
                              : profileImageUrl.isEmpty
                              ? Text(
                                userName.isNotEmpty
                                    ? userName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
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
              title: Text(
                userName,
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                _formatTimestamp(widget.post.timestamp),
                style: TextStyle(color: Colors.grey.shade600),
              ),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 'share':
                      widget.onShare();
                      break;
                    case 'delete':
                      widget.onDelete();
                      break;
                  }
                },
                itemBuilder:
                    (context) => [
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share),
                            SizedBox(width: 8),
                            Text('Share'),
                          ],
                        ),
                      ),
                      if (_canDelete)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                    ],
              ),
            ),

            // Content
            if (widget.post.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: LinkableText(
                  text: widget.post.content,
                  style: const TextStyle(fontSize: 16, height: 1.4),
                ),
              ),

            // Image
            if (widget.post.imageUrl.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: widget.post.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 300,
                    placeholder:
                        (context, url) => Container(
                          height: 300,
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    errorWidget:
                        (context, url, error) => Container(
                          height: 300,
                          color: Colors.grey.shade200,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                size: 50,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text('Failed to load image'),
                            ],
                          ),
                        ),
                  ),
                ),
              ),

            // Actions
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  // Like button
                  IconButton(
                    icon: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? Colors.red : Colors.grey,
                    ),
                    onPressed: widget.onLike,
                  ),
                  Text(
                    _formatCount(widget.post.likes),
                    style: TextStyle(
                      color: _isLiked ? Colors.red : Colors.grey,
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
                    _formatCount(widget.post.commentsCount),
                    style: TextStyle(
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
