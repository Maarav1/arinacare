
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  int _unreadCount = 0;
  
  int get unreadCount => _unreadCount;
  
  NotificationProvider() {
    _startListening();
  }
  
  void _startListening() {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _setupNotificationStream(user.uid);
      } else {
        _unreadCount = 0;
        notifyListeners();
      }
    });
  }
  
  void _setupNotificationStream(String userId) {
    _firestore
        .collection('notifications')
        .where('targetUserId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      _unreadCount = snapshot.docs.length;
      notifyListeners();
    });
  }
  
  void markAllAsRead() {
    _unreadCount = 0;
    notifyListeners();
  }
}