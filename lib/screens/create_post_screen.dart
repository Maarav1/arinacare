import 'dart:io';
import 'package:arina_cave/constants/app_constants.dart' as constants;
import 'package:arina_cave/screens/image_picker_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  File? _selectedImage;
  bool _isUploading = false;
  bool _isSubmitting = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    // Auto-focus the content field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _contentFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await ImagePickerService.pickImage();
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _selectedImage = null;
    });
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'post_images/${user.uid}_$timestamp.jpg';
      final ref = _storage.ref().child(fileName);

      setState(() {
        _isUploading = true;
        _uploadProgress = 0;
      });

      final uploadTask = ref.putFile(_selectedImage!);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      await uploadTask;
      final downloadUrl = await ref.getDownloadURL();

      setState(() {
        _isUploading = false;
        _uploadProgress = 0;
      });

      return downloadUrl;
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0;
      });
      _showError('Failed to upload image: $e');
      return null;
    }
  }

  Future<void> _createPost() async {
    if (_contentController.text.trim().isEmpty && _selectedImage == null) {
      _showError('Please add some text or an image to your post');
      return;
    }

    if (_contentController.text.length > constants.AppConstants.maxPostLength) {
      _showError(
          'Post is too long. Maximum ${constants.AppConstants.maxPostLength} characters allowed.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showError('Please sign in to create a post');
        setState(() => _isSubmitting = false);
        return;
      }

      // Get user details
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      final String userName = userData?['fullName'] ??
          userData?['firstName'] ??
          user.email?.split('@')[0] ??
          'Anonymous';
      final String userEmail = user.email ?? '';
      final String profilePictureUrl = userData?['profilePictureUrl'] ?? '';

      // Upload image if selected
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImage();
        if (imageUrl == null) {
          setState(() => _isSubmitting = false);
          return;
        }
      }

      // Create post data
      final postData = {
        'content': _contentController.text.trim(),
        'imageUrl': imageUrl,
        'userId': user.uid,
        'userName': userName,
        'userEmail': userEmail,
        'profilePictureUrl': profilePictureUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': 0,
        'likedBy': [],
        'comments': [],
        'commentsCount': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save to Firestore
      await _firestore.collection('posts').add(postData);

      // Show success and navigate back
      _showSuccess('Post created successfully!');
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError('Failed to create post: $e');
      setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          IconButton(
            onPressed: _isSubmitting ? null : _createPost,
            icon: _isSubmitting
                ? const CircularProgressIndicator()
                : const Icon(Icons.send),
            tooltip: 'Post',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User info
              _buildUserInfo(),
              const SizedBox(height: 16),

              // Content text field
              TextField(
                controller: _contentController,
                focusNode: _contentFocusNode,
                maxLines: null,
                maxLength: constants.AppConstants.maxPostLength,
                decoration: InputDecoration(
                  hintText: "What's on your mind?",
                  border: InputBorder.none,
                  counterText: '',
                ),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),

              // Character counter
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${_contentController.text.length}/${constants.AppConstants.maxPostLength}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _contentController.text.length >
                              constants.AppConstants.maxPostLength
                          ? Colors.red
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Selected image preview
              if (_selectedImage != null) _buildImagePreview(),
              if (_isUploading) _buildUploadProgress(),

              // Image picker buttons
              _buildImagePickerButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    final user = _auth.currentUser;
    return FutureBuilder<DocumentSnapshot>(
      future: user != null
          ? _firestore.collection('users').doc(user.uid).get()
          : null,
      builder: (context, snapshot) {
        String? profileImageUrl;
        String userName = 'Anonymous';

        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          profileImageUrl = userData['profilePictureUrl'];
          userName = userData['fullName'] ??
              userData['firstName'] ??
              user?.email?.split('@')[0] ??
              'Anonymous';
        }

        return Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: profileImageUrl != null
                  ? CachedNetworkImageProvider(profileImageUrl)
                  : null,
              backgroundColor: Colors.blue.shade100,
              child: profileImageUrl == null
                  ? Icon(
                      Icons.person,
                      color: Colors.blue.shade700,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              userName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey[200],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _selectedImage!,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: _removeImage,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadProgress() {
    return Column(
      children: [
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: _uploadProgress,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
        ),
        const SizedBox(height: 8),
        Text(
          'Uploading image... ${(_uploadProgress * 100).toStringAsFixed(0)}%',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildImagePickerButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: _isSubmitting || _isUploading ? null : _pickImage,
          icon: const Icon(Icons.photo_library),
          label: const Text('Gallery'),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.blue.shade700,
          ),
        ),
        ElevatedButton.icon(
          onPressed: _isSubmitting || _isUploading
              ? null
              : () async {
                  try {
                    final image =
                        await ImagePicker().pickImage(source: ImageSource.camera);
                    if (image != null) {
                      setState(() {
                        _selectedImage = File(image.path);
                      });
                    }
                  } catch (e) {
                    _showError('Failed to take photo: $e');
                  }
                },
          icon: const Icon(Icons.camera_alt),
          label: const Text('Camera'),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.green.shade700,
          ),
        ),
      ],
    );
  }
}