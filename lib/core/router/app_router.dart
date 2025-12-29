import 'package:go_router/go_router.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/past_papers/topic_detail_screen.dart';
import '../../features/past_papers/question_detail_screen.dart';
import '../../pages/admin/admin_shell.dart';

final goRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
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
      builder: (context, state) {
        final questionId = state.pathParameters['questionId']!;
        return QuestionDetailScreen(questionId: questionId);
      },
    ),
  ],
);
