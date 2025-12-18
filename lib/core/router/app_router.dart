import 'package:go_router/go_router.dart';
import '../../features/auth/login_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/past_papers/topic_detail_screen.dart';

final goRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/topic/:topicId',
      builder: (context, state) {
        final topicId = state.pathParameters['topicId']!;
        return TopicDetailScreen(topicId: topicId);
      },
    ),
  ],
);

