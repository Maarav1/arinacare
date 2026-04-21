import 'package:cloud_firestore/cloud_firestore.dart' as firestore;

class PostModel {
  final String id;
  final String content;
  final String imageUrl;
  final String userId;
  final String userName;
  final String userEmail;
  final String? profileImageUrl;
  final String? videoUrl;
  final String? location;
  final int shares;
  final bool isEdited;
  final DateTime timestamp;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int likes;
  final List<String> likedBy;
  final List<CommentModel> comments;
  final int commentsCount;

  PostModel({
    required this.id,
    required this.content,
    required this.imageUrl,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.profileImageUrl,
    this.videoUrl,
    this.location,
    this.shares = 0,
    this.isEdited = false,
    required this.timestamp,
    required this.createdAt,
    required this.updatedAt,
    required this.likes,
    required this.likedBy,
    required this.comments,
    required this.commentsCount,
  });

  factory PostModel.fromFirestore(firestore.DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PostModel(
      id: doc.id,
      content: data['content'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'User',
      userEmail: data['userEmail'] ?? '',
      profileImageUrl: data['profileImageUrl'],
      videoUrl: data['videoUrl'],
      location: data['location'],
      shares: data['shares'] ?? 0,
      isEdited: data['isEdited'] ?? false,
      timestamp: (data['timestamp'] as firestore.Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as firestore.Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as firestore.Timestamp?)?.toDate() ?? DateTime.now(),
      likes: data['likes'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      comments: List<Map<String, dynamic>>.from(data['comments'] ?? [])
          .map((comment) => CommentModel.fromMap(comment))
          .toList(),
      commentsCount: data['commentsCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'content': content,
      'imageUrl': imageUrl,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'profileImageUrl': profileImageUrl,
      'videoUrl': videoUrl,
      'location': location,
      'shares': shares,
      'isEdited': isEdited,
      'timestamp': firestore.Timestamp.fromDate(timestamp),
      'createdAt': firestore.Timestamp.fromDate(createdAt),
      'updatedAt': firestore.Timestamp.fromDate(updatedAt),
      'likes': likes,
      'likedBy': likedBy,
      'comments': comments.map((comment) => comment.toMap()).toList(),
      'commentsCount': commentsCount,
    };
  }
}

class CommentModel {
  final String id;
  final String text;
  final String userId;
  final String userName;
  final String userEmail;
  final String profilePictureUrl;
  final String? parentCommentId;
  final int depth;
  final DateTime timestamp;
  final int likes;
  final List<String> likedBy;
  final List<CommentModel> replies;
  final int replyCount;
  final bool isExpanded;

  CommentModel({
    required this.id,
    required this.text,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.profilePictureUrl,
    this.parentCommentId,
    this.depth = 0,
    required this.timestamp,
    required this.likes,
    required this.likedBy,
    required this.replies,
    required this.replyCount,
    this.isExpanded = true,
  });

  factory CommentModel.fromMap(Map<String, dynamic> map) {
    return CommentModel(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'User',
      userEmail: map['userEmail'] ?? '',
      profilePictureUrl: map['profilePictureUrl'] ?? '',
      parentCommentId: map['parentCommentId'],
      depth: map['depth'] ?? 0,
      timestamp: DateTime.parse(map['timestamp']),
      likes: map['likes'] ?? 0,
      likedBy: List<String>.from(map['likedBy'] ?? []),
      replies: List<Map<String, dynamic>>.from(map['replies'] ?? [])
          .map((reply) => CommentModel.fromMap(reply))
          .toList(),
      replyCount: map['replyCount'] ?? 0,
      isExpanded: map['isExpanded'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'profilePictureUrl': profilePictureUrl,
      'parentCommentId': parentCommentId,
      'depth': depth,
      'timestamp': timestamp.toIso8601String(),
      'likes': likes,
      'likedBy': likedBy,
      'replies': replies.map((reply) => reply.toMap()).toList(),
      'replyCount': replyCount,
      'isExpanded': isExpanded,
    };
  }
}