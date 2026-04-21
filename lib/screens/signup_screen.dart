import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:http/http.dart' as http;

// Import your services
import '../services/validation_service.dart';
import '../constants/app_constants.dart';
import '../widgets/signup_form_fields.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  // State variables
  File? _profileImage;
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _emailVerified = false;
  bool _agreedToTerms = false;
  bool _obscurePassword = true;

  // Form fields
  String _firstName = '';
  String _lastName = '';
  String _gender = AppConstants.genderOptions.first;
  String _interestedIn = AppConstants.interestedInOptions.first;
  String _relationshipStatus = AppConstants.relationshipOptions.first;
  String _occupation = AppConstants.occupationOptions.first;
  String _educationLevel = AppConstants.educationOptions.first;
  String _countryOfOrigin = '';
  String _countryOfResidence = '';
  String _city = '';
  String _email = '';
  String _password = '';
  String _phoneNumber = '';
  final List<String> _hobbies = [];
  DateTime? _dateOfBirth;

  // Focus nodes
  final FocusNode _firstNameFocus = FocusNode();
  final FocusNode _lastNameFocus = FocusNode();
  final FocusNode _countryOriginFocus = FocusNode();
  final FocusNode _countryResidenceFocus = FocusNode();
  final FocusNode _cityFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  // Scroll controller
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    
    // Dispose focus nodes
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _countryOriginFocus.dispose();
    _countryResidenceFocus.dispose();
    _cityFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _scrollController.dispose();
    
    super.dispose();
  }

  // Forgot Password Dialog - Simple scrollable solution
  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController();
    
    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20), // Add some padding
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 400, // Limit maximum height
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Reset Password',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Enter your email address to receive a password reset link:',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      autofocus: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(dialogContext, false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              final email = emailController.text.trim();
                              if (email.isEmpty || !email.contains('@')) {
                                ScaffoldMessenger.of(dialogContext).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid email address')),
                                );
                                return;
                              }
                              // Close keyboard before dismissing
                              FocusScope.of(dialogContext).unfocus();
                              Navigator.pop(dialogContext, true);
                            },
                            child: const Text('Send Reset Link'),
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
      },
    );

    if (shouldSend == true && mounted) {
      await _sendPasswordResetEmail(emailController.text.trim());
    }
  }

  Future<void> _sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      
      if (mounted) {
        _showSuccessSnackBar('Password reset email sent! Check your inbox.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to send reset email: ${e.toString()}');
      }
    }
  }

  // Image Picking with File Size Validation
  Future<void> _pickImage() async {
    try {
      FocusScope.of(context).unfocus();

      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: AppConstants.maxImageSize,
        maxHeight: AppConstants.maxImageSize,
        imageQuality: AppConstants.imageQuality,
      );
      
      if (pickedFile != null && mounted) {
        final file = File(pickedFile.path);
        
        // Validate file size (5MB limit)
        if (file.lengthSync() > 5 * 1024 * 1024) {
          _showErrorSnackBar('Image must be less than 5MB');
          return;
        }
        
        setState(() => _profileImage = file);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to pick image: ${e.toString()}');
      }
    }
  }

  Future<String?> _uploadProfileImage(String userId) async {
    if (_profileImage == null) return null;

    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'generateCloudinarySignature',
      );

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
        ..files.add(
          await http.MultipartFile.fromPath('file', _profileImage!.path),
        );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseData);

      if (response.statusCode == 200) {
        return jsonResponse['secure_url'];
      } else {
        throw 'Upload failed: ${response.reasonPhrase}';
      }
    } catch (e) {
      debugPrint('Error uploading to Cloudinary: $e');
      throw 'Image upload failed: ${e.toString()}';
    }
  }

  Future<void> _saveUserData(String userId, String? profileImageUrl) async {
    final userData = <String, dynamic>{
      'firstName': _firstName,
      'lastName': _lastName,
      'fullName': '$_firstName $_lastName',
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
      'userEmail': _email,
      'profilePictureUrl': profileImageUrl,
      'isOnline': true,
      'emailVisibility': false,
      'phoneVisibility': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (_dateOfBirth != null) {
      userData['dateOfBirth'] = Timestamp.fromDate(_dateOfBirth!);
    }

    await _firestore.collection('users').doc(userId).set(userData);
  }

  // Enhanced Signup with Comprehensive Validation
  Future<void> _signUp() async {
    // Use ValidationService for comprehensive validation
    final validationResults = ValidationService.validateSignupForm(
      firstName: _firstName,
      lastName: _lastName,
      email: _email,
      password: _password,
      countryOfOrigin: _countryOfOrigin,
      countryOfResidence: _countryOfResidence,
      city: _city,
      dateOfBirth: _dateOfBirth,
      hobbies: _hobbies,
      profileImage: _profileImage,
      agreedToTerms: _agreedToTerms,
      phoneNumber: _phoneNumber,
    );

    if (!ValidationService.isFormValid(validationResults)) {
      final firstError = ValidationService.getFirstValidationError(validationResults);
      _showErrorSnackBar(firstError ?? 'Please fix validation errors');
      return;
    }

    if (!_agreedToTerms) {
      _showErrorSnackBar('You must agree to the terms and conditions');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      // Create user with email and password (standard authentication)
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _email,
        password: _password,
      );

      // Upload profile image
      final profileImageUrl = await _uploadProfileImage(userCredential.user!.uid);
      
      // Save user data to Firestore
      await _saveUserData(userCredential.user!.uid, profileImageUrl);
      
      // Send email verification (standard verification email)
      await userCredential.user!.sendEmailVerification();

      if (mounted) {
        setState(() {
          _emailVerified = false;
          _isSubmitting = false;
        });
        _showSuccessSnackBar('Account created! Verification email sent. Please check your inbox.');
        
        // Show verification screen
        _showVerificationScreen();
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'This email is already registered. Please sign in instead.';
          break;
        case 'weak-password':
          errorMessage = 'Password is too weak. Please choose a stronger password.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address. Please check and try again.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password accounts are not enabled. Please contact support.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your connection and try again.';
          break;
        default:
          errorMessage = 'Signup failed: ${e.message}';
      }
      _showErrorSnackBar(errorMessage);
      setState(() => _isSubmitting = false);
    } catch (e) {
      _showErrorSnackBar('An unexpected error occurred: ${e.toString()}');
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _checkEmailVerification() async {
    setState(() => _isLoading = true);
    try {
      // Reload user to get latest verification status
      await _auth.currentUser?.reload();
      final currentUser = _auth.currentUser;
      
      if (currentUser != null && currentUser.emailVerified) {
        setState(() => _emailVerified = true);
        if (mounted) {
          _showSuccessSnackBar('Email verified successfully!');
          // Navigate to home screen
          context.go('/home');
        }
      } else {
        if (mounted) {
          _showErrorSnackBar('Email not verified yet. Please check your inbox.');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error checking verification: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showVerificationScreen() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.mark_email_read, color: Colors.blue),
            SizedBox(width: 8),
            Text('Verify Your Email'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'We\'ve sent a verification email to:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              _email,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.blue,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Please check your inbox and click the verification link to activate your account.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                children: [
                  Icon(Icons.sip, color: Colors.blue, size: 24),
                  SizedBox(height: 8),
                  Text(
                    'Tip: Check your spam folder if you don\'t see the email',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Go to login screen
              context.go('/login');
            },
            child: const Text('Go to Login'),
          ),
          FilledButton(
            onPressed: () {
              _resendVerificationEmail();
              Navigator.pop(context);
            },
            child: const Text('Resend Email'),
          ),
          FilledButton(
            onPressed: _checkEmailVerification,
            child: const Text('I\'ve Verified'),
          ),
        ],
      ),
    );
  }

  Future<void> _resendVerificationEmail() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        _showSuccessSnackBar('Verification email resent!');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to resend verification: ${e.toString()}');
    }
  }

  Future<void> _selectDate() async {
    FocusScope.of(context).unfocus();
    
    await Future.delayed(AppConstants.keyboardDismissDelay);
    
    if (!mounted) return;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(viewInsets: EdgeInsets.zero),
          child: Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(
                primary: Colors.blue,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
              dialogTheme: DialogThemeData(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: Colors.white,
                elevation: 4,
              ),
              textTheme: const TextTheme(
                bodyLarge: TextStyle(color: Colors.black87),
                bodyMedium: TextStyle(color: Colors.black87),
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null && picked != _dateOfBirth && mounted) {
      setState(() => _dateOfBirth = picked);
    }
  }

  // Snackbar helpers
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: AppConstants.snackBarDuration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: AppConstants.snackBarDuration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool get _isFormValid {
    return _profileImage != null &&
        _dateOfBirth != null &&
        _hobbies.isNotEmpty &&
        _agreedToTerms &&
        _firstName.isNotEmpty &&
        _lastName.isNotEmpty &&
        _countryOfOrigin.isNotEmpty &&
        _countryOfResidence.isNotEmpty &&
        _city.isNotEmpty &&
        _email.isNotEmpty &&
        _password.length >= AppConstants.minPasswordLength;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.signupTitle),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: _showForgotPasswordDialog,
            child: const Text(AppConstants.forgotPassword),
          ),
        ],
      ),
      body: _isLoading
          ? _buildShimmerLoader()
          : _emailVerified
              ? _buildVerifiedView()
              : _buildSignupForm(),
    );
  }

  Widget _buildShimmerLoader() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: ListView(
          children: [
            const SizedBox(height: AppConstants.defaultPadding),
            const CircleAvatar(
              radius: AppConstants.avatarRadius,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: AppConstants.largePadding),
            ...List.generate(8, (index) => _buildShimmerField()),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.defaultPadding),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildVerifiedView() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 80, color: Colors.green),
          const SizedBox(height: AppConstants.largePadding),
          const Text(
            'Email Verified!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.defaultPadding),
          const Text(
            'Your email has been successfully verified. You can now access all features.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => context.go('/home'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              minimumSize: const Size(200, 50),
            ),
            child: const Text('Continue to App'),
          ),
        ],
      ),
    );
  }

  Widget _buildSignupForm() {
    return IgnorePointer(
      ignoring: _isSubmitting,
      child: AnimatedOpacity(
        opacity: _isSubmitting ? 0.6 : 1.0,
        duration: AppConstants.buttonAnimationDuration,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          _buildProfilePictureSection(),
                          const SizedBox(height: AppConstants.largePadding),
                          _buildPersonalInfoSection(),
                          const SizedBox(height: 20),
                          _buildAboutMeSection(),
                          const SizedBox(height: 20),
                          _buildHobbiesSection(),
                          const SizedBox(height: 20),
                          _buildLocationSection(),
                          const SizedBox(height: 20),
                          _buildContactSection(),
                          const SizedBox(height: 20),
                          _buildTermsAgreement(),
                          const SizedBox(height: AppConstants.largePadding),
                        ],
                      ),
                    ),
                  ),
                  _buildSubmitButton(),
                  const SizedBox(height: AppConstants.defaultPadding),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePictureSection() {
    return Semantics(
      label: 'Profile picture upload section',
      button: true,
      child: Column(
        children: [
          GestureDetector(
            onTap: _isSubmitting ? null : _pickImage,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _profileImage == null ? Colors.red : Colors.green,
                  width: 2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 56,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _profileImage != null 
                        ? FileImage(_profileImage!) 
                        : null,
                    child: _profileImage == null
                        ? const Icon(
                            Icons.person_add,
                            size: 40,
                            color: Colors.grey,
                          )
                        : null,
                  ),
                  if (_profileImage != null)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (_isSubmitting)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black54,
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppConstants.smallPadding),
          Text(
            _profileImage == null ? 'Upload Profile Photo*' : 'Photo uploaded ✓',
            style: TextStyle(
              color: _profileImage == null ? Colors.red : Colors.green,
              fontWeight: FontWeight.w500,
            ),
            textScaler: MediaQuery.of(context).textScaler.clamp(),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Personal Information',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        Row(
          children: [
            Expanded(
              child: CustomTextField(
                label: 'First Name*',
                icon: Icons.person,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                focusNode: _firstNameFocus,
                nextFocusNode: _lastNameFocus,
                validator: (val) => ValidationService.validateName(val, 'First Name'),
                onChanged: (val) => setState(() => _firstName = val),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomTextField(
                label: 'Last Name*',
                icon: Icons.person_outline,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                focusNode: _lastNameFocus,
                nextFocusNode: _countryOriginFocus,
                validator: (val) => ValidationService.validateName(val, 'Last Name'),
                onChanged: (val) => setState(() => _lastName = val),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        DatePickerField(
          selectedDate: _dateOfBirth,
          onTap: _selectDate,
          errorText: ValidationService.validateDateOfBirth(_dateOfBirth),
        ),
      ],
    );
  }

  Widget _buildAboutMeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About Me',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        CustomDropdownField<String>(
          label: 'Gender*',
          value: _gender,
          items: AppConstants.genderOptions,
          icon: Icons.transgender,
          validator: (val) => ValidationService.validateRequiredField(val, 'Gender'),
          onChanged: (val) => setState(() => _gender = val!),
          displayText: (val) => val,
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        CustomDropdownField<String>(
          label: 'Relationship Status*',
          value: _relationshipStatus,
          items: AppConstants.relationshipOptions,
          icon: Icons.family_restroom,
          validator: (val) => ValidationService.validateRequiredField(val, 'Relationship Status'),
          onChanged: (val) => setState(() => _relationshipStatus = val!),
          displayText: (val) => val,
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        CustomDropdownField<String>(
          label: 'Interested In*',
          value: _interestedIn,
          items: AppConstants.interestedInOptions,
          icon: Icons.favorite,
          validator: (val) => ValidationService.validateRequiredField(val, 'Interested In'),
          onChanged: (val) => setState(() => _interestedIn = val!),
          displayText: (val) => val,
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        CustomDropdownField<String>(
          label: 'Occupation*',
          value: _occupation,
          items: AppConstants.occupationOptions,
          icon: Icons.work,
          validator: (val) => ValidationService.validateRequiredField(val, 'Occupation'),
          onChanged: (val) => setState(() => _occupation = val!),
          displayText: (val) => val,
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        CustomDropdownField<String>(
          label: 'Education Level*',
          value: _educationLevel,
          items: AppConstants.educationOptions,
          icon: Icons.school,
          validator: (val) => ValidationService.validateRequiredField(val, 'Education Level'),
          onChanged: (val) => setState(() => _educationLevel = val!),
          displayText: (val) => val,
        ),
      ],
    );
  }

  Widget _buildHobbiesSection() {
    return HobbiesSelectionGrid(
      selectedHobbies: _hobbies,
      onHobbySelected: (hobby, selected) => setState(() {
        selected ? _hobbies.add(hobby) : _hobbies.remove(hobby);
      }),
      errorText: ValidationService.validateHobbies(_hobbies),
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        CustomTextField(
          label: 'Country of Origin*',
          icon: Icons.flag,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          focusNode: _countryOriginFocus,
          nextFocusNode: _countryResidenceFocus,
          validator: (val) => ValidationService.validateCountry(val),
          onChanged: (val) => setState(() => _countryOfOrigin = val),
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        CustomTextField(
          label: 'Country of Residence*',
          icon: Icons.location_on,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          focusNode: _countryResidenceFocus,
          nextFocusNode: _cityFocus,
          validator: (val) => ValidationService.validateCountry(val),
          onChanged: (val) => setState(() => _countryOfResidence = val),
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        CustomTextField(
          label: 'City/Town*',
          icon: Icons.location_city,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          focusNode: _cityFocus,
          nextFocusNode: _emailFocus,
          validator: (val) => ValidationService.validateCity(val),
          onChanged: (val) => setState(() => _city = val),
        ),
      ],
    );
  }

  Widget _buildContactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Contact Information',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        CustomTextField(
          label: 'Email*',
          icon: Icons.email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          focusNode: _emailFocus,
          nextFocusNode: _phoneFocus,
          validator: ValidationService.validateEmail,
          onChanged: (val) => setState(() => _email = val),
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        CustomTextField(
          label: 'Phone Number',
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          focusNode: _phoneFocus,
          nextFocusNode: _passwordFocus,
          validator: ValidationService.validatePhoneNumber,
          onChanged: (val) => setState(() => _phoneNumber = val),
        ),
        const SizedBox(height: AppConstants.defaultPadding),
        TextFormField(
          focusNode: _passwordFocus,
          decoration: InputDecoration(
            labelText: 'Password*',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            helperText: 'Minimum ${AppConstants.minPasswordLength} characters with uppercase, lowercase, number & special character',
          ),
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          validator: ValidationService.validatePassword,
          onChanged: (val) => setState(() => _password = val),
          onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
        ),
      ],
    );
  }

  Widget _buildTermsAgreement() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _agreedToTerms,
              onChanged: _isSubmitting 
                  ? null 
                  : (value) => setState(() => _agreedToTerms = value ?? false),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    children: [
                      const Text('I agree to the '),
                      GestureDetector(
                        onTap: () => context.push('/terms'),
                        child: const Text(
                          'Terms of Service',
                          style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const Text(' and '),
                      GestureDetector(
                        onTap: () => context.push('/privacy'),
                        child: const Text(
                          'Privacy Policy',
                          style: TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!_agreedToTerms)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'You must agree to the terms',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: _isFormValid && !_isSubmitting 
              ? Theme.of(context).primaryColor 
              : Colors.grey,
          foregroundColor: Colors.white,
        ),
        onPressed: _isFormValid && !_isSubmitting ? _signUp : null,
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                AppConstants.createAccount,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}