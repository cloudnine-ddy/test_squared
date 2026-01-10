import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/landing/landing_page.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/auth/forgot_password_page.dart';
import '../../features/auth/reset_password_page.dart';
import '../../features/dashboard/dashboard_screen.dart';
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
import '../../features/vending/vending_page.dart';
import '../../main.dart' show isPasswordRecoverySession;

final goRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    // If this is a password recovery session, redirect to reset-password page
    if (isPasswordRecoverySession && state.matchedLocation != '/reset-password') {
      return '/reset-password';
    }
    return null;
  },
  routes: [
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
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/dashboard-preview',
      builder: (context, state) => const DashboardScreen(previewMode: true),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminShell(),
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
    GoRoute(
      path: '/premium',
      builder: (context, state) => const PremiumPage(),
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
    GoRoute(
      path: '/vending',
      builder: (context, state) => const VendingPage(),
    ),
  ],
);
