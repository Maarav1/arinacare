// lib/core/sync/firebase_sync_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:arina_cave/core/database/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum SyncStrategy { lowBandwidth, offlineFirst, adaptive }

class DeviceProfile {
  final bool isLowRam;
  final int availableStorageMB;
  final String networkType;
  final double batteryLevel;

  DeviceProfile({
    required this.isLowRam,
    required this.availableStorageMB,
    required this.networkType,
    required this.batteryLevel,
  });
}

class ArinaFirebaseSyncService {
  final fs.FirebaseFirestore _firestore = fs.FirebaseFirestore.instance;
  final Connectivity _connectivity = Connectivity();
  final Battery _battery = Battery();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  final AppDatabase _localDb;
  DateTime? _lastSyncTime;

  ArinaFirebaseSyncService(this._localDb) {
    _loadLastSyncTime();
  }

  Future<void> _loadLastSyncTime() async {
    try {
      final prefs = await getApplicationDocumentsDirectory();
      final syncFile = File('${prefs.path}/last_sync.txt');
      if (await syncFile.exists()) {
        final content = await syncFile.readAsString();
        _lastSyncTime = DateTime.tryParse(content);
      }
    } catch (e) {
      if (kDebugMode) print('Failed to load last sync: $e');
    }
  }

  Future<void> _saveLastSyncTime() async {
    _lastSyncTime = DateTime.now();
    final prefs = await getApplicationDocumentsDirectory();
    final syncFile = File('${prefs.path}/last_sync.txt');
    await syncFile.writeAsString(_lastSyncTime!.toIso8601String());
  }

  Future<void> syncUserData(String userId,
      {SyncStrategy strategy = SyncStrategy.adaptive}) async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      final deviceProfile = await _getDeviceProfile();

      switch (strategy) {
        case SyncStrategy.lowBandwidth:
          await _syncLowBandwidth(userId, deviceProfile);
          break;
        case SyncStrategy.offlineFirst:
          await _syncOfflineFirst(userId);
          break;
        case SyncStrategy.adaptive:
          await _syncAdaptive(userId, connectivityResult, deviceProfile);
          break;
      }

      await _saveLastSyncTime();
    } catch (e) {
      if (kDebugMode) {
        print('Sync error: $e');
      }
      await _storeFailedSync(userId, e.toString());
    }
  }

  Future<DeviceProfile> _getDeviceProfile() async {
    try {
      final batteryLevel = await _battery.batteryLevel;
      final connectivityResult = await _connectivity.checkConnectivity();

      // Conservative default for storage
      final availableStorageMB = 200;

      bool isLowRam = true;
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        final features = androidInfo.systemFeatures;
        isLowRam = features.contains('android.hardware.ram.low') ||
            features.contains('low_ram');
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        final model = iosInfo.utsname.machine.toLowerCase();
        isLowRam = model.contains('iphone7') || model.contains('iphone8');
      }

      return DeviceProfile(
        isLowRam: isLowRam,
        availableStorageMB: availableStorageMB,
        networkType: connectivityResult.toString(),
        batteryLevel: batteryLevel.toDouble(),
      );
    } catch (e) {
      if (kDebugMode) print('Device profile error: $e');
      return DeviceProfile(
        isLowRam: true,
        availableStorageMB: 100,
        networkType: 'unknown',
        batteryLevel: 50.0,
      );
    }
  }

  Future<void> _syncAdaptive(
      String userId, List<ConnectivityResult> connectivityResult, DeviceProfile profile) async {
    // Check if any connectivity result is 'none'
    if (connectivityResult.contains(ConnectivityResult.none)) {
      await _generateOfflineInsights(userId);
      return;
    }

    if (profile.isLowRam || profile.batteryLevel < 20) {
      await _syncInMicroBatches(userId);
    } else if (connectivityResult.contains(ConnectivityResult.mobile)) {
      await _syncCompressed(userId);
    } else {
      await _syncFull(userId);
    }
  }

  Future<void> _syncLowBandwidth(String userId, DeviceProfile profile) async {
    await _syncEssentialData(userId);

    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    await _syncPostsSince(userId, weekAgo);
  }

  Future<void> _syncOfflineFirst(String userId) async {
    await _uploadLocalChanges(userId);
    await _syncEssentialData(userId);
  }

  Future<void> _syncInMicroBatches(String userId) async {
    const batchSize = 30;

    await _syncCollectionInBatches(
      collectionPath: 'users/$userId/posts',
      batchSize: batchSize,
      processItem: (fs.QueryDocumentSnapshot doc) async {
        final post = doc.data() as Map<String, dynamic>;
        await _savePostFromFirestore(doc.id, userId, post);
      },
    );

    await _syncCollectionInBatches(
      collectionPath: 'users/$userId/comments',
      batchSize: batchSize,
      processItem: (fs.QueryDocumentSnapshot doc) async {
        final comment = doc.data() as Map<String, dynamic>;
        await _saveCommentFromFirestore(doc.id, userId, comment);
      },
    );
  }

  Future<void> _syncCollectionInBatches({
    required String collectionPath,
    required int batchSize,
    required Future<void> Function(fs.QueryDocumentSnapshot) processItem,
  }) async {
    try {
      fs.QueryDocumentSnapshot? lastDoc;
      int processed = 0;

      while (true) {
        fs.Query query = _firestore
            .collection(collectionPath)
            .orderBy('createdAt', descending: true)
            .limit(batchSize);

        if (lastDoc != null) {
          query = query.startAfterDocument(lastDoc);
        }

        final snapshot = await query.get();

        if (snapshot.docs.isEmpty) break;

        for (final doc in snapshot.docs) {
          await processItem(doc);
          processed++;

          if (processed % 10 == 0) {
            await Future.delayed(const Duration(milliseconds: 10));
          }
        }

        lastDoc = snapshot.docs.last;

        if (processed % 100 == 0) {
          await _saveSyncProgress(collectionPath, processed);
        }

        if (snapshot.docs.length < batchSize) break;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error syncing collection $collectionPath: $e');
      }
    }
  }

  Future<void> _syncCompressed(String userId) async {
    await _syncEssentialData(userId);

    final since = _lastSyncTime ?? DateTime(2024);
    final postsSnapshot = await _firestore
        .collection('users/$userId/posts')
        .where('createdAt', isGreaterThan: fs.Timestamp.fromDate(since))
        .get();

    for (final doc in postsSnapshot.docs) {
      final data = doc.data();
      await _savePostFromFirestore(doc.id, userId, data);
    }
  }

  Future<void> _syncFull(String userId) async {
    await _syncUserProfile(userId);
    await _syncAllPosts(userId);
    await _syncAllComments(userId);
    await _syncAllNotifications(userId);
    await _syncAnalytics(userId);
  }

  Future<void> _syncEssentialData(String userId) async {
    await _syncUserProfile(userId);

    final postsSnapshot = await _firestore
        .collection('users/$userId/posts')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    for (final doc in postsSnapshot.docs) {
      await _savePostFromFirestore(doc.id, userId, doc.data());
    }

    await _syncUnreadNotifications(userId);
  }

  Future<void> _syncUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        await _localDb.into(_localDb.appUsers).insertOnConflictUpdate(
          AppUsersCompanion(
            id: drift.Value(userId),
            username: drift.Value(data['username'] ?? ''),
            email: drift.Value(data['email'] ?? ''),
            profileImage: drift.Value(data['profileImage'] as String?),
            isVerified: drift.Value((data['isVerified'] ?? false) as bool),
            createdAt: drift.Value((data['createdAt'] as fs.Timestamp?)?.toDate() ?? DateTime.now()),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Error syncing user profile: $e');
    }
  }

  Future<void> _syncAllPosts(String userId) async {
    await _syncCollectionInBatches(
      collectionPath: 'users/$userId/posts',
      batchSize: 100,
      processItem: (doc) => _savePostFromFirestore(doc.id, userId, doc.data() as Map<String, dynamic>),
    );
  }

  Future<void> _savePostFromFirestore(String firestoreId, String userId, Map<String, dynamic> data) async {
    try {
      // Save to Posts table
      await _localDb.into(_localDb.posts).insertOnConflictUpdate(
        PostsCompanion(
          userId: drift.Value(userId),
          content: drift.Value(data['content'] ?? ''),
          likes: drift.Value((data['likes'] ?? 0) as int),
          commentsCount: drift.Value((data['commentsCount'] ?? 0) as int),
          shares: drift.Value((data['shares'] ?? 0) as int),
          imageUrl: drift.Value(data['imageUrl'] as String?),
          videoUrl: drift.Value(data['videoUrl'] as String?),
          location: drift.Value(data['location'] as String?),
          isEdited: drift.Value((data['isEdited'] ?? false) as bool),
          createdAt: drift.Value((data['createdAt'] as fs.Timestamp?)?.toDate() ?? DateTime.now()),
        ),
      );

      // Also cache in CachedPosts table for quick access
      await _localDb.into(_localDb.cachedPosts).insertOnConflictUpdate(
        CachedPostsCompanion(
          firestoreId: drift.Value(firestoreId),
          data: drift.Value(json.encode(data)),
          cachedAt: drift.Value(DateTime.now()),
          lastAccessed: drift.Value(DateTime.now()),
        ),
      );
    } catch (e) {
      if (kDebugMode) print('Error saving post from Firestore: $e');
    }
  }

  Future<void> _saveCommentFromFirestore(String firestoreId, String userId, Map<String, dynamic> data) async {
    try {
      await _localDb.into(_localDb.comments).insertOnConflictUpdate(
        CommentsCompanion(
          postId: drift.Value(data['postId'] ?? ''),
          userId: drift.Value(userId),
          content: drift.Value(data['content'] ?? ''),
          likes: drift.Value((data['likes'] ?? 0) as int),
          isEdited: drift.Value((data['isEdited'] ?? false) as bool),
          createdAt: drift.Value((data['createdAt'] as fs.Timestamp?)?.toDate() ?? DateTime.now()),
        ),
      );
    } catch (e) {
      if (kDebugMode) print('Error saving comment from Firestore: $e');
    }
  }

  Future<void> _syncAllComments(String userId) async {
    await _syncCollectionInBatches(
      collectionPath: 'users/$userId/comments',
      batchSize: 100,
      processItem: (doc) async {
        final data = doc.data() as Map<String, dynamic>;
        await _saveCommentFromFirestore(doc.id, userId, data);
      },
    );
  }

  Future<void> _syncAllNotifications(String userId) async {
    await _syncCollectionInBatches(
      collectionPath: 'users/$userId/notifications',
      batchSize: 50,
      processItem: (doc) async {
        final data = doc.data() as Map<String, dynamic>;
        await _localDb.into(_localDb.notifications).insertOnConflictUpdate(
          NotificationsCompanion(
            userId: drift.Value(userId),
            type: drift.Value(data['type'] ?? ''),
            content: drift.Value(data['content'] ?? ''),
            referenceId: drift.Value(data['referenceId'] as String?),
            isRead: drift.Value((data['isRead'] ?? false) as bool),
            createdAt: drift.Value((data['createdAt'] as fs.Timestamp?)?.toDate() ?? DateTime.now()),
          ),
        );
      },
    );
  }

  Future<void> _syncUnreadNotifications(String userId) async {
    final snapshot = await _firestore
        .collection('users/$userId/notifications')
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      await _localDb.into(_localDb.notifications).insertOnConflictUpdate(
        NotificationsCompanion(
          userId: drift.Value(userId),
          type: drift.Value(data['type'] ?? ''),
          content: drift.Value(data['content'] ?? ''),
          referenceId: drift.Value(data['referenceId'] as String?),
          isRead: drift.Value((data['isRead'] ?? false) as bool),
          createdAt: drift.Value((data['createdAt'] as fs.Timestamp?)?.toDate() ?? DateTime.now()),
        ),
      );
    }
  }

  Future<void> _syncPostsSince(String userId, DateTime since) async {
    final snapshot = await _firestore
        .collection('users/$userId/posts')
        .where('createdAt', isGreaterThan: fs.Timestamp.fromDate(since))
        .orderBy('createdAt', descending: true)
        .get();

    for (final doc in snapshot.docs) {
      await _savePostFromFirestore(doc.id, userId, doc.data());
    }
  }

  Future<void> _syncAnalytics(String userId) async {
    try {
      final since = _lastSyncTime ?? DateTime(2024);
      final snapshot = await _firestore
          .collection('user_analytics')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThan: fs.Timestamp.fromDate(since))
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        await _localDb.into(_localDb.analytics).insertOnConflictUpdate(
          AnalyticsCompanion(
            event: drift.Value(data['event'] ?? ''),
            data: drift.Value(data['data']?.toString()),
            timestamp: drift.Value((data['timestamp'] as fs.Timestamp?)?.toDate() ?? DateTime.now()),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Error syncing analytics: $e');
    }
  }

  Future<void> _uploadLocalChanges(String userId) async {
    try {
      // Get local posts that haven't been synced
      final localPosts = await (_localDb.select(_localDb.posts)
        ..where((p) => p.userId.equals(userId))
        ..where((p) => p.createdAt.isNull() | (p.createdAt.isBiggerThanValue(
            DateTime.now().subtract(const Duration(days: 7)))))
        ..orderBy([(t) => drift.OrderingTerm(expression: t.createdAt, mode: drift.OrderingMode.desc)])
        ..limit(50))
          .get();

      for (final post in localPosts) {
        // Check if this post exists in CachedPosts (means it came from Firestore)
        final cachedPosts = await (_localDb.select(_localDb.cachedPosts)
          ..where((cp) => cp.data.like('%${post.id}%')))
            .get();

        // Only upload if not already in Firestore
        if (cachedPosts.isEmpty) {
          await _uploadSinglePost(userId, post);
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error in _uploadLocalChanges: $e');
    }
  }

  Future<void> _uploadSinglePost(String userId, Post post) async {
    try {
      // Generate or use existing Firestore ID
      final firestoreId = post.id.toString();
      final docRef = _firestore.collection('users/$userId/posts').doc(firestoreId);

      await docRef.set({
        'content': post.content,
        'userId': userId,
        'likes': post.likes,
        'commentsCount': post.commentsCount,
        'shares': post.shares,
        'imageUrl': post.imageUrl,
        'videoUrl': post.videoUrl,
        'location': post.location,
        'isEdited': post.isEdited,
        'createdAt': fs.FieldValue.serverTimestamp(),
        'updatedAt': fs.FieldValue.serverTimestamp(),
      }, fs.SetOptions(merge: true));

      // Update local cache
      await _localDb.into(_localDb.cachedPosts).insertOnConflictUpdate(
        CachedPostsCompanion(
          firestoreId: drift.Value(firestoreId),
          data: drift.Value(json.encode({
            'content': post.content,
            'likes': post.likes,
            'commentsCount': post.commentsCount,
            'shares': post.shares,
            'imageUrl': post.imageUrl,
            'videoUrl': post.videoUrl,
            'location': post.location,
            'isEdited': post.isEdited,
            'createdAt': post.createdAt.toIso8601String(),
          })),
          cachedAt: drift.Value(DateTime.now()),
          lastAccessed: drift.Value(DateTime.now()),
        ),
      );

      if (kDebugMode) {
        print('✅ Uploaded post: $firestoreId');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error uploading post: $e');
    }
  }

  Future<Map<String, dynamic>> _generateOfflineInsights(String userId) async {
    try {
      final recentPosts = await (_localDb.select(_localDb.posts)
        ..where((p) => p.userId.equals(userId))
        ..orderBy([(t) => drift.OrderingTerm(expression: t.createdAt, mode: drift.OrderingMode.desc)])
        ..limit(20))
          .get();

      final totalLikes = recentPosts.fold<int>(0, (acc, post) => acc + (post.likes));
      final totalComments = recentPosts.fold<int>(0, (acc, post) => acc + (post.commentsCount));
      final totalShares = recentPosts.fold<int>(0, (acc, post) => acc + (post.shares));

      return {
        'userId': userId,
        'totalPosts': recentPosts.length,
        'totalLikes': totalLikes,
        'totalComments': totalComments,
        'totalShares': totalShares,
        'avgEngagement': recentPosts.isNotEmpty ? (totalLikes + totalComments) / recentPosts.length : 0,
        'lastSync': _lastSyncTime?.toIso8601String(),
        'isOffline': true,
      };
    } catch (e) {
      if (kDebugMode) print('Error generating offline insights: $e');
      return {
        'userId': userId,
        'error': e.toString(),
        'isOffline': true,
      };
    }
  }

  Future<void> _storeFailedSync(String userId, String error) async {
    final prefs = await getApplicationDocumentsDirectory();
    final errorFile = File('${prefs.path}/sync_errors.json');

    List<Map<String, dynamic>> errors = [];
    if (await errorFile.exists()) {
      final content = await errorFile.readAsString();
      try {
        errors = List<Map<String, dynamic>>.from(json.decode(content));
      } catch (_) {
        errors = [];
      }
    }

    errors.add({
      'userId': userId,
      'error': error,
      'timestamp': DateTime.now().toIso8601String(),
    });

    await errorFile.writeAsString(json.encode(errors));
  }

  Future<void> _saveSyncProgress(String collection, int processed) async {
    final prefs = await getApplicationDocumentsDirectory();
    final progressFile = File('${prefs.path}/sync_progress.json');

    Map<String, dynamic> progress = {};
    if (await progressFile.exists()) {
      final content = await progressFile.readAsString();
      try {
        progress = Map<String, dynamic>.from(json.decode(content));
      } catch (_) {
        progress = {};
      }
    }

    progress[collection] = {
      'processed': processed,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await progressFile.writeAsString(json.encode(progress));
  }

  Future<Map<String, dynamic>> getOfflineInsights(String userId) async {
    return await _generateOfflineInsights(userId);
  }

  Future<Map<String, dynamic>> getSyncStatus(String userId) async {
    final connectivity = await _connectivity.checkConnectivity();
    final deviceProfile = await _getDeviceProfile();

    final bool isOnline = !connectivity.contains(ConnectivityResult.none);
    final bool canSync = isOnline && deviceProfile.batteryLevel > 15;

    return {
      'userId': userId,
      'isOnline': isOnline,
      'connectivity': connectivity.toString(),
      'lastSync': _lastSyncTime?.toIso8601String(),
      'deviceProfile': {
        'isLowRam': deviceProfile.isLowRam,
        'availableStorageMB': deviceProfile.availableStorageMB,
        'batteryLevel': deviceProfile.batteryLevel,
      },
      'canSync': canSync,
    };
  }

  Future<void> forceSync(String userId) async {
    await _syncFull(userId);
    await _saveLastSyncTime();
  }

  Future<void> clearLocalData(String userId) async {
    // Delete user-specific data
    await (_localDb.delete(_localDb.posts)..where((p) => p.userId.equals(userId))).go();
    await (_localDb.delete(_localDb.comments)..where((c) => c.userId.equals(userId))).go();
    await (_localDb.delete(_localDb.notifications)..where((n) => n.userId.equals(userId))).go();
    await (_localDb.delete(_localDb.appUsers)..where((u) => u.id.equals(userId))).go();

    // Clear cached posts for this user
    final cachedPosts = await _localDb.select(_localDb.cachedPosts).get();
    for (final cachedPost in cachedPosts) {
      try {
        final data = json.decode(cachedPost.data) as Map<String, dynamic>;
        if (data['userId'] == userId) {
          await (_localDb.delete(_localDb.cachedPosts)
            ..where((cp) => cp.firestoreId.equals(cachedPost.firestoreId)))
              .go();
        }
      } catch (_) {
        // Skip if JSON decode fails
      }
    }

    _lastSyncTime = null;
    final prefs = await getApplicationDocumentsDirectory();
    final syncFile = File('${prefs.path}/last_sync.txt');
    if (await syncFile.exists()) {
      await syncFile.delete();
    }
  }

  // Helper method to check if user exists locally
  Future<bool> userExistsLocally(String userId) async {
    final user = await (_localDb.select(_localDb.appUsers)..where((u) => u.id.equals(userId))).getSingleOrNull();
    return user != null;
  }

  // Get user profile from local database
  Future<AppUser?> getUserProfile(String userId) async {
    return await (_localDb.select(_localDb.appUsers)..where((u) => u.id.equals(userId))).getSingleOrNull();
  }

  // Get user posts from local database
  Future<List<Post>> getUserPosts(String userId, {int limit = 50}) async {
    return await (_localDb.select(_localDb.posts)
      ..where((p) => p.userId.equals(userId))
      ..orderBy([(t) => drift.OrderingTerm(expression: t.createdAt, mode: drift.OrderingMode.desc)])
      ..limit(limit))
        .get();
  }

  // Get user notifications from local database
  Future<List<Notification>> getUserNotifications(String userId, {bool unreadOnly = false, int limit = 20}) async {
    final query = _localDb.select(_localDb.notifications)
      ..where((n) => n.userId.equals(userId))
      ..orderBy([(t) => drift.OrderingTerm(expression: t.createdAt, mode: drift.OrderingMode.desc)])
      ..limit(limit);

    if (unreadOnly) {
      query.where((n) => n.isRead.equals(false));
    }

    return await query.get();
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(int notificationId) async {
    await (_localDb.update(_localDb.notifications)..where((n) => n.id.equals(notificationId))).write(
      NotificationsCompanion(isRead: drift.Value(true)),
    );
  }

  // Add analytics event
  Future<void> addAnalyticsEvent(String event, {Map<String, dynamic>? data}) async {
    await _localDb.into(_localDb.analytics).insert(
      AnalyticsCompanion(
        event: drift.Value(event),
        data: drift.Value(data?.toString()),
        timestamp: drift.Value(DateTime.now()),
      ),
    );
  }

  // Cache management
  Future<void> clearOldCache({int daysOld = 7}) async {
    final cutoff = DateTime.now().subtract(Duration(days: daysOld));
    await (_localDb.delete(_localDb.cache)..where((c) => c.lastAccessed.isSmallerThanValue(cutoff))).go();
    await (_localDb.delete(_localDb.cachedPosts)..where((cp) => cp.lastAccessed.isSmallerThanValue(cutoff))).go();
  }

  // Get sync statistics
  Future<Map<String, dynamic>> getSyncStats(String userId) async {
    final userPosts = await (_localDb.select(_localDb.posts)..where((p) => p.userId.equals(userId))).get();
    final userComments = await (_localDb.select(_localDb.comments)..where((c) => c.userId.equals(userId))).get();
    final userNotifications = await (_localDb.select(_localDb.notifications)..where((n) => n.userId.equals(userId))).get();

    return {
      'userId': userId,
      'localPosts': userPosts.length,
      'localComments': userComments.length,
      'localNotifications': userNotifications.length,
      'lastSync': _lastSyncTime?.toIso8601String(),
      'hasUserProfile': await userExistsLocally(userId),
    };
  }
}