import 'dart:convert';
import 'dart:io';

import 'package:arina_cave/constants/app_constants.dart';
import 'package:arina_cave/core/models/post_model.dart';
import 'package:arina_cave/core/services/auto_delete_service.dart';
import 'package:arina_cave/core/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _controller = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  File? _image;
  bool _isUploading = false;
  bool _hasError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (pickedFile != null && mounted) {
        setState(() => _image = File(pickedFile.path));
      }
    } catch (e) {
      _showError('Failed to pick image: ${e.toString()}');
    }
  }

  Future<String?> _uploadImage() async {
    if (_image == null) return null;

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('generateCloudinarySignature');
      final results = await callable();

      final signature = results.data['signature'];
      final timestamp = results.data['timestamp'].toString();
      final apiKey = results.data['api_key'];
      final cloudName = results.data['cloud_name'];
      final folder = results.data['folder'];

      final uploadUrl = 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl))
        ..fields['api_key'] = apiKey
        ..fields['timestamp'] = timestamp
        ..fields['signature'] = signature
        ..fields['folder'] = folder
        ..files.add(await http.MultipartFile.fromPath('file', _image!.path));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseData);

      if (response.statusCode == 200) {
        return jsonResponse['secure_url'];
      } else {
        throw Exception('Upload failed: ${jsonResponse['error']?['message']}');
      }
    } catch (e) {
      throw Exception('Image upload failed: ${e.toString()}');
    }
  }

  Future<void> _submitPost() async {
    if (_controller.text.trim().isEmpty && _image == null) {
      _showError('Please add text or an image to post');
      return;
    }

    if (_controller.text.length > AppConstants.maxPostLength) {
      _showError('Post is too long. Maximum ${AppConstants.maxPostLength} characters allowed.');
      return;
    }

    if (_isUploading) return;

    setState(() {
      _isUploading = true;
      _hasError = false;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final imageUrl = await _uploadImage();
      final now = DateTime.now();

      // Get user profile data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final profileImageUrl = userDoc.data()?['profilePictureUrl'] ?? '';
      final userName = user.displayName ?? userDoc.data()?['fullName'] ?? 'User';

      final post = PostModel(
        id: FirebaseFirestore.instance.collection('posts').doc().id,
        content: _controller.text.trim(),
        imageUrl: imageUrl ?? '',
        userId: user.uid,
        userName: userName,
        userEmail: user.email ?? '',
        profileImageUrl: profileImageUrl,
        videoUrl: null,
        location: null,
        shares: 0,
        isEdited: false,
        timestamp: now,
        createdAt: now,
        updatedAt: now,
        likes: 0,
        likedBy: [],
        comments: [],
        commentsCount: 0,
      );

      await FirestoreService.createPost(post);
      await AutoDeleteService.schedulePostAutoDelete(post.id);

      if (mounted) {
        _showSuccess(AppConstants.successPostCreate);
        Navigator.pop(context, true);
      }
    } catch (e) {
      _setErrorState();
      _showError('${AppConstants.errorPostCreate}: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }
  void _setErrorState() {
    if (mounted) {
      setState(() => _hasError = true);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Content Input
                TextField(
                  controller: _controller,
                  maxLength: AppConstants.maxPostLength,
                  minLines: 3,
                  maxLines: 8,
                  decoration: InputDecoration(
                    hintText: "What's happening?",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 16),

                // Image Preview
                if (_image != null)
                  Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _image!,
                          height: 250,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _image = null),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove Image'),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),

                // Error State
                if (_hasError)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Failed to create post. Please try again.',
                            style: TextStyle(color: Colors.red.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Add Photo'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isUploading ? null : _submitPost,
                        icon: _isUploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                        label: Text(_isUploading ? 'Posting...' : 'Post'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}