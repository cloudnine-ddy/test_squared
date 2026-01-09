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
              'Test² Premium',
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
              padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24), // More vertical padding
              child: Column(
                children: [
                  Text(
                    'Unlock Your Full Potential',
                    style: _patrickHand(
                      fontSize: 48, // Larger title
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Get unlimited access to all features and ace your exams',
                    style: _patrickHand(
                      fontSize: 24,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
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
                  if (constraints.maxWidth > 800) {
                     return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildFreeCard(context)),
                        const SizedBox(width: 24),
                        Expanded(child: _buildPremiumCard(context)),
                        const SizedBox(width: 24),
                        Expanded(child: _buildLifetimeCard(context)),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _buildFreeCard(context),
                        const SizedBox(height: 32),
                        _buildPremiumCard(context),
                        const SizedBox(height: 32),
                        _buildLifetimeCard(context),
                      ],
                    );
                  }
                },
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
                      'Join thousands of students who improved their grades with Test² Premium',
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
      price: 'RM 0',
      period: 'forever',
      features: [
        '5 questions per day',
        'Basic progress tracking',
        'Community support',
        'Limited subjects',
      ],
      buttonText: 'Current Plan',
      buttonColor: AppColors.textSecondary,
      filledButton: false, 
      onPressed: null,
      isPopular: false,
    );
  }

  Widget _buildPremiumCard(BuildContext context) {
    return _buildPricingCardBase(
      title: 'Premium',
      price: 'RM 29',
      period: '/month',
      features: [
        '✨ Unlimited questions',
        '✨ AI-powered explanations',
        '✨ Advanced analytics',
        '✨ All subjects',
        '✨ Priority support',
        '✨ Download questions',
      ],
      buttonText: 'Upgrade Now',
      buttonColor: AppColors.primary,
      filledButton: true,
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
             content: Text('Payment coming soon!', style: _patrickHand(color: Colors.white)),
             backgroundColor: AppColors.primary,
          ),
        );
      },
      isPopular: true,
    );
  }

   Widget _buildLifetimeCard(BuildContext context) {
    return _buildPricingCardBase(
      title: 'Lifetime',
      price: 'RM 199',
      period: 'one-time',
      features: [
        '🚀 Everything in Premium',
        '🚀 Lifetime access',
        '🚀 Future features included',
        '🚀 VIP support',
        '🚀 Early access',
      ],
      buttonText: 'Get Lifetime',
      buttonColor: AppColors.accent,
      filledButton: true,
      onPressed: () {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
             content: Text('Payment coming soon!', style: _patrickHand(color: Colors.white)),
             backgroundColor: AppColors.primary,
          ),
        );
      },
      isPopular: false,
    );
  }

  Widget _buildPricingCardBase({
    required String title,
    required String price,
    required String period,
    required List<String> features,
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
           _buildCardContent(title, price, period, features, buttonText, buttonColor, filledButton, onPressed, isPopular: true),
        ],
      );
    } else {
       return _buildCardContent(title, price, period, features, buttonText, buttonColor, filledButton, onPressed, isPopular: false);
    }
  }

  Widget _buildCardContent(
    String title, 
    String price, 
    String period, 
    List<String> features, 
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
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price,
                style: _patrickHand(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                period,
                style: _patrickHand(
                  fontSize: 20,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          WiredDivider(color: AppColors.border),
           const SizedBox(height: 32),
          ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline, // Sketchy-er outline icon
                      color: isPopular ? AppColors.primary : AppColors.success,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        feature,
                        style: _patrickHand(
                          fontSize: 18,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
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
