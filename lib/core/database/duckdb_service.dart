// lib/core/database/analytics_database.dart
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ArinaAnalyticsDatabase {
  static final ArinaAnalyticsDatabase _instance = ArinaAnalyticsDatabase._internal();
  factory ArinaAnalyticsDatabase() => _instance;
  ArinaAnalyticsDatabase._internal();
  
  static Database? _database;
  bool _isInitialized = false;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  Future<Database> _initDatabase() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, 'arina_analytics.db');
    
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _createDatabase,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }
  
  Future<void> _createDatabase(Database db, int version) async {
    // User Activity Analytics
    await db.execute('''
      CREATE TABLE user_analytics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        session_date TEXT NOT NULL,
        post_views INTEGER DEFAULT 0,
        likes_given INTEGER DEFAULT 0,
        comments_made INTEGER DEFAULT 0,
        time_spent_seconds INTEGER DEFAULT 0,
        device_memory_mb INTEGER,
        network_type TEXT,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');
    
    // Create indices
    await db.execute('''
      CREATE INDEX idx_user_date 
      ON user_analytics(user_id, session_date)
    ''');
    
    // Post Performance Analytics
    await db.execute('''
      CREATE TABLE post_analytics (
        post_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        impressions INTEGER DEFAULT 0,
        likes INTEGER DEFAULT 0,
        comments INTEGER DEFAULT 0,
        shares INTEGER DEFAULT 0,
        avg_view_time_seconds INTEGER,
        retention_rate REAL,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');
    
    await db.execute('''
      CREATE INDEX idx_post_performance 
      ON post_analytics(post_id, created_at)
    ''');
    
    // Media Usage Analytics
    await db.execute('''
      CREATE TABLE media_analytics (
        media_id TEXT PRIMARY KEY,
        post_id TEXT,
        media_type TEXT CHECK(media_type IN ('image', 'video', 'audio')),
        size_bytes INTEGER,
        load_time_ms INTEGER,
        cache_hit INTEGER DEFAULT 0,
        compression_ratio REAL,
        device_ram_mb INTEGER,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');
  }
  
  Future<void> initialize() async {
    if (!_isInitialized) {
      await database;
      _isInitialized = true;
    }
  }
  
  // Insert user activity
  Future<void> insertUserActivity({
    required String userId,
    required DateTime sessionDate,
    int postViews = 0,
    int likesGiven = 0,
    int commentsMade = 0,
    int timeSpentSeconds = 0,
    int? deviceMemoryMb,
    String? networkType,
  }) async {
    final db = await database;
    
    await db.insert(
      'user_analytics',
      {
        'user_id': userId,
        'session_date': sessionDate.toIso8601String().split('T').first,
        'post_views': postViews,
        'likes_given': likesGiven,
        'comments_made': commentsMade,
        'time_spent_seconds': timeSpentSeconds,
        'device_memory_mb': deviceMemoryMb,
        'network_type': networkType,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  // Insert or update post analytics
  Future<void> insertPostAnalytics({
    required String postId,
    required String userId,
    int impressions = 0,
    int likes = 0,
    int comments = 0,
    int shares = 0,
    int? avgViewTimeSeconds,
    double? retentionRate,
  }) async {
    final db = await database;
    
    // Check if post exists
    final existing = await db.query(
      'post_analytics',
      where: 'post_id = ?',
      whereArgs: [postId],
    );
    
    if (existing.isEmpty) {
      // Insert new record
      await db.insert(
        'post_analytics',
        {
          'post_id': postId,
          'user_id': userId,
          'impressions': impressions,
          'likes': likes,
          'comments': comments,
          'shares': shares,
          'avg_view_time_seconds': avgViewTimeSeconds,
          'retention_rate': retentionRate,
        },
      );
    } else {
      // Update existing record
      await db.update(
        'post_analytics',
        {
          'impressions': (existing.first['impressions'] as int) + impressions,
          'likes': (existing.first['likes'] as int) + likes,
          'comments': (existing.first['comments'] as int) + comments,
          'shares': (existing.first['shares'] as int) + shares,
          'avg_view_time_seconds': avgViewTimeSeconds ?? existing.first['avg_view_time_seconds'],
          'retention_rate': retentionRate ?? existing.first['retention_rate'],
        },
        where: 'post_id = ?',
        whereArgs: [postId],
      );
    }
  }
  
  // Analyze user behavior
  Future<Map<String, dynamic>> analyzeUserBehavior(String userId) async {
    final db = await database;
    
    final result = await db.rawQuery('''
      SELECT 
        COUNT(DISTINCT session_date) as active_days,
        SUM(post_views) as total_views,
        SUM(likes_given) as total_likes,
        SUM(comments_made) as total_comments,
        AVG(time_spent_seconds) as avg_session_time
      FROM user_analytics
      WHERE user_id = ?
        AND date(session_date) >= date('now', '-30 days')
    ''', [userId]);
    
    if (result.isEmpty) return {};
    
    final stats = result.first;
    final activeDays = stats['active_days'] as int? ?? 0;
    final totalViews = stats['total_views'] as int? ?? 0;
    final totalLikes = stats['total_likes'] as int? ?? 0;
    final totalComments = stats['total_comments'] as int? ?? 0;
    
    final dailyEngagement = activeDays > 0 
        ? (totalViews * 0.3 + totalLikes * 0.4 + totalComments * 0.3) / activeDays 
        : 0;
    
    String engagementLevel;
    if (dailyEngagement > 50) {
      engagementLevel = 'HIGH';
    } else if (dailyEngagement > 20) {
      engagementLevel = 'MEDIUM';
    } else {
      engagementLevel = 'LOW';
    }
    
    return {
      'active_days': activeDays,
      'total_views': totalViews,
      'total_likes': totalLikes,
      'total_comments': totalComments,
      'avg_session_time': stats['avg_session_time'],
      'daily_engagement': dailyEngagement,
      'engagement_level': engagementLevel,
    };
  }
  
  // Get daily active users
  Future<int> getDailyActiveUsers() async {
    final db = await database;
    
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT user_id) as dau
      FROM user_analytics
      WHERE date(session_date) = date('now')
    ''');
    
    return result.isNotEmpty ? (result.first['dau'] as int?) ?? 0 : 0;
  }
  
  // Get top performing posts
  Future<List<Map<String, dynamic>>> getTopPerformingPosts({int limit = 10}) async {
    final db = await database;
    
    return await db.rawQuery('''
      SELECT 
        post_id,
        user_id,
        impressions,
        likes,
        comments,
        shares,
        CASE 
          WHEN impressions > 0 
          THEN ROUND(likes * 100.0 / impressions, 2)
          ELSE 0
        END as engagement_rate,
        created_at
      FROM post_analytics
      WHERE impressions > 0
      ORDER BY engagement_rate DESC
      LIMIT ?
    ''', [limit]);
  }
  
  // Clean old data
  Future<void> cleanOldData({int daysToKeep = 90}) async {
    final db = await database;
    
    await db.delete(
      'user_analytics',
      where: 'date(session_date) < date("now", ?)',
      whereArgs: ['-$daysToKeep days'],
    );
    
    await db.delete(
      'post_analytics',
      where: 'date(created_at) < date("now", ?)',
      whereArgs: ['-$daysToKeep days'],
    );
  }
  
  // Export data to list of maps (can be converted to CSV)
  Future<List<Map<String, dynamic>>> exportData() async {
    final db = await database;
    
    final userData = await db.query('user_analytics');
    final postData = await db.query('post_analytics');
    final mediaData = await db.query('media_analytics');
    
    return [...userData, ...postData, ...mediaData];
  }
  
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _isInitialized = false;
    }
  }
  
  bool get isInitialized => _isInitialized;
}

// Analytics Service
class ArinaAnalyticsService {
  final ArinaAnalyticsDatabase _db = ArinaAnalyticsDatabase();
  
  static final ArinaAnalyticsService _instance = ArinaAnalyticsService._internal();
  factory ArinaAnalyticsService() => _instance;
  ArinaAnalyticsService._internal();
  
  Future<void> initialize() async {
    await _db.initialize();
  }
  
  // Track user session
  Future<void> trackSession({
    required String userId,
    required int durationSeconds,
    int postViews = 0,
    int likes = 0,
    int comments = 0,
  }) async {
    await _db.insertUserActivity(
      userId: userId,
      sessionDate: DateTime.now(),
      postViews: postViews,
      likesGiven: likes,
      commentsMade: comments,
      timeSpentSeconds: durationSeconds,
    );
  }
  
  // Track post view
  Future<void> trackPostView({
    required String postId,
    required String userId,
    int viewTimeSeconds = 0,
  }) async {
    await _db.insertPostAnalytics(
      postId: postId,
      userId: userId,
      impressions: 1,
      avgViewTimeSeconds: viewTimeSeconds,
    );
  }
  
  // Track post engagement
  Future<void> trackPostEngagement({
    required String postId,
    required String userId,
    required String engagementType,
  }) async {
    final updates = <String, int>{};
    
    switch (engagementType) {
      case 'like':
        updates['likes'] = 1;
        break;
      case 'comment':
        updates['comments'] = 1;
        break;
      case 'share':
        updates['shares'] = 1;
        break;
    }
    
    await _db.insertPostAnalytics(
      postId: postId,
      userId: userId,
      likes: updates['likes'] ?? 0,
      comments: updates['comments'] ?? 0,
      shares: updates['shares'] ?? 0,
    );
  }
  
  // Get user insights
  Future<Map<String, dynamic>> getUserInsights(String userId) async {
    return await _db.analyzeUserBehavior(userId);
  }
  
  // Get dashboard data
  Future<Map<String, dynamic>> getDashboardData() async {
    final dau = await _db.getDailyActiveUsers();
    final topPosts = await _db.getTopPerformingPosts(limit: 5);
    
    return {
      'daily_active_users': dau,
      'top_performing_posts': topPosts,
    };
  }
  
  // Weekly cleanup
  Future<void> performWeeklyCleanup() async {
    await _db.cleanOldData(daysToKeep: 90);
  }
  
  // Export data
  Future<List<Map<String, dynamic>>> exportData() async {
    return await _db.exportData();
  }
  
  Future<void> close() async {
    await _db.close();
  }
}