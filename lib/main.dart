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
import 'firebase_options.dart';
import 'hive_models.dart'; // ADD THIS IMPORT


// ================== GLOBAL STREAMS ==================
final StreamController<Map<String, String>> deepLinkController =
    StreamController<Map<String, String>>.broadcast();

Uri? _initialDeepLink;
// ====================================================

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      if (!kIsWeb) {
        _enableEdgeToEdge();
      }

      if (!kIsWeb) {
        try {
          await dotenv.load(fileName: ".env");
        } catch (e) {
          if (kDebugMode) print('⚠️ dotenv load skipped: $e');
        }
      }

      if (!kIsWeb) {
        await MobileAds.instance.initialize();
      }

      // Initialize Hive FIRST with all adapters registered
      await _initializeHiveWithAdapters();

      await Future.wait([
        Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
        GeminiService.instance.initialize(),
      ]);

      if (!kIsWeb) {
        AdService.instance.loadInterstitialAd();
        AdService.instance.startIntervalTimer();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          AdService.instance.showInterstitialAd();
        });
      }

      if (!kIsWeb) {
        FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
      } else {
        FlutterError.onError = (error) {
          if (kDebugMode) {
            print('Flutter Error: $error');
          }
        };
        PlatformDispatcher.instance.onError = (error, stack) {
          if (kDebugMode) {
            print('Error: $error');
          }
          return true;
        };
      }

      await _handleInitialDeepLink();

      runApp(const MyApp());

      _initDeepLinks();
    },
    (error, stack) {
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } else {
        if (kDebugMode) {
          print('Uncaught error: $error');
        }
      }
    },
  );
}

Future<void> _initializeHiveWithAdapters() async {
  try {
    await Hive.initFlutter();

    // Register all adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ChatMessageHiveAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ConversationHiveAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(UserProfileHiveAdapter());
    }

    if (kDebugMode) {
      print('✅ Hive initialized with all adapters registered');
    }
  } catch (e) {
    if (kDebugMode) {
      print('⚠️ Hive initialization error: $e');
    }
  }
}

void _enableEdgeToEdge() {
  if (!kIsWeb) {
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
}

Future<void> _handleInitialDeepLink() async {
  if (kIsWeb) return;
  final appLinks = AppLinks();
  try {
    Uri? initialUri;
    try {
      initialUri = await appLinks.uriLinkStream.first.timeout(
        const Duration(milliseconds: 500),
      );
    } on TimeoutException {
      initialUri = null;
    } catch (e) {
      if (kDebugMode) print('Initial deep link error: $e');
      initialUri = null;
    }

    if (initialUri != null) {
      if (kDebugMode) print('Initial deep link: $initialUri');
      _initialDeepLink = initialUri;

      if (initialUri.scheme.startsWith('http')) {
        _handleBrowserDeepLink(initialUri);
      }
    }
  } catch (e) {
    if (kDebugMode) print('App link error: $e');
  }
}

void _initDeepLinks() {
  if (kIsWeb) return;
  final appLinks = AppLinks();
  appLinks.uriLinkStream.listen(
    (Uri? uri) {
      if (kDebugMode) print('Deep link: $uri');
      _handleDeepLink(uri);

      if (uri != null && uri.scheme.startsWith('http')) {
        _handleBrowserDeepLink(uri);
      }
    },
    onError: (err) {
      if (kDebugMode) print('Deep link error: $err');
    },
  );
}

void _handleBrowserDeepLink(Uri uri) {
  deepLinkController.add({
    'type': 'browser',
    'url': uri.toString(),
    'id': 'external_link',
  });
}

void _handleDeepLink(Uri? uri) {
  if (uri == null) return;

  if (uri.scheme.startsWith('http')) {
    _handleBrowserDeepLink(uri);
    return;
  }

  if (uri.scheme == 'arina' && uri.host == 'cave') {
    _handleCustomScheme(uri);
  } else if (uri.scheme == 'https' && uri.host == 'maarav1.github.io') {
    _handleGitHubPagesLink(uri);
  } else if (uri.scheme == 'https' &&
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
        if (id.isNotEmpty) {
          deepLinkController.add({'type': 'profile', 'id': id});
        }
        break;
      case 'user':
        if (id.isNotEmpty) deepLinkController.add({'type': 'user', 'id': id});
        break;
      case 'browser':
        if (id.isNotEmpty) {
          deepLinkController.add({
            'type': 'browser',
            'url': id,
            'id': 'browser',
          });
        }
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

    _deepLinkSubscription = deepLinkController.stream.listen(
      _navigateFromDeepLink,
      onError: (error) {
        if (kDebugMode) print('Deep link stream error: $error');
      },
    );

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
    if (!kIsWeb) {
      AdService.instance.stopIntervalTimer();
      AdService.instance.dispose();
    }
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

  void _performNavigation(
    String type,
    String id,
    String? url,
    BuildContext context,
  ) {
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
          if (url != null && url.isNotEmpty) {
            GoRouter.of(
              context,
            ).push('/browser?url=${Uri.encodeComponent(url)}');
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
