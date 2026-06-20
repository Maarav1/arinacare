// lib/services/firebase_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FirebaseService {
  static FirebaseService? _instance;

  factory FirebaseService() {
    _instance ??= FirebaseService._internal();
    return _instance!;
  }

  FirebaseService._internal();

  // Get Firebase instances
  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  // Check if Firebase is available on current platform
  bool get isFirebaseAvailable {
    // On web, Firebase is available if we're not in a test environment
    if (kIsWeb) return true;
    // On mobile, check if Firebase is initialized
    return true; // Or add specific checks
  }

  // Check if user is authenticated
  bool get isAuthenticated => FirebaseAuth.instance.currentUser != null;
}
