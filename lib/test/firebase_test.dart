// lib/test/firebase_test.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseTestScreen extends StatelessWidget {
  const FirebaseTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                try {
                  // Test Auth
                  final user = FirebaseAuth.instance.currentUser;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        user != null
                            ? '✅ User: ${user.email}'
                            : '⚠️ No user logged in',
                      ),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
                }
              },
              child: const Text('Check Auth Status'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Test Firestore
                  final doc =
                      await FirebaseFirestore.instance
                          .collection('test')
                          .doc('test_doc')
                          .get();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        doc.exists
                            ? '✅ Firestore connected!'
                            : '⚠️ Document not found but connected',
                      ),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
                }
              },
              child: const Text('Test Firestore'),
            ),
          ],
        ),
      ),
    );
  }
}
