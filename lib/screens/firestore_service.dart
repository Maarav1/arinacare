import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> createPost(Map<String, dynamic> postData) async {
    await _firestore.collection('posts').add(postData);
  }
}