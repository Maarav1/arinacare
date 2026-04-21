import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:io';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  File? _newProfileImage;
  String? _currentProfileImageUrl;
  bool _isLoading = false;
  bool _isSaving = false;

  // Form fields
  late String _firstName;
  late String _lastName;
  late String _gender;
  late String _interestedIn;
  late String _relationshipStatus;
  late String _occupation;
  late String _educationLevel;
  late String _countryOfOrigin;
  late String _countryOfResidence;
  late String _city;
  late String _phoneNumber;
  late List<String> _hobbies;
  DateTime? _dateOfBirth;

  // Constants
  static const List<String> _genderOptions = ['Male', 'Female', 'Other'];
  static const List<String> _interestedInOptions = [
    'Marriage',
    'Dating',
    'Relationship',
    'Friendship',
  ];
  static const List<String> _relationshipOptions = [
    'Single',
    'Married',
    'Divorced',
    'Widowed',
    'Single Parent',
    'Other',
  ];
  static const List<String> _occupationOptions = [
    'Employed',
    'Business',
    'Student',
    'Unemployed',
    'Retired',
  ];
  static const List<String> _educationOptions = [
    'Primary',
    'Secondary',
    'Diploma',
    'Degree',
    'Masters',
    'PhD',
  ];
  static const List<String> _hobbyOptions = [
    'Reading',
    'Sports',
    'Music',
    'Travel',
    'Cooking',
    'Gardening',
    'Photography',
  ];

  @override
  void initState() {
    super.initState();
    _initializeFormFields();
    _loadCurrentProfile();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _initializeFormFields() {
    _firstName = '';
    _lastName = '';
    _gender = _genderOptions.first;
    _interestedIn = _interestedInOptions.last;
    _relationshipStatus = _relationshipOptions.first;
    _occupation = _occupationOptions.first;
    _educationLevel = _educationOptions[1];
    _countryOfOrigin = '';
    _countryOfResidence = '';
    _city = '';
    _phoneNumber = '';
    _hobbies = [];
  }

  Future<void> _loadCurrentProfile() async {
    setState(() => _isLoading = true);
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _firstName = data['firstName'] ?? '';
          _lastName = data['lastName'] ?? '';
          _gender = data['gender'] ?? _genderOptions.first;
          _interestedIn = data['interestedIn'] ?? _interestedInOptions.last;
          _relationshipStatus =
              data['relationshipStatus'] ?? _relationshipOptions.first;
          _occupation = data['occupation'] ?? _occupationOptions.first;
          _educationLevel = data['educationLevel'] ?? _educationOptions[1];
          _countryOfOrigin = data['countryOfOrigin'] ?? '';
          _countryOfResidence = data['countryOfResidence'] ?? '';
          _city = data['city'] ?? '';
          _phoneNumber = data['phoneNumber'] ?? '';
          _hobbies = List<String>.from(data['hobbies'] ?? []);
          _currentProfileImageUrl = data['profilePictureUrl'];
          if (data['dateOfBirth'] != null) {
            _dateOfBirth = (data['dateOfBirth'] as Timestamp).toDate();
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() => _newProfileImage = File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: ${e.toString()}')),
        );
      }
    }
  }

  Future<String?> _uploadProfileImage(String userId) async {
    if (_newProfileImage == null) return _currentProfileImageUrl;

    try {
      // Delete old image if it exists
      if (_currentProfileImageUrl != null) {
        try {
          await _storage.refFromURL(_currentProfileImageUrl!).delete();
        } catch (e) {
          debugPrint('Error deleting old image: $e');
        }
      }

      // Upload new image
      final storageRef = _storage.ref().child('profile_pictures/$userId.jpg');
      await storageRef.putFile(_newProfileImage!);
      final url = await storageRef.getDownloadURL();

      // Clear cache for this image
      await CachedNetworkImage.evictFromCache(url);

      return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: ${e.toString()}')),
        );
      }
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Upload new image if selected
      final profileImageUrl = await _uploadProfileImage(userId);

      // Prepare update data
      final updateData = {
        'firstName': _firstName,
        'lastName': _lastName,
        'gender': _gender,
        'interestedIn': _interestedIn,
        'relationshipStatus': _relationshipStatus,
        'occupation': _occupation,
        'educationLevel': _educationLevel,
        'countryOfOrigin': _countryOfOrigin,
        'countryOfResidence': _countryOfResidence,
        'city': _city,
        'phoneNumber': _phoneNumber,
        'hobbies': _hobbies,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add date of birth if it exists
      if (_dateOfBirth != null) {
        updateData['dateOfBirth'] = Timestamp.fromDate(_dateOfBirth!);
      }

      // Add profile image URL if available
      if (profileImageUrl != null) {
        updateData['profilePictureUrl'] = profileImageUrl;
      }

      await _firestore.collection('users').doc(userId).update(updateData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );

      // Navigate back and force refresh
      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _dateOfBirth ??
          DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _dateOfBirth) {
      setState(() => _dateOfBirth = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          IconButton(
            icon:
                _isSaving
                    ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveProfile,
            tooltip: 'Save Profile',
          ),
        ],
      ),
      body:
          _isLoading
              ? _buildShimmerLoader()
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Profile Picture Section
                      _buildProfilePictureSection(),
                      const SizedBox(height: 24),

                      // Personal Information Section
                      _buildPersonalInfoSection(),
                      const SizedBox(height: 16),

                      // About Me Section
                      _buildAboutMeSection(),
                      const SizedBox(height: 16),

                      // Hobbies Section
                      if (_hobbyOptions.isNotEmpty) ...[
                        _buildHobbiesSection(),
                        const SizedBox(height: 16),
                      ],

                      // Location Section
                      _buildLocationSection(),
                      const SizedBox(height: 16),

                      // Contact Section
                      _buildContactSection(),
                      const SizedBox(height: 24),

                      // Save Button
                      _buildSaveButton(),
                    ],
                  ),
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
            ...List.generate(
              10,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePictureSection() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[200],
                backgroundImage:
                    _newProfileImage != null
                        ? FileImage(_newProfileImage!)
                        : _currentProfileImageUrl != null
                        ? NetworkImage(_currentProfileImageUrl!)
                        : null,
                child:
                    _newProfileImage == null && _currentProfileImageUrl == null
                        ? const Icon(Icons.person, size: 50)
                        : null,
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, size: 16, color: Colors.white),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: _pickImage,
          child: const Text('Change Profile Picture'),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoSection() {
    return Column(
      children: [
        TextFormField(
          initialValue: _firstName,
          decoration: const InputDecoration(
            labelText: 'First Name*',
            border: OutlineInputBorder(),
          ),
          validator: (val) => val?.isEmpty ?? true ? 'Required' : null,
          onChanged: (val) => _firstName = val,
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _lastName,
          decoration: const InputDecoration(
            labelText: 'Last Name*',
            border: OutlineInputBorder(),
          ),
          validator: (val) => val?.isEmpty ?? true ? 'Required' : null,
          onChanged: (val) => _lastName = val,
        ),
        const SizedBox(height: 16),
        ListTile(
          title: Text(
            _dateOfBirth == null
                ? 'Select Date of Birth'
                : 'Date of Birth: ${_dateOfBirth!.toLocal()}'.split(' ')[0],
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: () => _selectDate(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: Colors.grey[400]!),
          ),
        ),
      ],
    );
  }

  Widget _buildAboutMeSection() {
    return Column(
      children: [
        _buildDropdownFormField(
          'Gender*',
          _gender,
          _genderOptions,
          (val) => _gender = val!,
        ),
        const SizedBox(height: 16),
        _buildDropdownFormField(
          'Relationship Status',
          _relationshipStatus,
          _relationshipOptions,
          (val) => _relationshipStatus = val!,
        ),
        const SizedBox(height: 16),
        _buildDropdownFormField(
          'Interested In',
          _interestedIn,
          _interestedInOptions,
          (val) => _interestedIn = val!,
        ),
        const SizedBox(height: 16),
        _buildDropdownFormField(
          'Occupation',
          _occupation,
          _occupationOptions,
          (val) => _occupation = val!,
        ),
        const SizedBox(height: 16),
        _buildDropdownFormField(
          'Education Level',
          _educationLevel,
          _educationOptions,
          (val) => _educationLevel = val!,
        ),
      ],
    );
  }

  Widget _buildHobbiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hobbies & Interests',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              _hobbyOptions
                  .map(
                    (hobby) => FilterChip(
                      label: Text(hobby),
                      selected: _hobbies.contains(hobby),
                      onSelected:
                          (selected) => setState(() {
                            selected
                                ? _hobbies.add(hobby)
                                : _hobbies.remove(hobby);
                          }),
                    ),
                  )
                  .toList(),
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Column(
      children: [
        TextFormField(
          initialValue: _countryOfOrigin,
          decoration: const InputDecoration(
            labelText: 'Country of Origin',
            border: OutlineInputBorder(),
          ),
          onChanged: (val) => _countryOfOrigin = val,
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _countryOfResidence,
          decoration: const InputDecoration(
            labelText: 'Country of Residence',
            border: OutlineInputBorder(),
          ),
          onChanged: (val) => _countryOfResidence = val,
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _city,
          decoration: const InputDecoration(
            labelText: 'City/Town',
            border: OutlineInputBorder(),
          ),
          onChanged: (val) => _city = val,
        ),
      ],
    );
  }

  Widget _buildContactSection() {
    return TextFormField(
      initialValue: _phoneNumber,
      decoration: const InputDecoration(
        labelText: 'Phone Number',
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.phone,
      onChanged: (val) => _phoneNumber = val,
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: _isSaving ? null : _saveProfile,
        child:
            _isSaving
                ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                : const Text('SAVE PROFILE', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildDropdownFormField(
    String label,
    String initialValue,
    List<String> items,
    ValueChanged<String?> onChanged, {
    String? hintText,
    String? Function(String?)? validator,
    bool isRequired = false,
  }) {
    return DropdownButtonFormField<String>(
      value: initialValue, // Changed from initialValue to value
      decoration: InputDecoration(
        labelText: isRequired ? '$label*' : label,
        border: const OutlineInputBorder(),
        hintText: hintText,
      ),
      items:
          items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
      onChanged: onChanged,
      validator:
          validator ??
          (isRequired
              ? (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select $label';
                }
                return null;
              }
              : null),
    );
  }
}
