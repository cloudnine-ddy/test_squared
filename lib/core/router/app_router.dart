import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/landing/landing_page.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/auth/forgot_password_page.dart';
import '../../features/auth/reset_password_page.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/dashboard/dashboard_shell.dart';
import '../../features/past_papers/topic_detail_screen.dart';
import '../../features/past_papers/question_detail_screen.dart';
import '../../features/past_papers/question_detail_screen_with_chat.dart';
import '../../features/past_papers/paper_selection_screen.dart';
import '../../features/past_papers/paper_detail_screen.dart';
import '../../features/past_papers/paper_debug_screen.dart';
import '../../pages/admin/admin_shell.dart';
import '../../features/progress/screens/progress_dashboard_screen.dart';
import '../../features/bookmarks/screens/bookmarks_screen.dart';
import '../../features/search/screens/search_screen.dart';
import '../../features/settings/screens/accessibility_settings_screen.dart';
import '../../features/premium/premium_page.dart';
import '../../features/premium/checkout_page.dart';
import '../../features/vending/vending_page.dart';
import '../../main.dart' show isPasswordRecoverySession;
import 'dart:async';

/// A class that converts a Stream into a Listenable for GoRouter
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final goRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange),
  redirect: (context, state) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final isLoggedIn = user != null;
    final path = state.matchedLocation;

    // 1. Password Recovery logic
    if (isPasswordRecoverySession && path != '/reset-password') {
      return '/reset-password';
    }

    // 2. Auth Redirects
    // If logged in, don't allow access to landing/login/signup (redirect to dashboard)
    if (isLoggedIn && (path == '/' || path == '/login' || path == '/signup')) {
      return '/dashboard';
    }

    // If NOT logged in, don't allow access to protected routes
    final protectedRoutes = [
      '/dashboard', 
      '/premium', 
      '/checkout', 
      '/progress', 
      '/bookmarks', 
      '/search',
      '/topic',
      '/question',
      '/paper'
    ];
    
    if (!isLoggedIn) {
      final isProtected = protectedRoutes.any((route) => path == route || path.startsWith('$route/'));
      if (isProtected) return '/login';
    }

    return null;
  },
  routes: [
    // Public Routes
    GoRoute(
      path: '/',
      builder: (context, state) => const LandingPage(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordPage(),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) => const ResetPasswordPage(),
    ),
    GoRoute(
      path: '/vending',
      builder: (context, state) => const VendingPage(),
    ),

    // Dashboard Shell (Protected Routes)
    ShellRoute(
      builder: (context, state, child) => DashboardShell(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) {
            final subjectId = state.uri.queryParameters['subjectId'];
            final subjectName = state.uri.queryParameters['subjectName'];
            return DashboardScreen(
              initialSubjectId: subjectId,
              initialSubjectName: subjectName,
            );
          },
        ),
        GoRoute(
          path: '/premium',
          builder: (context, state) => const PremiumPage(),
        ),
        GoRoute(
          path: '/checkout/:planType',
          builder: (context, state) {
            final planType = state.pathParameters['planType'] ?? 'pro';
            return CheckoutPage(planType: planType);
          },
        ),
        GoRoute(
          path: '/progress',
          builder: (context, state) => const ProgressDashboardScreen(),
        ),
        GoRoute(
          path: '/bookmarks',
          builder: (context, state) => const BookmarksScreen(),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchScreen(),
        ),
      ],
    ),

    // Non-Shell Protected Routes (e.g. Admin, Details)
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminShell(),
    ),
    GoRoute(
      path: '/dashboard-preview',
      builder: (context, state) => const DashboardScreen(previewMode: true),
    ),
    GoRoute(
      path: '/topic/:topicId',
      builder: (context, state) {
        final topicId = state.pathParameters['topicId']!;
        return TopicDetailScreen(topicId: topicId);
      },
    ),
    GoRoute(
      path: '/question/:questionId',
      pageBuilder: (context, state) {
        final questionId = state.pathParameters['questionId']!;
        final topicId = state.uri.queryParameters['topicId'];
        return CustomTransitionPage(
          key: state.pageKey,
          child: QuestionDetailScreenWithChat(
            questionId: questionId,
            topicId: topicId,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 200),
        );
      },
    ),
    GoRoute(
      path: '/papers/year/:year/subject/:subjectId',
      builder: (context, state) {
        final year = int.parse(state.pathParameters['year']!);
        final subjectId = state.pathParameters['subjectId']!;
        return PaperSelectionScreen(year: year, subjectId: subjectId);
      },
    ),
    GoRoute(
      path: '/paper/:paperId',
      builder: (context, state) {
        final paperId = state.pathParameters['paperId']!;
        return PaperDetailScreen(paperId: paperId);
      },
    ),
    GoRoute(
      path: '/paper/:paperId/debug',
      builder: (context, state) {
        final paperId = state.pathParameters['paperId']!;
        return PaperDebugScreen(paperId: paperId);
      },
    ),
    GoRoute(
      path: '/settings/accessibility',
      builder: (context, state) => const AccessibilitySettingsScreen(),
    ),
  ],
);
