import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:arina_cave/core/memory/memory_manager.dart';

part 'app_database.g.dart';

// Users table
class AppUsers extends Table { 
  TextColumn get id => text()();
  TextColumn get username => text()();
  TextColumn get email => text()();
  TextColumn get profileImage => text().nullable()();
  BoolColumn get isVerified => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  
  @override
  Set<Column> get primaryKey => {id};
}

// Posts table
class Posts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userId => text()();
  TextColumn get content => text()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get videoUrl => text().nullable()();
  TextColumn get location => text().nullable()();
  IntColumn get likes => integer().withDefault(const Constant(0))();
  IntColumn get commentsCount => integer().withDefault(const Constant(0))();
  IntColumn get shares => integer().withDefault(const Constant(0))();
  BoolColumn get isEdited => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

// Comments table
class Comments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get postId => text()();
  TextColumn get userId => text()();
  TextColumn get content => text()();
  IntColumn get likes => integer().withDefault(const Constant(0))();
  BoolColumn get isEdited => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

// Notifications table
class Notifications extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get userId => text()();
  TextColumn get type => text()();
  TextColumn get content => text()();
  TextColumn get referenceId => text().nullable()();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

// Cache table
class Cache extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get lastAccessed => dateTime()();
  DateTimeColumn get expiresAt => dateTime().nullable()();
  
  @override
  Set<Column> get primaryKey => {key};
}

// Analytics table
class Analytics extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get event => text()();
  TextColumn get data => text().nullable()();
  DateTimeColumn get timestamp => dateTime()();
}

// AppMetadata table
class AppMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();
  
  @override
  Set<Column> get primaryKey => {key};
}

// CachedPosts table
class CachedPosts extends Table {
  TextColumn get firestoreId => text()();
  TextColumn get data => text()(); // Store as JSON string
  DateTimeColumn get cachedAt => dateTime()();
  DateTimeColumn get lastAccessed => dateTime()();
  
  @override
  Set<Column> get primaryKey => {firestoreId};
}

// DriftDatabase annotation with all tables
@DriftDatabase(
  tables: [
    AppUsers, 
    Posts, 
    Comments, 
    Notifications, 
    Cache, 
    Analytics,
    AppMetadata,
    CachedPosts,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  
  // Memory manager reference
  ArinaMemoryManager? _memoryManager;
  
  // Factory method
  static Future<AppDatabase> create() async {
    final db = AppDatabase();
    await db._initDatabase();
    return db;
  }
  
  Future<void> _initDatabase() async {
    await customStatement('PRAGMA foreign_keys = ON');
    await customStatement('PRAGMA journal_mode = WAL');
    await customStatement('PRAGMA cache_size = -2048'); // 2MB cache
    await customStatement('PRAGMA busy_timeout = 5000'); // 5 second timeout
  }
  
  void setMemoryManager(ArinaMemoryManager memoryManager) {
    _memoryManager = memoryManager;
  }
  
  // Raw query method
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? args,
  ]) async {
    try {
      final variables = args?.map((p) => Variable(p)).toList() ?? [];
      final result = await customSelect(sql, variables: variables).get();
      return result.map((row) => row.data).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error in rawQuery: $e');
      }
      rethrow;
    }
  }
  
  // Custom statement method
  @override
  Future<void> customStatement(String statement, [List<dynamic>? args]) async {
    try {
      final variables = args?.map((p) => Variable(p)).toList() ?? [];
      await customUpdate(statement, variables: variables, updates: {});
    } catch (e) {
      if (kDebugMode) {
        print('Error in customStatement: $e');
      }
      rethrow;
    }
  }
  
  // Print statistics method
  Future<void> printStats() async {
    if (kDebugMode) {
      print('📊 ========== DATABASE STATISTICS ==========');
      
      try {
        // Get table counts
        final usersCount = await select(AppUsers as ResultSetImplementation<HasResultSet, dynamic>).get();
        final postsCount = await select(posts).get();
        final commentsCount = await select(comments).get();
        final notificationsCount = await select(notifications).get();
        final cacheCount = await select(cache).get();
        final analyticsCount = await select(analytics).get();
        final appMetadataCount = await select(appMetadata).get();
        final cachedPostsCount = await select(cachedPosts).get();
        
        print('  📋 Table Counts:');
        print('    👤 Users: ${usersCount.length}');
        print('    📝 Posts: ${postsCount.length}');
        print('    💬 Comments: ${commentsCount.length}');
        print('    🔔 Notifications: ${notificationsCount.length}');
        print('    💾 Cache entries: ${cacheCount.length}');
        print('    📈 Analytics events: ${analyticsCount.length}');
        print('    🏷️  App Metadata: ${appMetadataCount.length}');
        print('    📥 Cached Posts: ${cachedPostsCount.length}');
        
        // Calculate total
        final totalRecords = usersCount.length + postsCount.length + 
                           commentsCount.length + notificationsCount.length + 
                           cacheCount.length + analyticsCount.length +
                           appMetadataCount.length + cachedPostsCount.length;
        print('    📊 Total records: $totalRecords');
        
        // Get database file size
        final path = await getDatabasePath();
        final file = File(path);
        if (await file.exists()) {
          final fileStat = await file.stat();
          final sizeMB = fileStat.size / (1024 * 1024);
          print('  💾 Database size: ${sizeMB.toStringAsFixed(2)} MB');
        }
        
        // Get PRAGMA info
        final pragmaResults = await Future.wait([
          customSelect('PRAGMA journal_mode').getSingle(),
          customSelect('PRAGMA cache_size').getSingle(),
          customSelect('PRAGMA page_size').getSingle(),
          customSelect('PRAGMA page_count').getSingle(),
        ]);
        
        print('  ⚙️  Database Settings:');
        print('    Journal mode: ${pragmaResults[0].read<String>('journal_mode')}');
        print('    Cache size: ${pragmaResults[1].read<int>('cache_size')} pages');
        print('    Page size: ${pragmaResults[2].read<int>('page_size')} bytes');
        print('    Page count: ${pragmaResults[3].read<int>('page_count')} pages');
        
        // Memory info
        if (_memoryManager != null) {
          try {
            final memoryInfo = await _memoryManager!.getMemoryInfo();
            print('  🧠 Memory Status:');
            print('    Used: ${memoryInfo.usedMemMB} MB');
            print('    Available: ${memoryInfo.availableMemMB} MB');
            print('    Total: ${memoryInfo.totalMemMB} MB');
            print('    Platform: ${memoryInfo.platform}');
            print('    Used %: ${memoryInfo.usedPercentage.toStringAsFixed(1)}%');
            print('    Timestamp: ${memoryInfo.timestamp.toLocal()}');
          } catch (e) {
            print('    ❌ Error accessing memory info: $e');
          }
        }
        
        print('📊 =========================================');
      } catch (e) {
        print('  ❌ Error getting database stats: $e');
      }
    }
  }
  
  // Get statistics as map
  Future<Map<String, dynamic>> getStats() async {
    final stats = <String, dynamic>{};
    
    try {
      // Get counts for all tables
      final usersCount = await select(AppUsers as ResultSetImplementation<HasResultSet, dynamic>).get();
      final postsCount = await select(posts).get();
      final commentsCount = await select(comments).get();
      final notificationsCount = await select(notifications).get();
      final cacheCount = await select(cache).get();
      final analyticsCount = await select(analytics).get();
      final appMetadataCount = await select(appMetadata).get();
      final cachedPostsCount = await select(cachedPosts).get();
      
      final tableCounts = <String, int>{
        'users': usersCount.length,
        'posts': postsCount.length,
        'comments': commentsCount.length,
        'notifications': notificationsCount.length,
        'cache': cacheCount.length,
        'analytics': analyticsCount.length,
        'app_metadata': appMetadataCount.length,
        'cached_posts': cachedPostsCount.length,
      };
      
      stats['table_counts'] = tableCounts;
      stats['total_records'] = tableCounts.values.fold(0, (sum, count) => sum + count);
      
      // Get database file size
      final path = await getDatabasePath();
      final file = File(path);
      if (await file.exists()) {
        final fileStat = await file.stat();
        stats['total_size_bytes'] = fileStat.size;
        stats['total_size_mb'] = fileStat.size / (1024 * 1024);
      } else {
        stats['total_size_bytes'] = 0;
        stats['total_size_mb'] = 0;
      }
      
      // Get PRAGMA info
      final pragmaResults = await Future.wait([
        customSelect('PRAGMA journal_mode').getSingle(),
        customSelect('PRAGMA cache_size').getSingle(),
        customSelect('PRAGMA page_size').getSingle(),
        customSelect('PRAGMA page_count').getSingle(),
        customSelect('PRAGMA foreign_keys').getSingle(),
      ]);
      
      stats['settings'] = {
        'journal_mode': pragmaResults[0].read<String>('journal_mode'),
        'cache_size_pages': pragmaResults[1].read<int>('cache_size'),
        'page_size_bytes': pragmaResults[2].read<int>('page_size'),
        'page_count': pragmaResults[3].read<int>('page_count'),
        'foreign_keys_enabled': pragmaResults[4].read<int>('foreign_keys') == 1,
      };
      
      // Calculate cache size in MB
      final pageSize = pragmaResults[2].read<int>('page_size');
      final cacheSizePages = pragmaResults[1].read<int>('cache_size');
      final cacheSizeKB = (pageSize * cacheSizePages.abs()) / 1024;
      stats['cache_size_kb'] = cacheSizeKB;
      
      // Get memory info
      if (_memoryManager != null) {
        try {
          final memoryInfo = await _memoryManager!.getMemoryInfo();
          stats['memory'] = {
            'used_mb': memoryInfo.usedMemMB,
            'available_mb': memoryInfo.availableMemMB,
            'total_mb': memoryInfo.totalMemMB,
            'used_percentage': memoryInfo.usedPercentage,
            'platform': memoryInfo.platform,
            'timestamp': memoryInfo.timestamp.toIso8601String(),
          };
        } catch (_) {
          stats['memory_error'] = 'Failed to get memory info';
        }
      }
      
      stats['success'] = true;
      stats['timestamp'] = DateTime.now().toIso8601String();
    } catch (e) {
      stats['error'] = e.toString();
      stats['success'] = false;
      stats['timestamp'] = DateTime.now().toIso8601String();
    }
    
    return stats;
  }
  
  // Get database file path
  Future<String> getDatabasePath() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return p.join(dbFolder.path, 'arina_cave.db');
  }
  
  @override
  int get schemaVersion => 1;
}

// In app_database.dart, try this:
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'arina_cave.db'));
    
    // Try simpler version
    return NativeDatabase(file);
    // Instead of: return NativeDatabase.createInBackground(file);
  });
}