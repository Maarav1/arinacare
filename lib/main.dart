import 'dart:async';

import 'package:arina_cave/router/app_router.dart';
import 'package:arina_cave/screens/gemini_service.dart';
import 'package:arina_cave/services/ad_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:go_router/go_router.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';

// REMOVED: Old browser imports
// ================== GLOBAL STREAMS ==================
final StreamController<Map<String, String>> deepLinkController = 
    StreamController<Map<String, String>>.broadcast();

Uri? _initialDeepLink;
// ====================================================

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Enable edge-to-edge
    _enableEdgeToEdge();
    
    // Initialize core services (PARALLEL FOR SPEED)
    // 1. Load critical config first
    await dotenv.load(fileName: ".env"); 
    
    // 2. Now initialize services that DEPEND on dotenv
    await Future.wait([
      Firebase.initializeApp(),
      MobileAds.instance.initialize(),
      _initializeHive(),  // Simple Hive initialization (no browser adapters here)
      GeminiService.instance.initialize(),
    ]);

    // Initialize AdService and preload first interstitial
      AdService.instance.loadInterstitialAd();
      AdService.instance.startIntervalTimer(); // Start 5-minute timer

      // Show ad immediately after first frame 
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AdService.instance.showInterstitialAd();
      });
    
    // Setup error reporting
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    
    // Handle initial deep link
    await _handleInitialDeepLink();
    
    // RUN APP IMMEDIATELY - No database slowing things down
    runApp(const MyApp());
    
    // Initialize deep links after app starts
    _initDeepLinks();
    
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

Future<void> _initializeHive() async {
  try {
    // Initialize Hive with Flutter
    await Hive.initFlutter();
    
    if (kDebugMode) {
      print('✅ Hive initialized');
    }
    
  } catch (e) {
    if (kDebugMode) {
      print('⚠️ Hive initialization error: $e');
      print('⚠️ Continuing without Hive for now...');
    }
  }
}

void _enableEdgeToEdge() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
}

Future<void> _handleInitialDeepLink() async {
  final appLinks = AppLinks();
  try {
    Uri? initialUri;
    try {
      initialUri = await appLinks.uriLinkStream.first
          .timeout(const Duration(milliseconds: 500));
    } on TimeoutException {
      initialUri = null;
    } catch (e) {
      if (kDebugMode) print('Initial deep link error: $e');
      initialUri = null;
    }

    if (initialUri != null) {
      if (kDebugMode) print('Initial deep link: $initialUri');
      _initialDeepLink = initialUri;
      
      // Handle browser deep links (http/https URLs)
      if (initialUri.scheme.startsWith('http')) {
        _handleBrowserDeepLink(initialUri);
      }
    }
  } catch (e) {
    if (kDebugMode) print('App link error: $e');
  }
}

void _initDeepLinks() {
  final appLinks = AppLinks();
  appLinks.uriLinkStream.listen(
    (Uri? uri) {
      if (kDebugMode) print('Deep link: $uri');
      _handleDeepLink(uri);
      
      // Handle browser deep links
      if (uri != null && uri.scheme.startsWith('http')) {
        _handleBrowserDeepLink(uri);
      }
    },
    onError: (err) {
      if (kDebugMode) print('Deep link error: $err');
    },
  );
}

// Handle browser-specific deep links
void _handleBrowserDeepLink(Uri uri) {
  // Add to stream for browser navigation
  deepLinkController.add({
    'type': 'browser',
    'url': uri.toString(),
    'id': 'external_link'
  });
}

void _handleDeepLink(Uri? uri) {
  if (uri == null) return;
  
  // Handle browser URLs (http/https)
  if (uri.scheme.startsWith('http')) {
    _handleBrowserDeepLink(uri);
    return;
  }
  
  // Handle custom scheme: arina://cave/post/123
  if (uri.scheme == 'arina' && uri.host == 'cave') {
    _handleCustomScheme(uri);
  }
  // Handle GitHub Pages
  else if (uri.scheme == 'https' && uri.host == 'maarav1.github.io') {
    _handleGitHubPagesLink(uri);
  }
  // Handle hash parameters
  else if (uri.scheme == 'https' && 
           uri.host == 'maarav1.github.io' && 
           uri.fragment.isNotEmpty) {
    _handleHashParameters(uri);
  }
}

void _handleCustomScheme(Uri uri) {
  if (uri.pathSegments.isNotEmpty) {
    final type = uri.pathSegments[0];
    final id = uri.pathSegments.length > 1 ? uri.pathSegments[1] : '';
    
    switch (type) {
      case 'post':
        if (id.isNotEmpty) deepLinkController.add({'type': 'post', 'id': id});
        break;
      case 'profile':
        if (id.isNotEmpty) deepLinkController.add({'type': 'profile', 'id': id});
        break;
      case 'user':
        if (id.isNotEmpty) deepLinkController.add({'type': 'user', 'id': id});
        break;
      case 'browser':
        if (id.isNotEmpty) deepLinkController.add({'type': 'browser', 'url': id, 'id': 'browser'});
        break;
      default:
        deepLinkController.add({'type': 'home', 'id': 'home'});
    }
  } else {
    deepLinkController.add({'type': 'home', 'id': 'home'});
  }
}

void _handleGitHubPagesLink(Uri uri) {
  final pathSegments = uri.pathSegments;
  if (pathSegments.length >= 3) {
    final type = pathSegments[1];
    final id = pathSegments[2];
    
    switch (type) {
      case 'post':
        deepLinkController.add({'type': 'post', 'id': id});
        break;
      case 'profile':
        deepLinkController.add({'type': 'profile', 'id': id});
        break;
      case 'user':
        deepLinkController.add({'type': 'user', 'id': id});
        break;
      case 'browser':
        deepLinkController.add({'type': 'browser', 'url': id, 'id': 'browser'});
        break;
    }
  } else if (pathSegments.length == 1) {
    deepLinkController.add({'type': 'home', 'id': 'home'});
  }
}

void _handleHashParameters(Uri uri) {
  final fragment = uri.fragment;
  
  if (fragment.contains('post=')) {
    final postId = fragment.split('post=')[1].split('&')[0];
    deepLinkController.add({'type': 'post', 'id': postId});
  } else if (fragment.contains('profile=')) {
    final profileId = fragment.split('profile=')[1].split('&')[0];
    deepLinkController.add({'type': 'profile', 'id': profileId});
  } else if (fragment.contains('user=')) {
    final userId = fragment.split('user=')[1].split('&')[0];
    deepLinkController.add({'type': 'user', 'id': userId});
  } else if (fragment.contains('browser=')) {
    final url = fragment.split('browser=')[1].split('&')[0];
    deepLinkController.add({'type': 'browser', 'url': url, 'id': 'browser'});
  } else {
    deepLinkController.add({'type': 'home', 'id': 'home'});
  }
}

// ================== MAIN APP WIDGET ==================

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<Map<String, String>>? _deepLinkSubscription;
  bool _initialLinkHandled = false;
  
  @override
  void initState() {
    super.initState();
    
    // Listen for deep links
    _deepLinkSubscription = deepLinkController.stream.listen(
      _navigateFromDeepLink,
      onError: (error) {
        if (kDebugMode) print('Deep link stream error: $error');
      },
    );
    
    // Handle initial deep link
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialLinkHandled && _initialDeepLink != null) {
        _handleDeepLink(_initialDeepLink);
        _initialLinkHandled = true;
      }
    });
  }

    @override
  void dispose() {
    _deepLinkSubscription?.cancel();
    AdService.instance.stopIntervalTimer();
    AdService.instance.dispose();
    super.dispose();
  }

  void _navigateFromDeepLink(Map<String, String> deepLinkData) {
    final context = AppRouter.navigatorKey.currentContext;
    if (context != null && context.mounted) {
      final type = deepLinkData['type'];
      final id = deepLinkData['id'];
      final url = deepLinkData['url'];

      _performNavigation(type!, id!, url, context);
    }
  }

  void _performNavigation(String type, String id, String? url, BuildContext context) {
    if (!context.mounted) return;

    try {
      switch (type) {
        case 'post':
          GoRouter.of(context).push('/post/$id');
          break;
        case 'profile':
          GoRouter.of(context).push('/profile/$id');
          break;
        case 'user':
          GoRouter.of(context).push('/user/$id');
          break;
        case 'browser':
          // Navigate to browser with URL
          if (url != null && url.isNotEmpty) {
            GoRouter.of(context).push('/browser?url=${Uri.encodeComponent(url)}');
          } else {
            GoRouter.of(context).push('/browser');
          }
          break;
        case 'home':
          GoRouter.of(context).go('/');
          break;
      }
    } catch (e) {
      if (kDebugMode) print('Navigation error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ArinaCave',
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.router,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
    );
  }
}
