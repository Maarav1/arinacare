import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';

class UserProfile {
  final String uid;
  final String? firstName;
  final String? lastName;
  final String? profilePictureUrl;
  final String? gender;
  final String? relationshipStatus;
  final String? occupation;
  final String? educationLevel;
  final String? countryOfOrigin;
  final String? city;
  final String? countryOfResidence;
  final String? interestedIn;
  final List<String>? hobbies;
  final String? email;
  final String? phoneNumber;
  final DateTime? updatedAt;
  final DateTime? dateOfBirth;
  final int likesCount;
  final bool isOnline;

  UserProfile({
    required this.uid,
    this.firstName,
    this.lastName,
    this.profilePictureUrl,
    this.gender,
    this.relationshipStatus,
    this.occupation,
    this.educationLevel,
    this.countryOfOrigin,
    this.city,
    this.countryOfResidence,
    this.interestedIn,
    this.hobbies,
    this.email,
    this.phoneNumber,
    this.updatedAt,
    this.dateOfBirth,
    this.likesCount = 0,
    this.isOnline = false,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserProfile(
      uid: doc.id,
      firstName: data['firstName'],
      lastName: data['lastName'],
      profilePictureUrl: data['profilePictureUrl'],
      gender: data['gender'],
      relationshipStatus: data['relationshipStatus'],
      occupation: data['occupation'],
      educationLevel: data['educationLevel'],
      countryOfOrigin: data['countryOfOrigin'],
      city: data['city'],
      countryOfResidence: data['countryOfResidence'],
      interestedIn: data['interestedIn'],
      hobbies: List<String>.from(data['hobbies'] ?? []),
      email: data['email'],
      phoneNumber: data['phoneNumber'],
      updatedAt: data['updatedAt']?.toDate(),
      dateOfBirth: data['dateOfBirth']?.toDate(),
      likesCount: data['likesCount'] ?? 0,
      isOnline: data['isOnline'] ?? false,
    );
  }

  String get fullName =>
      [firstName, lastName].where((n) => n != null).join(' ').trim();
  String get location =>
      [city, countryOfResidence].where((l) => l != null).join(', ');

  int? get age {
    if (dateOfBirth == null) return null;

    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;

    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }

    return age;
  }
}

class ProfileScreen extends StatefulWidget {
  final String? userId;

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final ImagePicker _picker = ImagePicker();

  UserProfile? _userProfile;
  bool _isLoading = true;
  bool _isCurrentUser = false;
  bool _hasError = false;
  File? _newProfileImage;
  bool _isLiked = false;
  bool _isFriend = false;
  bool _friendRequestPending = false;
  int _likesCount = 0;
  bool _isPerformingAction = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        setState(() => _hasError = true);
        return;
      }

      final targetUserId = widget.userId ?? currentUserId;
      _isCurrentUser = targetUserId == currentUserId;

      // Redirect if viewing own profile with userId parameter
      if (widget.userId != null && widget.userId == currentUserId) {
        if (mounted) {
          context.go('/profile');
          return;
        }
      }

      final doc = await _firestore.collection('users').doc(targetUserId).get();
      
      if (!doc.exists) {
        setState(() => _hasError = true);
        _showSnackBar('User profile not found');
        return;
      }

      final userProfile = UserProfile.fromFirestore(doc);
      
      setState(() {
        _userProfile = userProfile;
        _likesCount = userProfile.likesCount;
      });

      if (!_isCurrentUser) {
        await _loadSocialStatus(targetUserId);
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      setState(() => _hasError = true);
      _showSnackBar('Failed to load profile');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _shareProfile() {
    if (_userProfile == null) return;
    
    final profileUrl = 'https://maarav1.github.io/denis-marav/profile/${_userProfile!.uid}';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this link:'),
            const SizedBox(height: 8),
            SelectableText(
              profileUrl,
              style: const TextStyle(color: Colors.blue),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: profileUrl));
              _showSnackBar('Link copied to clipboard');
              Navigator.pop(context);
            },
            child: const Text('Copy Link'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSocialStatus(String targetUserId) async {
    final currentUserId = _auth.currentUser!.uid;
    
    final likeDoc = await _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('likes')
        .doc(currentUserId)
        .get();
    
    setState(() => _isLiked = likeDoc.exists);
    
    await _checkFriendStatus(targetUserId);
  }

  Future<void> _checkFriendStatus(String targetUserId) async {
    final currentUserId = _auth.currentUser!.uid;

    final friendDoc = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('friends')
        .doc(targetUserId)
        .get();

    if (friendDoc.exists) {
      setState(() => _isFriend = true);
      return;
    }

    final requestQuery = await _firestore
        .collection('friend_requests')
        .where('from', isEqualTo: currentUserId)
        .where('to', isEqualTo: targetUserId)
        .where('status', isEqualTo: 'pending')
        .get();

    setState(() => _friendRequestPending = requestQuery.docs.isNotEmpty);
  }

  Future<void> _toggleLike() async {
    if (_isPerformingAction || _isCurrentUser || _auth.currentUser == null || _userProfile == null) {
      return;
    }

    setState(() => _isPerformingAction = true);

    // Optimistic UI update
    final wasLiked = _isLiked;
    final oldLikesCount = _likesCount;
    
    setState(() {
      _isLiked = !_isLiked;
      _likesCount = _isLiked ? _likesCount + 1 : _likesCount - 1;
    });

    try {
      final currentUserId = _auth.currentUser!.uid;
      final targetUserId = _userProfile!.uid;

      final likeRef = _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('likes')
          .doc(currentUserId);

      if (wasLiked) {
        await _firestore.runTransaction((transaction) async {
          transaction.delete(likeRef);
          transaction.update(_firestore.collection('users').doc(targetUserId), {
            'likesCount': FieldValue.increment(-1),
          });
        });
      } else {
        await _firestore.runTransaction((transaction) async {
          transaction.set(likeRef, {
            'timestamp': FieldValue.serverTimestamp(),
            'likerId': currentUserId,
          });
          transaction.update(_firestore.collection('users').doc(targetUserId), {
            'likesCount': FieldValue.increment(1),
          });
        });
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
      // Revert optimistic update on error
      setState(() {
        _isLiked = wasLiked;
        _likesCount = oldLikesCount;
      });
      _showSnackBar('Failed to update like');
    } finally {
      setState(() => _isPerformingAction = false);
    }
  }

  Future<void> _sendFriendRequest() async {
    if (_isPerformingAction || _isCurrentUser || _auth.currentUser == null || _userProfile == null) {
      return;
    }

    setState(() => _isPerformingAction = true);

    try {
      // Try Cloud Function first
      try {
        final HttpsCallable callable = _functions.httpsCallable('sendFriendRequest');
        final result = await callable.call({
          'toUserId': _userProfile!.uid,
          'toUserName': _userProfile!.fullName,
        }).timeout(const Duration(seconds: 10));
        
        if (result.data['success'] == true) {
          _showSnackBar('Friend request sent successfully');
          setState(() => _friendRequestPending = true);
          return;
        } else {
          throw Exception(result.data['error'] ?? 'Unknown error');
        }
      } on FirebaseFunctionsException catch (e) {
        debugPrint('Cloud Function error: ${e.code} - ${e.message}');
        // Fall through to Firestore implementation
      } on TimeoutException {
        debugPrint('Cloud Function timeout');
        // Fall through to Firestore implementation
      }

      // Fallback to direct Firestore
      final requestId = '${_auth.currentUser!.uid}_${_userProfile!.uid}';
      
      // Check if request already exists
      final existingRequest = await _firestore.collection('friend_requests').doc(requestId).get();
      if (existingRequest.exists) {
        _showSnackBar('Friend request already sent');
        setState(() => _friendRequestPending = true);
        return;
      }

      await _firestore.collection('friend_requests').doc(requestId).set({
        'from': _auth.currentUser!.uid,
        'to': _userProfile!.uid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'fromName': _auth.currentUser?.displayName ?? 'Unknown User',
        'toName': _userProfile!.fullName,
      });

      _showSnackBar('Friend request sent successfully');
      setState(() => _friendRequestPending = true);
    } catch (e) {
      debugPrint('Error sending friend request: $e');
      _showSnackBar('Failed to send friend request');
    } finally {
      setState(() => _isPerformingAction = false);
    }
  }

  Future<String?> _uploadProfileImage(String userId) async {
    if (_newProfileImage == null) return null;

    try {
      // Validate file size (max 5MB)
      final fileSize = await _newProfileImage!.length();
      if (fileSize > 5 * 1024 * 1024) {
        _showSnackBar('Image too large. Please select an image under 5MB.');
        return null;
      }

      final functionsUrl = 'https://us-central1-lifematters-c466d.cloudfunctions.net/generateCloudinarySignature';

      final response = await http.post(
        Uri.parse(functionsUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Failed to get upload signature: ${response.statusCode}');
      }

      final responseData = json.decode(response.body);

      if (responseData['success'] != true) {
        throw Exception('Cloud Function returned error: ${responseData['error']}');
      }

      final signature = responseData['signature'] as String;
      final timestamp = responseData['timestamp'].toString();
      final apiKey = responseData['api_key'] as String;
      final cloudName = responseData['cloud_name'] as String;
      final folder = responseData['folder'] as String;

      final uploadUrl = 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl))
        ..fields['api_key'] = apiKey
        ..fields['timestamp'] = timestamp
        ..fields['signature'] = signature
        ..fields['folder'] = folder
        ..files.add(await http.MultipartFile.fromPath(
          'file', 
          _newProfileImage!.path,
          filename: 'profile_$widget.userId${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));

      final cloudinaryResponse = await request.send().timeout(const Duration(seconds: 30));
      final responseDataString = await cloudinaryResponse.stream.bytesToString();
      final jsonResponse = json.decode(responseDataString);

      if (cloudinaryResponse.statusCode == 200) {
        return jsonResponse['secure_url'] as String;
      } else {
        final errorMsg = jsonResponse['error']?['message'] ?? 'Upload failed with status ${cloudinaryResponse.statusCode}';
        throw Exception('Cloudinary upload failed: $errorMsg');
      }
    } catch (e) {
      debugPrint('Error uploading to Cloudinary: $e');
      _showSnackBar('Failed to upload image: ${e.toString()}');
      return null;
    }
  }

  Future<File?> _compressImage(File imageFile) async {
    return imageFile;
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final compressedImage = await _compressImage(File(pickedFile.path));
        setState(() => _newProfileImage = compressedImage);
        await _updateProfilePicture();
      }
    } catch (e) {
      _showSnackBar('Failed to pick image: ${e.toString()}');
    }
  }

  Future<void> _updateProfilePicture() async {
    if (_newProfileImage == null) return;

    try {
      setState(() => _isLoading = true);

      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final profileImageUrl = await _uploadProfileImage(userId);
      if (profileImageUrl != null) {
        await _firestore.collection('users').doc(userId).update({
          'profilePictureUrl': profileImageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await _loadUserData();
        _showSnackBar('Profile picture updated successfully');
      }
    } catch (e) {
      debugPrint('Error updating profile picture: $e');
      _showSnackBar('Failed to update profile picture: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
        _newProfileImage = null;
      });
    }
  }

  Future<void> _navigateToEditProfile() async {
    final shouldRefresh = await context.pushNamed<bool>('edit-profile');
    if (shouldRefresh == true && mounted) {
      await _loadUserData();
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        )
      );
    }
  }

  Widget _buildActionButtons() {
    if (_isCurrentUser || _isLoading) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: _isPerformingAction 
          ? const CircularProgressIndicator()
          : Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                // Like button
                ElevatedButton.icon(
                  onPressed: _toggleLike,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isLiked ? Colors.pink[50] : null,
                    foregroundColor: _isLiked ? Colors.pink : null,
                  ),
                  icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border),
                  label: Text('Like ($_likesCount)'),
                ),
                
                // Message button
                ElevatedButton.icon(
                  onPressed: () => _sendMessage(context),
                  icon: const Icon(Icons.message),
                  label: const Text('Message'),
                ),
                
                // Share button
                ElevatedButton.icon(
                  onPressed: _shareProfile,
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                ),
                
                // Friend request button
                if (!_isFriend)
                  ElevatedButton.icon(
                    onPressed: _friendRequestPending ? null : _sendFriendRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _friendRequestPending ? Colors.grey[300] : null,
                    ),
                    icon: Icon(_friendRequestPending ? Icons.check : Icons.person_add),
                    label: Text(_friendRequestPending ? 'Request Sent' : 'Add Friend'),
                  ),
                
                // Friends indicator
                if (_isFriend)
                  ElevatedButton.icon(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[50],
                      foregroundColor: Colors.green,
                    ),
                    icon: const Icon(Icons.person),
                    label: const Text('Friends'),
                  ),
              ],
            ),
    );
  }

  Future<void> _sendMessage(BuildContext context) async {
    if (_auth.currentUser == null || _userProfile == null) {
      _showSnackBar('Please sign in to send messages');
      return;
    }

    if (_isCurrentUser) {
      _showSnackBar('You cannot message yourself');
      return;
    }

    final messageController = TextEditingController();
    bool isSending = false;

    await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            insetPadding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Message ${_userProfile?.firstName ?? ''}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: TextField(
                        controller: messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type your message here...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(16),
                        ),
                        maxLines: null,
                        minLines: 3,
                        maxLength: 500,
                        autofocus: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.favorite, color: Colors.red),
                          onPressed: () {
                            final currentText = messageController.text;
                            final selection = messageController.selection;
                            final newText = currentText.replaceRange(
                              selection.start,
                              selection.end,
                              '❤️',
                            );
                            messageController.text = newText;
                            messageController.selection = TextSelection.fromPosition(
                              TextPosition(offset: selection.start + 2),
                            );
                          },
                        ),
                        Row(
                          children: [
                            if (isSending)
                              const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ElevatedButton(
  onPressed: messageController.text.trim().isNotEmpty && !isSending
      ? () {
          setState(() => isSending = true);
          // Close immediately without delay since we're already showing loading state
          if (mounted) {
            Navigator.pop(context, true);
          }
        }
      : null,
  child: isSending 
      ? const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        )
      : const Text('Send'),
),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ).then((result) async {
      if (result == true && messageController.text.trim().isNotEmpty) {
        await _sendMessageToUser(messageController.text.trim());
      }
    });
  }

  Future<void> _sendMessageToUser(String message) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null || _userProfile == null) return;

      final currentUserId = currentUser.uid;
      final targetUserId = _userProfile!.uid;

      final participants = [currentUserId, targetUserId]..sort();
      final chatRoomId = participants.join('_');

      final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
      final currentUserData = currentUserDoc.data();
      
      final senderName = currentUserData?['firstName'] ?? 'Unknown User';
      final senderAvatar = currentUserData?['profilePictureUrl'] ?? '';

      await _firestore.collection('chat_rooms').doc(chatRoomId).set({
        'participants': participants,
        'participantNames': {
          currentUserId: senderName,
          targetUserId: _userProfile!.fullName,
        },
        'participantAvatars': {
          currentUserId: senderAvatar,
          targetUserId: _userProfile!.profilePictureUrl ?? '',
        },
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': currentUserId,
        'unreadCount': {
          targetUserId: FieldValue.increment(1),
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .add({
        'content': message,
        'senderId': currentUserId,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
        'isRead': false,
        'chatRoomId': chatRoomId,
      });

      _showSnackBar('Message sent successfully');
      
      if (mounted) {
        context.push('/chat/$chatRoomId');
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      _showSnackBar('Failed to send message: ${e.toString()}');
    }
  }

  double get _profileCompletion {
    if (_userProfile == null) return 0.0;
    
    final fields = [
      _userProfile!.firstName,
      _userProfile!.lastName,
      _userProfile!.profilePictureUrl,
      _userProfile!.gender,
      _userProfile!.relationshipStatus,
      _userProfile!.occupation,
      _userProfile!.educationLevel,
      _userProfile!.countryOfOrigin,
      _userProfile!.city,
      _userProfile!.countryOfResidence,
      _userProfile!.interestedIn,
      _userProfile!.hobbies?.isNotEmpty == true,
    ];
    
    final completedFields = fields.where((field) {
      if (field is String) return field.isNotEmpty;
      if (field is bool) return field == true;
      return field != null;
    }).length;
    
    return completedFields / fields.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isCurrentUser ? 'My Profile' : 'Profile'),
        leading: widget.userId != null 
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              )
            : null,
        actions: [
          if (_isCurrentUser)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _navigateToEditProfile,
              tooltip: 'Edit Profile',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: _isLoading && _userProfile == null
            ? _buildShimmerLoader()
            : CustomScrollView(
                slivers: [
                  if (_hasError || _userProfile == null)
                    SliverFillRemaining(child: _buildErrorState())
                  else
                    SliverList(
                      delegate: SliverChildListDelegate([
                        const SizedBox(height: 16),
                        _buildProfileHeader(),
                        const SizedBox(height: 16),
                        _buildActionButtons(),
                        const SizedBox(height: 16),
                        _buildProfileContent(),
                      ]),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildShimmerLoader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          children: [
            const SizedBox(height: 16),
            CircleAvatar(radius: 60, backgroundColor: Colors.white),
            const SizedBox(height: 16),
            Container(width: 200, height: 24, color: Colors.white),
            const SizedBox(height: 8),
            Container(width: 150, height: 16, color: Colors.white),
            const SizedBox(height: 32),
            ...List.generate(
              5,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _isCurrentUser ? 'Create your profile' : 'Profile not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            if (_isCurrentUser)
              FilledButton(
                onPressed: _navigateToEditProfile,
                child: const Text('Get Started'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        GestureDetector(
          onTap: _isCurrentUser ? _pickImage : null,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[200],
                backgroundImage: _userProfile?.profilePictureUrl != null
                    ? CachedNetworkImageProvider(_userProfile!.profilePictureUrl!)
                    : null,
                child: _userProfile?.profilePictureUrl == null
                    ? const Icon(Icons.person, size: 50, color: Colors.grey)
                    : null,
              ),
              if (_isLoading && _newProfileImage != null)
                const Positioned.fill(
                  child: CircularProgressIndicator()
                ),
              if (_isCurrentUser && !_isLoading)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, size: 16, color: Colors.white),
                ),
              if (_userProfile?.isOnline == true)
                Positioned(
                  bottom: _isCurrentUser ? 20 : 0,
                  right: _isCurrentUser ? 20 : 0,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _userProfile?.fullName ?? 'No Name',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        if (_userProfile != null && _userProfile!.location.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _userProfile!.location,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ),
        ],
        if (_userProfile?.age != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${_userProfile!.age} years',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite, color: Colors.pink, size: 16),
              const SizedBox(width: 4),
              Text(
                '$_likesCount likes',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (_isCurrentUser && _profileCompletion < 1.0) ...[
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _navigateToEditProfile,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _profileCompletion,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _profileCompletion > 0.7 ? Colors.green : 
                      _profileCompletion > 0.4 ? Colors.orange : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Profile ${(_profileCompletion * 100).toStringAsFixed(0)}% complete - Tap to improve!',
                    style: TextStyle(
                      fontSize: 12,
                      color: _profileCompletion > 0.7 ? Colors.green : 
                            _profileCompletion > 0.4 ? Colors.orange : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProfileContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildSectionCard(
            title: 'About Me',
            children: [
              _buildInfoRow('Gender', _userProfile?.gender),
              _buildInfoRow('Relationship', _userProfile?.relationshipStatus),
              _buildInfoRow('Occupation', _userProfile?.occupation),
              _buildInfoRow('Education', _userProfile?.educationLevel),
              _buildInfoRow('From', _userProfile?.countryOfOrigin),
              _buildInfoRow('Lives in', _userProfile?.location),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Looking For',
            children: [
              Text(
                _userProfile?.interestedIn ?? 'Not specified',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          if ((_userProfile?.hobbies?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 16),
            _buildHobbiesSection(),
          ],
          if (_isCurrentUser) ...[
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Private Information',
              children: [
                _buildInfoRow('Email', _userProfile?.email),
                _buildInfoRow('Phone', _userProfile?.phoneNumber),
              ],
            ),
          ],
          if (_userProfile?.updatedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 32),
              child: Text(
                'Last updated: ${_userProfile!.updatedAt!.toString().split(' ')[0]}',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildHobbiesSection() {
    return _buildSectionCard(
      title: 'Hobbies & Interests',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _userProfile!.hobbies!
              .map((hobby) => Chip(
                    label: Text(hobby),
                    backgroundColor: Colors.blue[50],
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}