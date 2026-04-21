// core/providers/database_provider.dart
import 'package:flutter/foundation.dart';
import 'package:arina_cave/core/database/app_database.dart';

class DatabaseProvider extends ChangeNotifier {
  AppDatabase? _database;
  bool _isInitializing = false;
  String? _error;
  
  // Minimal getters
  bool get isInitializing => _isInitializing;
  bool get isInitialized => _database != null;
  String? get error => _error;
  
  // Simple initialize that WON'T hang
  Future<void> initialize() async {
    if (_isInitializing || _database != null) return;
    
    _isInitializing = true;
    _error = null;
    notifyListeners();
    
    try {
      if (kDebugMode) print('🔄 Starting database...');
      
      // SIMPLE initialization - no extra dependencies
      _database = await AppDatabase.create();
      
      // Quick test query
      await _database!.select(_database!.appMetadata).get();
      
      _isInitializing = false;
      
      if (kDebugMode) {
        print('✅ Database ready');
        await _database!.printStats();
      }
      
      notifyListeners();
      
    } catch (e) {
      _isInitializing = false;
      _error = e.toString();
      
      if (kDebugMode) {
        print('⚠️ Database warning: $e');
        print('⚠️ App continues without database');
      }
      
      notifyListeners();
      
      // DON'T rethrow - let app continue
    }
  }
  
  // Safe database access
  AppDatabase? get database => _database;
  
  // Safe query execution
  Future<T?> safeQuery<T>(Future<T> Function(AppDatabase db) query) async {
    if (_database == null) return null;
    
    try {
      return await query(_database!);
    } catch (e) {
      if (kDebugMode) print('Query failed: $e');
      return null;
    }
  }
  
  // Error handling for main.dart
  void setError(String error) {
    _error = error;
    notifyListeners();
  }
  
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  void markAsInitialized() {
    _error = null;
    _isInitializing = false;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _database?.close();
    super.dispose();
  }
}