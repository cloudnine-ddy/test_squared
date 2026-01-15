import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/wired/wired_widgets.dart';

class PremiumPage extends StatelessWidget {
  const PremiumPage({super.key});

  TextStyle _patrickHand({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    return GoogleFonts.patrickHand(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
               icon: const Icon(Icons.arrow_back, color: Colors.white),
               onPressed: () => context.pop(),
            ),
            title: Text(
              'TestSquared Premium',
              style: _patrickHand(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),

          // Hero Section
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
              child: Column(
                children: [
                  // Logo in Hero Section
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    height: 100,
                    child: Image.asset(
                      'lib/core/assets/images/logo_box_test_squared.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ),
                  Text(
                    'Unlock Your Full Potential',
                    style: _patrickHand(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Get unlimited access to all features and ace your exams with TestSquared',
                    style: _patrickHand(
                      fontSize: 24,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 100),
                    child: WiredDivider(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      thickness: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Pricing Cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20), // Adjusted padding
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Responsive layout for cards
                  if (constraints.maxWidth > 1000) {
                     return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildFreeCard(context)),
                        const SizedBox(width: 24),
                        Expanded(child: _buildProCard(context)),
                        const SizedBox(width: 24),
                        Expanded(child: _buildEliteCard(context)),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _buildFreeCard(context),
                        const SizedBox(height: 32),
                        _buildProCard(context),
                        const SizedBox(height: 32),
                        _buildEliteCard(context),
                      ],
                    );
                  }
                },
              ),
            ),
          ),

          // Small print below cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                children: [
                  Text(
                    'Unlimited usage subject to fair use.',
                    style: _patrickHand(
                      fontSize: 14,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Features may expand over time.',
                    style: _patrickHand(
                      fontSize: 14,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // Features Section
          SliverToBoxAdapter(
             child: Padding(
               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
               child: WiredCard(
                borderColor: AppColors.primary,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Text(
                      'Why Go Premium?',
                      style: _patrickHand(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 48),
                    Wrap(
                      spacing: 48,
                      runSpacing: 48,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildFeatureItem(
                          icon: Icons.auto_awesome_outlined,
                          title: 'AI-Powered Learning',
                          description: 'Instant detailed explanations for every single question.',
                        ),
                        _buildFeatureItem(
                          icon: Icons.insights_outlined,
                          title: 'Advanced Analytics',
                          description: 'Track your growth with smart data visualization.',
                        ),
                        _buildFeatureItem(
                          icon: Icons.lock_open_outlined,
                          title: 'Unlimited Access',
                          description: 'Practice without limits. Master every subject.',
                        ),
                        _buildFeatureItem(
                          icon: Icons.speed_outlined,
                          title: 'Faster Results',
                          description: 'Focus on what matters and improve scores quickly.',
                        ),
                      ],
                    ),
                  ],
                ),
               ),
             ),
          ),

          // Final CTA
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 80),
              child: WiredCard(
                 borderColor: AppColors.accent,
                 backgroundColor: AppColors.primary, // Dark card
                 padding: const EdgeInsets.all(48),
                 child: Column(
                  children: [
                    Text(
                      'Ready to Ace Your Exams?',
                      style: _patrickHand(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Join thousands of students who improved their grades with TestSquared Premium',
                      style: _patrickHand(
                        fontSize: 20,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    WiredButton(
                      onPressed: () {}, // TODO: Scroll up or action
                      backgroundColor: Colors.white,
                      borderColor: Colors.white,
                      filled: true,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                      child: Text(
                        'Upgrade to Premium',
                        style: _patrickHand(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeCard(BuildContext context) {
    return _buildPricingCardBase(
      title: 'Free',
      subtitle: 'Smart practice for everyday revision',
      price: 'RM 0',
      period: '/ month',
      features: [
        'Limited AI answer checking',
        'Basic marking feedback',
        'Limited question generation',
        'Bookmark questions',
        'View notes & sketches',
        'Access to all IGCSE subjects',
      ],
      footnote: '*Limits apply: AI Answer checks – 5/day, Question Generation - 10/Week',
      buttonText: 'Get Free →',
      buttonColor: AppColors.primary,
      filledButton: false, 
      onPressed: () => context.pop(),
      isPopular: false,
    );
  }

  Widget _buildProCard(BuildContext context) {
    return _buildPricingCardBase(
      title: 'Pro',
      subtitle: 'Everything you need to improve your grades',
      price: 'RM 10',
      period: '/ month',
      features: [
        'Everything in Free, plus:',
        'Unlimited AI answer checking',
        'Full marking-scheme comparison',
        'Method & working feedback',
        'Unlimited question generation',
        'Save questions to personal library',
        'Editable notes & sketch tools',
        'Topic-level progress tracking',
        'Faster AI responses',
      ],
      footnote: 'Best value for most students',
      buttonText: 'Get Pro →',
      buttonColor: AppColors.primary,
      filledButton: true,
      onPressed: () {
        context.push('/checkout/pro');
      },
      isPopular: true,
    );
  }

  Widget _buildEliteCard(BuildContext context) {
    return _buildPricingCardBase(
      title: 'Elite',
      subtitle: 'Exam-level mastery for top scorers',
      price: 'RM 29',
      period: '/ month',
      features: [
        'Everything in Pro, plus:',
        'Advanced hints before full solutions',
        'Custom difficulty control (easy → A*)',
        'Long-term progress analytics',
        'Exportable progress reports (PDF)',
        'Priority AI response speed',
        'Priority support',
      ],
      footnote: 'Built for A/A* students and exam-focused learners',
      buttonText: 'Get Elite →',
      buttonColor: AppColors.accent,
      filledButton: true,
      onPressed: () {
        context.push('/checkout/elite');
      },
      isPopular: false,
    );
  }

  Widget _buildPricingCardBase({
    required String title,
    required String subtitle,
    required String price,
    required String period,
    required List<String> features,
    required String footnote,
    required String buttonText,
    required Color buttonColor,
    required bool filledButton,
    required VoidCallback? onPressed,
    required bool isPopular,
  }) {
    // If popular, use rotating stack effect, else just wired card
    if (isPopular) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Rotation
           Positioned.fill(
              child: Transform.rotate(
                angle: 0.03,
                child: WiredCard(
                   borderColor: AppColors.primary.withValues(alpha: 0.3),
                   backgroundColor: Colors.white,
                   child: Container(),
                ),
              ),
           ),
           _buildCardContent(title, subtitle, price, period, features, footnote, buttonText, buttonColor, filledButton, onPressed, isPopular: true),
        ],
      );
    } else {
       return _buildCardContent(title, subtitle, price, period, features, footnote, buttonText, buttonColor, filledButton, onPressed, isPopular: false);
    }
  }

  Widget _buildCardContent(
    String title,
    String subtitle,
    String price, 
    String period, 
    List<String> features,
    String footnote,
    String buttonText, 
    Color buttonColor, 
    bool filledButton,
    VoidCallback? onPressed,
    {required bool isPopular}
    ) {
    return WiredCard(
      borderColor: isPopular ? AppColors.primary : AppColors.border,
      borderWidth: isPopular ? 2.5 : 1.5,
      backgroundColor: Colors.white,
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPopular)
            Align(
              alignment: Alignment.topRight,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
                child: Text(
                  'POPULAR',
                  style: _patrickHand(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ),

          Text(
            title,
            style: _patrickHand(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: _patrickHand(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price,
                style: _patrickHand(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                period,
                style: _patrickHand(
                  fontSize: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          WiredDivider(color: AppColors.border),
          const SizedBox(height: 24),
          ...features.map((feature) => _buildFeatureRow(feature, isPopular)),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: WiredButton(
              onPressed: onPressed,
              backgroundColor: buttonColor,
              borderColor: buttonColor,
              filled: filledButton,
              child: Text(
                buttonText,
                style: _patrickHand(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: filledButton ? Colors.white : buttonColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            footnote,
            style: _patrickHand(
              fontSize: 13,
              color: AppColors.textSecondary.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(String feature, bool isPopular) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            color: isPopular ? AppColors.primary : AppColors.success,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              feature,
              style: _patrickHand(
                fontSize: 17,
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return SizedBox(
      width: 250,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2), // Wired circle
            ),
            child: Icon(
              icon,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: _patrickHand(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: _patrickHand(
               fontSize: 18,
               color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
