import 'dart:async';
import 'package:arina_cave/constants/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:flutter/foundation.dart';

class AutoDeleteService {
  static final firestore.FirebaseFirestore _firestore = firestore.FirebaseFirestore.instance;

  static void initialize() {
    // Schedule daily cleanup
    Timer.periodic(const Duration(hours: 24), (timer) async {
      await _deleteOldPosts();
    });
  }

  static Future<void> _deleteOldPosts() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(AppConstants.postAutoDeleteDuration);
      
      final query = _firestore
          .collection(AppConstants.postsCollection)
          .where('timestamp', isLessThan: firestore.Timestamp.fromDate(thirtyDaysAgo));

      final snapshot = await query.get();
      
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
        
        // Also remove from scheduled deletes
        final scheduledDeleteRef = _firestore
            .collection(AppConstants.scheduledDeletesCollection)
            .doc(doc.id);
        batch.delete(scheduledDeleteRef);
      }
      
      await batch.commit();
      
      if (snapshot.docs.isNotEmpty) {
        debugPrint('Auto-deleted ${snapshot.docs.length} posts older than 30 days');
      }
    } catch (e) {
      debugPrint('Error auto-deleting posts: $e');
      // Don't throw - this is a background process
    }
  }

  static Future<void> schedulePostAutoDelete(String postId) async {
    try {
      final deleteTime = DateTime.now().add(AppConstants.postAutoDeleteDuration);
      
      await _firestore.collection(AppConstants.scheduledDeletesCollection).doc(postId).set({
        'postId': postId,
        'deleteAt': firestore.Timestamp.fromDate(deleteTime),
        'scheduledAt': firestore.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error scheduling auto-delete: $e');
    }
  }
}