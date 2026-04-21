// lib/core/memory/memory_manager.dart
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class ArinaMemoryManager {
  static final ArinaMemoryManager _instance = ArinaMemoryManager._internal();
  factory ArinaMemoryManager() => _instance;
  ArinaMemoryManager._internal();

  static const MethodChannel _channel = MethodChannel('arina.memory');
  bool _isMonitoring = false;
  StreamController<MemoryPressureLevel>? _pressureController;
  Timer? _monitoringTimer;

  // Initialize memory monitoring
  Future<void> initialize() async {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    _pressureController = StreamController<MemoryPressureLevel>.broadcast();
    
    _startMonitoring();
  }

  // Start periodic monitoring
  void _startMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = Timer.periodic(Duration(seconds: 15), (_) async {
      try {
        final pressure = await getMemoryPressure();
        _pressureController?.add(pressure);
        
        // Auto cleanup based on pressure
        await _handleMemoryPressure(pressure);
      } catch (e) {
        if (kDebugMode) print('Memory monitoring error: $e');
      }
    });
  }

  // Get memory pressure level
  Future<MemoryPressureLevel> getMemoryPressure() async {
    try {
      final result = await _channel.invokeMethod<int>('getMemoryPressure');
      if (result != null) {
        return MemoryPressureLevel.values[result.clamp(0, MemoryPressureLevel.values.length - 1)];
      }
    } catch (e) {
      if (kDebugMode) print('Native memory pressure failed: $e');
    }
    
    // Fallback to estimation
    return await _estimateMemoryPressure();
  }

  // Get detailed memory information
  Future<MemoryInfo> getMemoryInfo() async {
    try {
      final data = await _channel.invokeMethod<Map<dynamic, dynamic>>('getMemoryInfo');
      if (data != null) {
        return MemoryInfo.fromMap(Map<String, dynamic>.from(data));
      }
    } catch (e) {
      if (kDebugMode) print('Memory info error: $e');
    }
    
    return await _estimateMemoryInfo();
  }

  // Get memory statistics
  Future<MemoryStats> getMemoryStats() async {
    try {
      final data = await _channel.invokeMethod<Map<dynamic, dynamic>>('getMemoryStats');
      if (data != null) {
        return MemoryStats.fromMap(Map<String, dynamic>.from(data));
      }
    } catch (e) {
      if (kDebugMode) print('Memory stats error: $e');
    }
    
    return MemoryStats.empty();
  }

  // Monitor memory pressure stream
  Stream<MemoryPressureLevel> monitorMemoryPressure() {
    initialize();
    return _pressureController!.stream;
  }

  // Handle memory pressure changes
  Future<void> _handleMemoryPressure(MemoryPressureLevel pressure) async {
    switch (pressure) {
      case MemoryPressureLevel.critical:
        await triggerEmergencyCleanup();
        break;
      case MemoryPressureLevel.high:
        await _performProactiveCleanup();
        break;
      case MemoryPressureLevel.medium:
        await _performLightCleanup();
        break;
      default:
        break;
    }
  }

  // Emergency cleanup
  Future<void> triggerEmergencyCleanup() async {
    if (kDebugMode) print('🚨 EMERGENCY MEMORY CLEANUP');
    
    await Future.wait([
      clearImageCache(),
      _clearTempFiles(),
      _cleanupDatabaseCache(),
      _requestGarbageCollection(),
    ], eagerError: false);
    
    if (kDebugMode) print('✅ Emergency cleanup completed');
  }

  // Proactive cleanup
  Future<void> _performProactiveCleanup() async {
    if (kDebugMode) print('🔄 Proactive memory cleanup');
    
    await Future.wait([
      _clearOldCacheFiles(hours: 24),
      _trimDatabase(),
    ], eagerError: false);
  }

  // Light cleanup
  Future<void> _performLightCleanup() async {
    await _clearOldCacheFiles(hours: 72);
  }

  // Clear image cache
  Future<void> clearImageCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDirs = [
        '${tempDir.path}/image_cache',
        '${tempDir.path}/CachedImageData',
        '${tempDir.path}/libCachedImageData',
      ];
      
      for (final dirPath in cacheDirs) {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
    } catch (e) {
      if (kDebugMode) print('Image cache error: $e');
    }
  }

  // Clear temporary files
  Future<void> _clearTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cutoff = DateTime.now().subtract(Duration(hours: 1));
      
      final files = await tempDir.list().toList();
      for (final file in files) {
        if (file is File) {
          try {
            final stat = await file.stat();
            if (stat.modified.isBefore(cutoff)) {
              await file.delete();
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      if (kDebugMode) print('Temp files error: $e');
    }
  }

  // Clear old cache files
  Future<void> _clearOldCacheFiles({required int hours}) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cutoff = DateTime.now().subtract(Duration(hours: hours));
      
      final files = await tempDir.list().toList();
      for (final file in files) {
        if (file is File) {
          try {
            final stat = await file.stat();
            if (stat.modified.isBefore(cutoff)) {
              await file.delete();
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      if (kDebugMode) print('Old cache error: $e');
    }
  }

  // Cleanup database cache
  Future<void> _cleanupDatabaseCache() async {
    // Implementation depends on your database setup
    await Future.delayed(Duration(milliseconds: 100));
  }

  // Trim database
  Future<void> _trimDatabase() async {
    // Implementation depends on your database setup
    await Future.delayed(Duration(milliseconds: 100));
  }

  // Request garbage collection
  Future<void> _requestGarbageCollection() async {
    try {
      await Isolate.run(() {
        final largeList = List<int>.filled(1000000, 0);
        largeList.clear();
        return Future.value();
      });
      await Future.delayed(Duration(milliseconds: 100));
    } catch (_) {}
  }

  // Estimate memory pressure (fallback)
  Future<MemoryPressureLevel> _estimateMemoryPressure() async {
    try {
      final stats = await getMemoryStats();
      final availableMB = stats.available;
      
      if (availableMB < 50) return MemoryPressureLevel.critical;
      if (availableMB < 100) return MemoryPressureLevel.high;
      if (availableMB < 200) return MemoryPressureLevel.medium;
      return MemoryPressureLevel.low;
    } catch (_) {
      return MemoryPressureLevel.unknown;
    }
  }

  // Estimate memory info (fallback)
  Future<MemoryInfo> _estimateMemoryInfo() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final appDir = await getApplicationDocumentsDirectory();
      
      final tempSize = await _getDirectorySize(tempDir);
      final appSize = await _getDirectorySize(appDir);
      
      return MemoryInfo(
        usedMemMB: (tempSize + appSize) ~/ (1024 * 1024),
        availableMemMB: 500, // Estimated
        totalMemMB: 1000, // Estimated
        platform: Platform.operatingSystem,
        timestamp: DateTime.now(),
      );
    } catch (_) {
      return MemoryInfo.empty();
    }
  }

  // Get directory size
  Future<int> _getDirectorySize(Directory dir) async {
    try {
      if (!await dir.exists()) return 0;
      
      var total = 0;
      final files = await dir.list(recursive: true).toList();
      
      for (final file in files) {
        if (file is File) {
          try {
            total += (await file.stat()).size;
          } catch (_) {}
        }
      }
      
      return total;
    } catch (_) {
      return 0;
    }
  }

  // Check if operation should proceed
  Future<bool> shouldProceedWithOperation(OperationType operation) async {
    final pressure = await getMemoryPressure();
    
    switch (operation) {
      case OperationType.imageProcessing:
        return pressure.index <= MemoryPressureLevel.high.index;
      case OperationType.fileDownload:
        return pressure.index <= MemoryPressureLevel.medium.index;
      case OperationType.databaseQuery:
        return pressure.index <= MemoryPressureLevel.critical.index;
      case OperationType.analyticsProcessing:
        return pressure.index <= MemoryPressureLevel.low.index;
    }
  }

  // Optimize for operation
  Future<void> optimizeForOperation(OperationType operation) async {
    switch (operation) {
      case OperationType.imageProcessing:
        await clearImageCache();
        break;
      case OperationType.fileDownload:
        await _clearTempFiles();
        break;
      case OperationType.databaseQuery:
        await _cleanupDatabaseCache();
        break;
      default:
        break;
    }
  }

  // Dispose
  Future<void> dispose() async {
    _isMonitoring = false;
    _monitoringTimer?.cancel();
    await _pressureController?.close();
    _pressureController = null;
  }
}

// Models
enum MemoryPressureLevel {
  low,        // 0
  medium,     // 1
  high,       // 2
  critical,   // 3
  unknown,    // 4
}

enum OperationType {
  imageProcessing,
  fileDownload,
  databaseQuery,
  analyticsProcessing,
}

class MemoryInfo {
  final int usedMemMB;
  final int availableMemMB;
  final int totalMemMB;
  final String platform;
  final DateTime timestamp;
  
  MemoryInfo({
    required this.usedMemMB,
    required this.availableMemMB,
    required this.totalMemMB,
    required this.platform,
    required this.timestamp,
  });
  
  factory MemoryInfo.fromMap(Map<String, dynamic> map) {
    return MemoryInfo(
      usedMemMB: (map['usedMemMB'] ?? 0).toInt(),
      availableMemMB: (map['availableMemMB'] ?? 0).toInt(),
      totalMemMB: (map['totalMemMB'] ?? 0).toInt(),
      platform: map['platform'] ?? 'unknown',
      timestamp: map['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch((map['timestamp'] as num).toInt())
          : DateTime.now(),
    );
  }
  
  factory MemoryInfo.empty() {
    return MemoryInfo(
      usedMemMB: 0,
      availableMemMB: 0,
      totalMemMB: 0,
      platform: 'unknown',
      timestamp: DateTime.now(),
    );
  }
  
  double get usedPercentage => totalMemMB > 0 
      ? (usedMemMB * 100.0) / totalMemMB 
      : 0.0;
}

class MemoryStats {
  final int current;
  final int available;
  final int total;
  final int pressure;
  final bool isCritical;
  final DateTime timestamp;
  
  MemoryStats({
    required this.current,
    required this.available,
    required this.total,
    required this.pressure,
    required this.isCritical,
    required this.timestamp,
  });
  
  factory MemoryStats.fromMap(Map<String, dynamic> map) {
    return MemoryStats(
      current: (map['current'] ?? 0).toInt(),
      available: (map['available'] ?? 0).toInt(),
      total: (map['total'] ?? 0).toInt(),
      pressure: (map['pressure'] ?? 0).toInt(),
      isCritical: map['isCritical'] ?? false,
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch((map['timestamp'] as num).toInt())
          : DateTime.now(),
    );
  }
  
  factory MemoryStats.empty() {
    return MemoryStats(
      current: 0,
      available: 0,
      total: 0,
      pressure: 0,
      isCritical: false,
      timestamp: DateTime.now(),
    );
  }
}