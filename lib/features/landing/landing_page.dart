import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../auth/providers/auth_provider.dart';
import '../../main.dart' show isPasswordRecoverySession;

/// Landing page for non-authenticated users
/// Modern design inspired by SaveMyExams with clean aesthetics
class LandingPage extends ConsumerWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check URL for recovery params directly (robust fallback)
    final isRecoveryUrl = Uri.base.toString().contains('type=recovery');
    
    // If this is a password recovery session, redirect to reset-password page instead of dashboard
    if (isPasswordRecoverySession || isRecoveryUrl) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Ensure we don't loop if we are already there (though LandingPage shouldn't be ResetPage)
        context.go('/reset-password');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Redirect to dashboard if already authenticated (and NOT in recovery session)
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    if (isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Small delay to allow any pending auth events (like passwordRecovery) to fire first
        await Future.delayed(const Duration(milliseconds: 500));
        if (context.mounted) {
             // Re-check recovery status just in case
             if (Uri.base.toString().contains('type=recovery')) {
                context.go('/reset-password');
             } else {
                context.go('/dashboard');
             }
        }
      });
    }


    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Navigation Bar
                _buildNavigationBar(context),
                
                const SizedBox(height: 40),
                
                // Main Content
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // Trust Indicator
                        _buildTrustBadge(),
                        const SizedBox(height: 32),
                        
                        // Hero Section
                        _buildHeroSection(context),
                        const SizedBox(height: 48),
                        
                        // CTA Buttons
                        _buildCTAButtons(context),
                        const SizedBox(height: 80),
                        
                        // "Why it works" Section
                        _buildWhyItWorksSection(),
                        const SizedBox(height: 60),
                        
                        // Feature Cards
                        _buildFeatureCards(),
                        const SizedBox(height: 80),
                        
                        // Final CTA
                        _buildFinalCTA(context),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo/Brand
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.school_outlined,
                  color: AppColors.textOnDark,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Test²',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          
          // Navigation Items
          Row(
            children: [
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text(
                  'Log in',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => context.go('/signup'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.info,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'Join now for free',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrustBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star,
            color: Colors.amber,
            size: 20,
          ),
          SizedBox(width: 8),
          Text(
            'Trusted by students worldwide',
            style: TextStyle(
              color: AppColors.textOnDark,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Column(
      children: [
        // Main Heading
        Text(
          'Exam-specific practice,',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            height: 1.2,
          ),
        ),
        Text(
          'powered by AI',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 24),
        
        // Subheading
        Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Text(
            'Practice with real past paper questions. Get instant AI feedback and detailed explanations. Master your exams with confidence.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCTAButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Primary CTA
        ElevatedButton(
          onPressed: () => context.go('/login'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.info,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 18,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            shadowColor: AppColors.info.withValues(alpha: 0.4),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Join now for free',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        
        // Secondary CTA
        OutlinedButton(
          onPressed: () => context.go('/dashboard'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: BorderSide(
              color: AppColors.textPrimary,
              width: 2,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 18,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Explore as guest',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWhyItWorksSection() {
    return Column(
      children: [
        Text(
          'Why it works',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Real results. Real progress. On average, students improve significantly.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCards() {
    final features = [
      {
        'icon': Icons.history_edu,
        'title': 'Past Papers Library',
        'description': 'Access thousands of questions from previous exam papers, organized by topic and difficulty',
      },
      {
        'icon': Icons.psychology_outlined,
        'title': 'AI-Powered Checking',
        'description': 'Get instant, intelligent feedback on your answers with detailed AI analysis and explanations',
      },
      {
        'icon': Icons.insights_outlined,
        'title': 'Track Your Progress',
        'description': 'Monitor your improvement with detailed analytics and personalized recommendations',
      },
      {
        'icon': Icons.bookmark_outline,
        'title': 'Save & Review',
        'description': 'Bookmark important questions and add personal notes for effective revision',
      },
    ];

    return Wrap(
      spacing: 24,
      runSpacing: 24,
      alignment: WrapAlignment.center,
      children: features.map((feature) {
        return Container(
          width: 280,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  feature['icon'] as IconData,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                feature['title'] as String,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                feature['description'] as String,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFinalCTA(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Ready to achieve your best results?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.textOnDark,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Join thousands of students already using Test² to excel in their exams',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textOnDark.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.go('/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(
                horizontal: 40,
                vertical: 20,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 8,
            ),
            child: const Text(
              'Get Started Free',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
