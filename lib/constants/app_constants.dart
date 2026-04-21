class AppConstants {
  // App info
  static const String appName = 'ConnectMe';
  
  // Firestore Collections - ADD THESE
  static const String postsCollection = 'posts';
  static const String usersCollection = 'users';
  static const String scheduledDeletesCollection = 'scheduledDeletes';
  
  // News Feed Constants - ADD THESE
  static const int postsPerPage = 15;
  static const int maxPostLength = 2000;
  static const int maxCommentLength = 500;
  static const Duration postAutoDeleteDuration = Duration(days: 30);
  static const Duration refreshDuration = Duration(seconds: 30);
  
  // Ad Units - ADD THESE (Replace with your actual ad unit IDs)
  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111'; // Test ID
  static const String interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712'; // Test ID
  static const Duration adInterval = Duration(minutes: 5);
  
  // Validation constants
  static const int minPasswordLength = 8;
  static const int minAgeYears = 18;
  static const double maxImageSize = 800.0;
  static const int imageQuality = 85;
  
  // Duration constants
  static const Duration snackBarDuration = Duration(seconds: 5);
  static const Duration buttonAnimationDuration = Duration(milliseconds: 300);
  static const Duration keyboardDismissDelay = Duration(milliseconds: 200);
  
  // UI constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double avatarRadius = 60.0;
  static const double buttonHeight = 50.0;
  
  // Text constants
  static const String signupTitle = 'Create Account';
  static const String forgotPassword = 'Forgot Password?';
  static const String createAccount = 'CREATE ACCOUNT';
  static const String verifyEmail = 'Verify Your Email';
  
  // Error Messages - ADD THESE
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorNetwork = 'Please check your internet connection.';
  static const String errorPostCreate = 'Failed to create post.';
  static const String errorImageUpload = 'Failed to upload image.';
  static const String errorLike = 'Failed to like post.';
  static const String errorComment = 'Failed to add comment.';
  static const String errorDelete = 'Failed to delete post.';
  static const String errorShare = 'Failed to share post.';
  
  // Success Messages - ADD THESE
  static const String successPostCreate = 'Post created successfully!';
  static const String successPostDelete = 'Post deleted successfully!';
  static const String successComment = 'Comment added!';
  static const String successShare = 'Link copied to clipboard!';
  
  // Options lists
  static const List<String> genderOptions = ['Male', 'Female', 'Other'];
  static const List<String> interestedInOptions = [
    'Marriage', 'Dating', 'Relationship', 'Friendship',
  ];
  static const List<String> relationshipOptions = [
    'Single', 'Married', 'Divorced', 'Widowed', 'Single Parent', 'Other',
  ];
  static const List<String> occupationOptions = [
    'Employed', 'Business', 'Student', 'Unemployed', 'Retired',
  ];
  static const List<String> educationOptions = [
    'Primary', 'Secondary', 'Diploma', 'Degree', 'Masters', 'PhD',
  ];
  static const List<String> hobbyOptions = [
    'Reading', 'Sports', 'Music', 'Travel', 'Cooking', 
    'Gardening', 'Photography', 'Art', 'Dancing', 'Gaming',
  ];
}