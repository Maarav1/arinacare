class AppConstants {
  // App Info
  static const String appName = 'News Feed App';
  static const String appVersion = '1.0.0';
  
  // Firestore Collections
  static const String postsCollection = 'posts';
  static const String usersCollection = 'users';
  static const String scheduledDeletesCollection = 'scheduledDeletes';
  
  // Limits
  static const int postsPerPage = 15;
  static const int maxPostLength = 2000;
  static const int maxCommentLength = 500;
  
  // Durations
  static const Duration refreshDuration = Duration(seconds: 30);
  static const Duration adInterval = Duration(minutes: 5);
  static const Duration postAutoDeleteDuration = Duration(days: 30); // Add this line
  
  // Ad Units (Replace with your actual ad unit IDs)
  static const String bannerAdUnitId = 'ca-app-pub-1472609237394607/8084106825'; // real  ID
  static const String interstitialAdUnitId = 'ca-app-pub-1472609237394607/5863485201'; // real  ID
  
  // Error Messages
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorNetwork = 'Please check your internet connection.';
  static const String errorPostCreate = 'Failed to create post.';
  static const String errorImageUpload = 'Failed to upload image.';
  static const String errorLike = 'Failed to like post.';
  static const String errorComment = 'Failed to add comment.';
  static const String errorDelete = 'Failed to delete post.';
  static const String errorShare = 'Failed to share post.';
  
  // Success Messages
  static const String successPostCreate = 'Post created successfully!';
  static const String successPostDelete = 'Post deleted successfully!';
  static const String successComment = 'Comment added!';
  static const String successShare = 'Link copied to clipboard!';
}