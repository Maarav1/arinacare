// lib/features/browser/data/services/hive_service.dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:arina_cave/features/browser/domain/models/browser_tab.dart';
import 'package:arina_cave/features/browser/domain/models/browser_settings.dart';
import 'package:arina_cave/features/browser/domain/models/engagement_metrics.dart';

class HiveService {
  static const String tabsBox = 'browser_tabs';
  static const String settingsBox = 'browser_settings';
  static const String metricsBox = 'browser_metrics';  // Changed from 'engagement_metrics'
  static const String bookmarksBox = 'browser_bookmarks';
  static const String historyBox = 'browser_history';
  
  static Future<void> init() async {
    // Don't call Hive.initFlutter() here - it's already called in main.dart
    // Just register adapters and open boxes
    
    // Register adapters - NO typeId parameter
    Hive.registerAdapter(BrowserTabAdapter());
    Hive.registerAdapter(BrowserSettingsAdapter());
    Hive.registerAdapter(EngagementMetricsAdapter());
    
    // Open boxes
    await Hive.openBox<BrowserTab>(tabsBox);
    await Hive.openBox<BrowserSettings>(settingsBox);
    await Hive.openBox<EngagementMetrics>(metricsBox);
    await Hive.openBox(bookmarksBox);
    await Hive.openBox(historyBox);
    
    // Initialize default settings if not exists
    await _initializeDefaultSettings();
  }
  
  static Future<void> _initializeDefaultSettings() async {
    final box = Hive.box<BrowserSettings>(settingsBox);
    
    if (box.isEmpty) {
      final defaultSettings = BrowserSettings();
      await box.put('main', defaultSettings);
    }
  }
  
  static Future<void> clearAllData() async {
    final tabsBox = await Hive.openBox<BrowserTab>('browser_tabs');
    await tabsBox.clear();
    
    final settingsBox = await Hive.openBox<BrowserSettings>('browser_settings');
    await settingsBox.clear();
    
    final metricsBox = await Hive.openBox<EngagementMetrics>('browser_metrics');
    await metricsBox.clear();
    
    final bookmarksBox = await Hive.openBox('browser_bookmarks');
    await bookmarksBox.clear();
    
    final historyBox = await Hive.openBox('browser_history');
    await historyBox.clear();
  }
}