import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/wired/wired_widgets.dart';

/// Beautiful empty state for dashboard when no subject is selected
class DashboardEmptyState extends StatelessWidget {
  final VoidCallback? onExploreSubjects;

  const DashboardEmptyState({
    super.key,
    this.onExploreSubjects,
  });

  // Sketchy Theme Colors (matching sidebar)
  static const Color _primaryColor = Color(0xFF2D3E50); // Deep Navy
  static const Color _backgroundColor = Color(0xFFFDFBF7); // Cream beige

  // Patrick Hand text style helper
  TextStyle _patrickHand({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? height,
    FontStyle? fontStyle,
  }) {
    return TextStyle(
      fontFamily: 'PatrickHand',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? _primaryColor,
      height: height,
      fontStyle: fontStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _backgroundColor,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // TestSquared Logo
              Image.asset(
                'lib/core/assets/images/logo_box_test_squared.png',
                width: 120,
                height: 120,
              ),

              const SizedBox(height: 40),

              // Welcome message
              Text(
                'Welcome to TestSquared!',
                style: _patrickHand(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Subtitle
              Text(
                'Select a subject from the sidebar to start practicing,\nor explore our subjects to begin your learning journey.',
                style: _patrickHand(
                  fontSize: 18,
                  color: _primaryColor.withValues(alpha: 0.7),
                  height: 1.6,
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
                    color: _primaryColor,
                    onTap: onExploreSubjects,
                  ),
                  _buildQuickActionCard(
                    context,
                    icon: Icons.bar_chart_outlined,
                    title: 'View Progress',
                    description: 'Track your learning journey',
                    color: const Color(0xFF4A7C59), // Forest green
                    onTap: () => context.push('/progress'),
                  ),
                  _buildQuickActionCard(
                    context,
                    icon: Icons.bookmark_outline,
                    title: 'Saved Questions',
                    description: 'Review bookmarked questions',
                    color: const Color(0xFFD4A574), // Warm tan
                    onTap: () => context.push('/bookmarks'),
                  ),
                ],
              ),
            ],
          ),
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
    return GestureDetector(
      onTap: onTap,
      child: WiredCard(
        backgroundColor: Colors.white,
        borderColor: _primaryColor.withValues(alpha: 0.3),
        borderWidth: 1.5,
        width: 200,
        minHeight: 200,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
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
              style: _patrickHand(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: _patrickHand(
                fontSize: 14,
                color: _primaryColor.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
