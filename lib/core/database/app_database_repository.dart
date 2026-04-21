// core/database/app_database_repository.dart
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:arina_cave/core/database/app_database.dart';

class AppDatabaseRepository {
  final AppDatabase _database;
  
  AppDatabaseRepository(this._database);
  
  Future<void> performMaintenance() async {
    try {
      // Drift maintenance operations
      await _database.customStatement('PRAGMA optimize');
      await _database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      
      // Clean up old data
      await clearOldCache();
      await clearOldNotifications();
      
      if (kDebugMode) {
        print('✅ Database maintenance completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Database maintenance error: $e');
      }
    }
  }
  
  Future<void> clearAllCache() async {
    try {
      // ✅ Corrected: Use 'cache' instead of '_database.cacheTable'
      await _database.delete(_database.cache).go();
      if (kDebugMode) {
        print('✅ All cache cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Clear cache error: $e');
      }
    }
  }
  
  // Clear old cache entries
  Future<void> clearOldCache() async {
    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      
      // ✅ The 'cache' table is accessible via _database.cache
      await (_database.delete(_database.cache)
        ..where((tbl) => tbl.lastAccessed.isSmallerThanValue(sevenDaysAgo))
      ).go();
      
      if (kDebugMode) {
        print('✅ Old cache cleared (older than 7 days)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Clear old cache warning: $e');
      }
    }
  }
  
  // Clear old notifications
  Future<void> clearOldNotifications() async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      // ✅ Corrected: Use 'notifications' instead of '_database.notificationsTable'
      await (_database.delete(_database.notifications)
        ..where((tbl) => tbl.isRead.equals(true) & tbl.createdAt.isSmallerThanValue(thirtyDaysAgo))
      ).go();
      
      if (kDebugMode) {
        print('✅ Old read notifications cleared (older than 30 days)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Clear old notifications warning: $e');
      }
    }
  }
  
  // Example query method to get notifications
  Future<List<Map<String, dynamic>>> getNotifications({
    bool unreadOnly = false,
    int limit = 50,
  }) async {
    // ✅ Corrected: Access the table via _database.notifications
    final query = _database.select(_database.notifications)
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
      ..limit(limit);
    
    if (unreadOnly) {
      query.where((tbl) => tbl.isRead.equals(false));
    }
    
    final results = await query.get();
    // Convert to list of maps. Ensure your Notifications class has a toJson() method.
    return results.map((notification) => notification.toJson()).toList();
  }
  
  Future<void> insertNotification({
    required String userId,
    required String type,
    required String content,
    String? referenceId,
  }) async {
    // ✅ Corrected: Use the generated NotificationsCompanion
    final companion = NotificationsCompanion(
      userId: Value(userId),
      type: Value(type),
      content: Value(content),
      referenceId: Value(referenceId),
      isRead: const Value(false),
      createdAt: Value(DateTime.now()),
    );
    
    await _database.into(_database.notifications).insert(companion);
  }
}