import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class GeminiService {
  // 1. Private constructor
  GeminiService._internal();
  
  // 2. The single instance everyone uses
  static final GeminiService instance = GeminiService._internal();

  String _apiKey = '';
  bool _isInitialized = false;

  // 3. Initialize ONCE when the app starts
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await dotenv.load(fileName: ".env"); // Ensure this is loaded
      _apiKey = dotenv.get('GEMINI_API_KEY', fallback: '');
      
      if (_apiKey.isNotEmpty) {
        _isInitialized = true;
        if (kDebugMode) print('🚀 Gemini Service Initialized Globally');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Failed to init Gemini Service: $e');
    }
  }

  bool get isReady => _isInitialized && _apiKey.isNotEmpty;
  String get apiKey => _apiKey;
}