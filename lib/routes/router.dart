import 'package:arina_cave/screens/ai_screen.dart';
import 'package:arina_cave/screens/chat_screen.dart';
import 'package:arina_cave/screens/news_api_screen.dart';
import 'package:arina_cave/screens/news_screen.dart';
import 'package:arina_cave/screens/privacy_policy.dart';
import 'package:arina_cave/screens/radio_screen.dart';
import 'package:arina_cave/screens/sql_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:arina_cave/screens/add_friends_screen.dart';
import 'package:arina_cave/screens/edit_profile_screen.dart';
import 'package:arina_cave/screens/friends_screen.dart';
import 'package:arina_cave/screens/home_screen.dart';
import 'package:arina_cave/screens/inbox_screen.dart';
import 'package:arina_cave/screens/login_screen.dart';
import 'package:arina_cave/screens/menu_screen.dart';
import 'package:arina_cave/screens/messages_screen.dart';
import 'package:arina_cave/screens/online_screen.dart';
import 'package:arina_cave/screens/post_detail_screen.dart';
import 'package:arina_cave/screens/profile_screen.dart';
import 'package:arina_cave/screens/signup_screen.dart';
import 'package:arina_cave/screens/terms_screen.dart';
import 'package:arina_cave/screens/picture_screen.dart';
import 'package:arina_cave/screens/feed_screen.dart';

// UPDATED: Import Browser Screen from screens folder
import 'package:arina_cave/screens/browser_screen.dart';
// REMOVE: Old imports
// import 'package:arina_cave/features/browser/presentation/screens/browser_screen.dart';
// import 'package:arina_cave/features/browser/presentation/screens/monetization_disclosure_screen.dart';

class AppRouter {
  static final FirebaseAuth auth = FirebaseAuth.instance;
  static final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static CustomTransitionPage buildPageWithDefaultTransition<T>({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionsBuilder:
          (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
    );
  }

  // Centralized route guard function
  static String? _routeGuard(BuildContext context, GoRouterState state) {
    try {
      final user = auth.currentUser;
      if (user == null) return '/login';
      
      // Optional: Add feature-specific guards
      if (state.matchedLocation.startsWith('/ai') && !user.emailVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please verify your email to use AI features')),
        );
        return '/home';
      }
      
      return null;
    } catch (e) {
      // If there's any error in route guard, redirect to login
      return '/login';
    }
  }

  // Analytics helper
  static void _logScreenView(String screenName, {Map<String, dynamic>? parameters}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        analytics.logEvent(
          name: 'screen_view',
          parameters: {
            'screen_name': screenName,
            ...?parameters,
          },
        );
      } catch (e) {
        // Silently fail analytics
        if (kDebugMode) {
          print('Analytics error: $e');
        }
      }
    });
  }

  static final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/home',
    debugLogDiagnostics: true,
    observers: [FirebaseAnalyticsObserver(analytics: analytics)],

    routes: [
      // Auth routes (outside shell)
      GoRoute(
        path: '/',
        name: 'root',
        redirect: (context, state) {
          try {
            final user = auth.currentUser;
            return user == null ? '/login' : '/home';
          } catch (e) {
            return '/login';
          }
        },
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => buildPageWithDefaultTransition(
          context: context,
          state: state,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        pageBuilder: (context, state) => buildPageWithDefaultTransition(
          context: context,
          state: state,
          child: const SignupScreen(),
        ),
      ),
      GoRoute(
        path: '/terms',
        name: 'terms',
        pageBuilder: (context, state) => buildPageWithDefaultTransition(
          context: context,
          state: state,
          child: const TermsScreen(),
        ),
      ),
      GoRoute(
        path: '/privacy',
        name: 'privacy',
        pageBuilder: (context, state) => buildPageWithDefaultTransition(
          context: context,
          state: state,
          child: const PrivacyPolicyScreen(),
        ),
      ),

      // Main app routes
      GoRoute(
        path: '/home',
        name: 'home',
        pageBuilder: (context, state) {
          _logScreenView('home');
          return buildPageWithDefaultTransition(
            context: context,
            state: state,
            child: const HomeScreen(),
          );
        },
        redirect: _routeGuard,
      ),
      
      // Profile routes - consolidated
      GoRoute(
        path: '/userProfile/:userId',
        name: 'profile',
        pageBuilder: (context, state) {
          final userId = state.pathParameters['userId']!;
          _logScreenView('profile', parameters: {'viewed_user_id': userId});
          return buildPageWithDefaultTransition(
            context: context,
            state: state,
            child: ProfileScreen(userId: userId),
          );
        },
        redirect: _routeGuard,
      ),

      // Current user's profile (without ID)
      GoRoute(
        path: '/profile',
        name: 'myProfile',
        pageBuilder: (context, state) {
          _logScreenView('my_profile');
          return buildPageWithDefaultTransition(
            context: context,
            state: state,
            child: const ProfileScreen(),
          );
        },
        redirect: _routeGuard,
        routes: [
          GoRoute(
            path: 'picture',
            name: 'edit-picture',
            pageBuilder: (context, state) => buildPageWithDefaultTransition(
              context: context,
              state: state,
              child: const PictureScreen(),
            ),
          ),
        ],
      ),

      // ========== BROWSER ROUTES ==========
      GoRoute(
        path: '/browser',
        name: 'browser',
        pageBuilder: (context, state) {
          _logScreenView('browser');
          final url = state.uri.queryParameters['url'];
          return buildPageWithDefaultTransition(
            context: context,
            state: state,
            child: BrowserScreen(
              key: ValueKey('browser_${url ?? 'main'}'),
              initialUrl: url,
            ),
          );
        },
        redirect: _routeGuard,
      ),
      
      // REMOVED: Monetization disclosure route since it's now handled in BrowserScreen
      // ======================================

      // Other app routes
      GoRoute(
        path: '/friends',
        name: 'friends',
        pageBuilder: (context, state) {
          _logScreenView('friends');
          return buildPageWithDefaultTransition(
            context: context,
            state: state,
            child: const FriendsScreen(),
          );
        },
        redirect: _routeGuard,
      ),
      GoRoute(
        path: '/add',
        name: 'add',
        pageBuilder: (context, state) {
          _logScreenView('add_friends');
          return buildPageWithDefaultTransition(
            context: context,
            state: state,
            child: const AddFriendsScreen(),
          );
        },
        redirect: _routeGuard,
      ),
      GoRoute(
        path: '/messages',
        name: 'messages',
        pageBuilder: (context, state) {
          _logScreenView('messages');
          return buildPageWithDefaultTransition(
            context: context,
            state: state,
            child: const MessagesScreen(),
          );
        },
        redirect: _routeGuard,
      ),
      GoRoute(
        path: '/inbox',
        name: 'inbox',
        pageBuilder: (context, state) {
          _logScreenView('inbox');
          return buildPageWithDefaultTransition(
            context: context,
            state: state,
            child: const InboxScreen(),
          );
        },
        redirect: _routeGuard,
      ),
      GoRoute(
        path: '/news',
        name: 'news',
        pageBuilder: (context, state) {
          _logScreenView('news');
          return buildPageWithDefaultTransition(
            context: context,
            state: state,
            child: const ArinaNewsScreen(),
          );
        },
        redirect: _routeGuard,
      ),
      GoRoute(
        path: '/news-api',
        name: 'news-api',
        pageBuilder: (context, state) {
          _logScreenView('news-api');
          return buildPageWithDefaultTransition(
            context: context,
            state: state,
            child: const NewsApiScreen(),
          );
        },
        redirect: _routeGuard,
      ),
      GoRoute(
        path: '/radio',
        name: 'radio',
        pageBuilder: (context, state) {
          _logScreenView('radio');
          return buildPageWithDefaultTransition(
            context: context,
            state: state,
            child: const RadioScreen(),
          );
        },
        redirect: _routeGuard,
      ),
      GoRoute(
        path: '/sql',
        name: 'sql',
        pageBuilder: (context, state) {
          _logScreenView('sql');
          return buildPageWithDefaultTransition(
            context: context,
            state: state,
            child: const AScreen(),
          );
        },
        redirect: _routeGuard,
      ),
      GoRoute(
        path: '/feed',
        name: 'feed',
        pageBuilder: (context, state) {
          _logScreenView('feed');
          return buildPageWithDefaultTransition(
            context: context,
            state: state,
            child: const NewsFeedScreen(),
          );
        },
        redirect: _routeGuard,
      ),
      GoRoute(
        path: '/chat/:chatRoomId',
        name: 'chat',
        pageBuilder: (context, state) {
          final chatRoomId = state.pathParameters['chatRoomId']!;
          _logScreenView('chat', parameters: {'chat_room_id': chatRoomId});
          return buildPageWithDefaultTransition(
            context: context,
            state: state,
            child: ChatScreen(chatRoomId: chatRoomId),
          );
        },
        redirect: _routeGuard,
      ),
      GoRoute(
        path: '/menu',
        name: 'menu',
        pageBuilder: (context, state) {
          _logScreenView('menu');
          return buildPageWithDefaultTransition(
            context: context,
            state: state,
            child: const MenuScreen(),
          );
        },
        redirect: _routeGuard,
      ),
      GoRoute(
        path: '/ai',
        name: 'ai',
        pageBuilder: (context, state) {
          _logScreenView('ai');
          return buildPageWithDefaultTransition(
            context: context,
            state: state,
            child: const AIScreen(),
          );
        },
        redirect: _routeGuard,
      ),
      GoRoute(
        path: '/post/:postId',
        name: 'post',
        pageBuilder: (context, state) {
          final postId = state.pathParameters['postId']!;
          _logScreenView('post_detail', parameters: {'post_id': postId});
          return buildPageWithDefaultTransition(
            context: context,
            state: state,
            child: PostDetailScreen(postId: postId),
          );
        },
        redirect: _routeGuard,
      ),
      GoRoute(
        path: '/online',
        name: 'online',
        pageBuilder: (context, state) {
          _logScreenView('online_users');
          return buildPageWithDefaultTransition(
            context: context,
            state: state,
            child: const OnlineUsersScreen(),
          );
        },
        redirect: _routeGuard,
      ),
      GoRoute(
        path: '/edit-profile',
        name: 'edit-profile',
        pageBuilder: (context, state) {
          _logScreenView('edit_profile');
          return buildPageWithDefaultTransition(
            context: context,
            state: state,
            child: const EditProfileScreen(),
          );
        },
        redirect: _routeGuard,
      ),
    ],

    redirect: (BuildContext context, GoRouterState state) {
      try {
        final isLoggedIn = auth.currentUser != null;
        final isAuthRoute = state.matchedLocation.startsWith('/login') ||
            state.matchedLocation.startsWith('/signup');

        // Always allow access to /terms and /privacy regardless of login status
        final isPublicRoute = state.matchedLocation.startsWith('/terms') ||
            state.matchedLocation.startsWith('/privacy');

        if (!isLoggedIn && !isAuthRoute && !isPublicRoute) {
          return '/login';
        }

        // Only redirect auth routes (login/signup) to home when logged in
        if (isLoggedIn && isAuthRoute) {
          return '/home';
        }

        return null;
      } catch (e) {
        return '/login';
      }
    },

    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(
        title: const Text('Page Not Found'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 20),
              Text(
                'Page Not Found',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                'The page "${state.uri.path}" doesn\'t exist or you don\'t have access to it.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 30),
              FilledButton(
                onPressed: () => context.go('/home'),
                child: const Text('Go to Home'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => context.go('/menu'),
                child: const Text('Go to Menu'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}