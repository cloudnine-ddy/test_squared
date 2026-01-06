import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

/// Beautiful empty state for dashboard when no subject is selected
class DashboardEmptyState extends StatelessWidget {
  final VoidCallback? onExploreSubjects;

  const DashboardEmptyState({
    super.key,
    this.onExploreSubjects,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Illustration/Icon
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Animated rings
                  ...List.generate(3, (index) {
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 1500 + (index * 300)),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return Container(
                          width: 120 + (index * 30) * value,
                          height: 120 + (index * 30) * value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).primaryColor.withValues(alpha: 0.2 - (index * 0.05)),
                              width: 2,
                            ),
                          ),
                        );
                      },
                    );
                  }),
                  // Center icon
                  Icon(
                    Icons.school_outlined,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Welcome message
            Text(
              'Welcome to Test²!',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Subtitle
            Text(
              'Select a subject from the sidebar to start practicing,\nor explore our subjects to begin your learning journey.',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                height:1.6,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // Quick action cards
            Wrap(
              spacing: 24,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: [
                _buildQuickActionCard(
                  context,
                  icon: Icons.library_books_outlined,
                  title: 'Browse Subjects',
                  description: 'Explore all available subjects',
                  color: Theme.of(context).primaryColor,
                  onTap: onExploreSubjects,
                ),
                _buildQuickActionCard(
                  context,
                  icon: Icons.bar_chart_outlined,
                  title: 'View Progress',
                  description: 'Track your learning journey',
                  color: Colors.green,
                  onTap: () => context.push('/progress'),
                ),
                _buildQuickActionCard(
                  context,
                  icon: Icons.bookmark_outline,
                  title: 'Saved Questions',
                  description: 'Review bookmarked questions',
                  color: Colors.orange,
                  onTap: () => context.push('/bookmarks'),
                ),
              ],
            ),

            const SizedBox(height: 60),

            // Motivational quote
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Theme.of(context).colorScheme.secondary,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Text(
                      '"Success is the sum of small efforts repeated day in and day out."',
                      style: TextStyle(
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
