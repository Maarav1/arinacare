import 'package:arina_cave/constants/app_constants.dart';
import 'package:arina_cave/core/models/post_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Posts
  static Future<List<PostModel>> getPosts({
    required int limit,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore
          .collection(AppConstants.postsCollection)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to load posts: $e');
    }
  }

  static Future<void> createPost(PostModel post) async {
    try {
      await _firestore
          .collection(AppConstants.postsCollection)
          .doc(post.id)
          .set(post.toFirestore());
    } catch (e) {
      throw Exception('Failed to create post: $e');
    }
  }

  static Future<void> deletePost(String postId) async {
    try {
      await _firestore.collection(AppConstants.postsCollection).doc(postId).delete();
    } catch (e) {
      throw Exception('Failed to delete post: $e');
    }
  }

  static Future<void> toggleLike({
    required String postId,
    required String userId,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final postRef = _firestore.collection(AppConstants.postsCollection).doc(postId);
        final postDoc = await transaction.get(postRef);

        if (!postDoc.exists) {
          throw Exception('Post not found');
        }

        final data = postDoc.data()!;
        final likedBy = List<String>.from(data['likedBy'] ?? []);
        int likes = data['likes'] ?? 0;

        if (likedBy.contains(userId)) {
          likedBy.remove(userId);
          likes = (likes - 1).clamp(0, 999999999);
        } else {
          likedBy.add(userId);
          likes = likes + 1;
        }

        transaction.update(postRef, {
          'likedBy': likedBy,
          'likes': likes,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw Exception('Failed to toggle like: $e');
    }
  }

  // Users
  static Future<Map<String, dynamic>> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection(AppConstants.usersCollection).doc(userId).get();
      if (doc.exists) {
        return doc.data()!;
      }
      return {};
    } catch (e) {
      throw Exception('Failed to get user data: $e');
    }
  }

  // Comments
  static Future<void> addComment({
    required String postId,
    required CommentModel comment, // Make sure CommentModel is imported
  }) async {
    try {
      final postRef = _firestore.collection(AppConstants.postsCollection).doc(postId);
      
      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        if (!postDoc.exists) throw Exception('Post not found');

        final data = postDoc.data()!;
        final comments = List<Map<String, dynamic>>.from(data['comments'] ?? []);
        comments.add(comment.toMap());

        transaction.update(postRef, {
          'comments': comments,
          'commentsCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw Exception('Failed to add comment: $e');
    }
  }
}