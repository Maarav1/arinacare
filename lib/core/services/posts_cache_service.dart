import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:arina_cave/core/database/app_database.dart';

class PostCacheService {
  final AppDatabase _database;
  
  PostCacheService(this._database);

  Future<List<Map<String, dynamic>>> getCachedPosts({int limit = 20}) async {
    try {
      // Create query without chaining
      final query = _database.select(_database.cachedPosts);

      // Apply ordering and limit separately
      query
        ..orderBy([(t) => OrderingTerm.desc(t.lastAccessed)])
        ..limit(limit);

      // Now execute the query
      final cached = await query.get();
      
      return cached.map((post) {
        try {
          final data = jsonDecode(post.data) as Map<String, dynamic>;
          return {
            'id': post.firestoreId,
            ...data,
            'isCached': true,
            'cachedAt': post.cachedAt.toIso8601String(),
          };
        } catch (e) {
          return {'id': post.firestoreId, 'error': 'Failed to parse'};
        }
      }).toList();
    } catch (e) {
      if (kDebugMode) print('Error getting cached posts: $e');
      return [];
    }
  }
  
  Future<void> cachePost(Map<String, dynamic> post) async {
    try {
      final postId = post['id'] as String? ?? '';
      if (postId.isEmpty) return;
      
      // Prepare data for caching
      final postData = Map<String, dynamic>.from(post);
      
      // Remove internal fields that shouldn't be cached
      postData.remove('id');
      postData.remove('isCached');
      postData.remove('isOffline');
      postData.remove('isFresh');
      postData.remove('cachedAt');
      
      await _database.into(_database.cachedPosts).insert(
        CachedPostsCompanion.insert(
          firestoreId: postId,
          data: jsonEncode(postData),
          cachedAt: DateTime.now(),
          lastAccessed: DateTime.now(),
        ),
        mode: InsertMode.insertOrReplace,
      );
      
      if (kDebugMode) print('✅ Cached post: $postId');
    } catch (e) {
      if (kDebugMode) print('Error caching post: $e');
    }
  }
  
  Future<void> clearCache() async {
    try {
      await _database.delete(_database.cachedPosts).go();
    } catch (e) {
      if (kDebugMode) print('Error clearing cache: $e');
    }
  }
  
  Future<void> updateLastAccessed(String postId) async {
    try {
      await (_database.update(_database.cachedPosts)
        ..where((tbl) => tbl.firestoreId.equals(postId)))
        .write(CachedPostsCompanion(
          lastAccessed: Value(DateTime.now()),
        ));
    } catch (e) {
      if (kDebugMode) print('Error updating last accessed: $e');
    }
  }
}