
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/wired/wired_widgets.dart';

class VendingPage extends StatelessWidget {
  const VendingPage({super.key});

  // Color constants
  static const Color _backgroundColor = Color(0xFFFDFBF7); // Cream background
  static const Color _primaryColor = Color(0xFF2D3E50); // Deep Navy Blue (from Logo Background)
  static const Color _accentColor = Color(0xFFD4C4A8); // Sand/Gold (from Logo 'T')

  // Helper for Patrick Hand text style
  TextStyle _patrickHand({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: 'PatrickHand',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? _primaryColor,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Navbar
            _buildNavBar(context),
            
            const SizedBox(height: 60),

            // 2. Hero Graphic
            // 2. Hero Section (Unified Card)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background Paper 1 (Rotated)
                    Positioned.fill(
                      child: Transform.rotate(
                        angle: -0.02,
                        child: Container(
                          margin: const EdgeInsets.all(10), // Margin to show rotation without clipping
                          child: WiredCard(
                            borderColor: _primaryColor.withValues(alpha: 0.3),
                            borderWidth: 2,
                            backgroundColor: Colors.white,
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                    // Background Paper 2 (Rotated)
                    Positioned.fill(
                      child: Transform.rotate(
                        angle: 0.015,
                        child: Container(
                          margin: const EdgeInsets.all(5),
                          child: WiredCard(
                            borderColor: _primaryColor.withValues(alpha: 0.5),
                            borderWidth: 2,
                            backgroundColor: Colors.white,
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                    // Main Content Card
                    WiredCard(
                      borderColor: _primaryColor,
                      borderWidth: 2, // Revert to standard thick
                      backgroundColor: const Color(0xFFFDFBF7),
                      padding: const EdgeInsets.all(48),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 900;
                          // ... content ... (copy exactly from existing)
                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Left Content
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Frictionless\nStudying.',
                                        style: _patrickHand(
                                          fontSize: 72,
                                          fontWeight: FontWeight.bold,
                                          color: _primaryColor,
                                          height: 1.0,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        'Unlock your potential with smart, adaptive learning.',
                                        style: _patrickHand(
                                          fontSize: 24,
                                          color: _primaryColor.withValues(alpha: 0.8),
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 40),
                                      Row(
                                        children: [
                                          WiredButton(
                                            onPressed: () => context.push('/dashboard'),
                                            filled: true,
                                            backgroundColor: _primaryColor,
                                            borderColor: _primaryColor,
                                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                            child: Text(
                                              'Try for Free',
                                              style: _patrickHand(
                                                color: Colors.white,
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 24),
                                          WiredButton(
                                            onPressed: () => context.push('/signup'),
                                            filled: false,
                                            borderColor: _primaryColor,
                                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                            child: Text(
                                              'Get Started Free',
                                              style: _patrickHand(
                                                color: _primaryColor,
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 48),
                                // Right Content (Image)
                                Expanded(
                                  flex: 6,
                                  child: Center(
                                    child: Container(
                                      constraints: const BoxConstraints(maxHeight: 400), // Reduced size
                                      child: Image.asset(
                                        'lib/core/assets/images/landing_hero_tablet.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          } else {
                            // Mobile
                            return Column(
                              children: [
                                Text(
                                  'Frictionless\nStudying.',
                                  textAlign: TextAlign.center,
                                  style: _patrickHand(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: _primaryColor,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Unlock your potential with smart, adaptive learning.',
                                  textAlign: TextAlign.center,
                                  style: _patrickHand(
                                    fontSize: 18,
                                    color: _primaryColor.withValues(alpha: 0.8),
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center, // Center buttons for mobile
                                    children: [
                                      WiredButton(
                                        onPressed: () => context.push('/dashboard'),
                                        filled: true,
                                        backgroundColor: _primaryColor,
                                        borderColor: _primaryColor,
                                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                        child: Text(
                                          'Try for Free',
                                          style: _patrickHand(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      WiredButton(
                                        onPressed: () => context.push('/signup'),
                                        filled: false,
                                        borderColor: _primaryColor,
                                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                        child: Text(
                                          'Get Started Free',
                                          style: _patrickHand(
                                            color: _primaryColor,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 48),
                                Image.asset(
                                  'lib/core/assets/images/landing_hero_tablet.png',
                                  fit: BoxFit.contain,
                                ),
                              ],
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 60),

            // 5. App Preview
            Container(
              constraints: const BoxConstraints(maxWidth: 1000),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: WiredCard(
                borderColor: _primaryColor.withValues(alpha: 0.2),
                borderWidth: 2.0,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(0),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      children: [
                        // Fake Browser Header
                        Container(
                          height: 40,
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Row(
                                children: [Colors.red, Colors.amber, Colors.green]
                                    .map((c) => Container(
                                          margin: const EdgeInsets.only(right: 8),
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: c.withValues(alpha: 0.5),
                                            shape: BoxShape.circle,
                                          ),
                                        ))
                                    .toList(),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Content Placeholder
                        Expanded(
                          child: Center(
                            child: Icon(
                              Icons.dashboard_customize_outlined,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 100),

            // 6. Features Section
            _buildFeaturesSection(context),

            const SizedBox(height: 100),

             // 7. Testimonials
            _buildTestimonialsSection(context),

            const SizedBox(height: 100),

            // 8. Footer
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  // ... (NavBar and HeroGraphic methods remain the same)

  Widget _buildFeaturesSection(BuildContext context) {
    final features = [
      {
        'icon': Icons.library_books_outlined,
        'title': 'Unlimited Past Papers',
        'desc': 'Access thousands of IGCSE, A-Level, and SPM papers instantly. No more hunting for PDFs.',
      },
      {
        'icon': Icons.psychology_outlined,
        'title': 'AI Marking Assistant',
        'desc': 'Get instant feedback on your answers. Our AI explains where you went wrong and how to fix it.',
      },
      {
        'icon': Icons.insights_outlined,
        'title': 'Progress Tracking',
        'desc': 'Visualize your improvement over time. Pinpoint your weak topics and master them.',
      },
    ];

    return Container(
      constraints: const BoxConstraints(maxWidth: 1200),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;
          return Column(
            children: [
              Text(
                'Why Test²?',
                style: _patrickHand(fontSize: 48, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: features.map((f) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: _buildFeatureCard(f),
                    ),
                  )).toList(),
                )
              else
                Column(
                  children: features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: _buildFeatureCard(f),
                  )).toList(),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFeatureCard(Map<String, dynamic> feature) {
    return WiredCard(
      borderColor: _primaryColor,
      backgroundColor: Colors.white,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(feature['icon'] as IconData, size: 48, color: _primaryColor),
          const SizedBox(height: 20),
          Text(
            feature['title'] as String,
            textAlign: TextAlign.center,
            style: _patrickHand(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            feature['desc'] as String,
            textAlign: TextAlign.center,
            style: _patrickHand(
              fontSize: 18, 
              color: _primaryColor.withValues(alpha: 0.8),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestimonialsSection(BuildContext context) {
    return Container(
      color: _primaryColor.withValues(alpha: 0.03), // Subtle background
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      child: Column(
        children: [
          Text(
            'Students ❤️ Test²',
            style: _patrickHand(fontSize: 48, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 60),
          Wrap(
            spacing: 40,
            runSpacing: 40,
            alignment: WrapAlignment.center,
            children: [
              _buildTestimonial(
                'Sarah J.', 
                'Straight As in A-Levels!', 
                'The AI marking is a lifesaver. It feels like having a private tutor 24/7.',
                Colors.orange[100]!,
              ),
              _buildTestimonial(
                'Michael T.', 
                'IGCSE Prep Made Easy', 
                'I used to hate doing past papers. TestSquared actually makes it fun to practice.',
                Colors.blue[100]!,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestimonial(String name, String headline, String quote, Color avatarColor) {
    return Container(
      width: 350,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          WiredCard(
            borderColor: _primaryColor,
            backgroundColor: Colors.white,
            padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: _patrickHand(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  '"$quote"',
                  style: _patrickHand(fontSize: 18, height: 1.5),
                ),
                const SizedBox(height: 20),
                Text(
                  '- $name',
                  style: _patrickHand(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Positioned(
            top: -24,
            left: 32,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: avatarColor,
                shape: BoxShape.circle,
                border: Border.all(color: _primaryColor, width: 2),
              ),
              child: Center(
                child: Text(
                  name[0],
                  style: _patrickHand(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      constraints: const BoxConstraints(maxWidth: 1200),
      child: Column(
        children: [
          WiredDivider(color: _primaryColor, thickness: 2),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Mini Logo
                      Container(
                        width: 30,
                        height: 30,
                        margin: const EdgeInsets.only(right: 8),
                         child: Image.asset('lib/core/assets/images/logo_box_test_squared.png'),
                      ),
                      Text(
                        'TestSquared',
                        style: _patrickHand(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '© 2026 TestSquared Inc.',
                    style: _patrickHand(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
              Row(
                children: [
                  _footerLink('Privacy'),
                  const SizedBox(width: 24),
                  _footerLink('Terms'),
                  const SizedBox(width: 24),
                  _footerLink('Contact'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footerLink(String text) {
    return Text(
      text,
      style: _patrickHand(
        fontSize: 18,
        color: _primaryColor,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildNavBar(BuildContext context) {
    return Container(
      width: double.infinity, // Full width
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), // Reduced vertical padding
      constraints: const BoxConstraints(minHeight: 100), // Ensure minimum height for Stack
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Left: Logo
          Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'lib/core/assets/images/logo_box_test_squared.png',
              height: 70, // Slightly smaller as requested
              fit: BoxFit.contain,
            ),
          ),
          
          // Center: Pricing Link
          if (MediaQuery.of(context).size.width > 600) 
            Align(
              alignment: Alignment.center,
              child: _navLink('Pricing', onTap: () => context.push('/premium')),
            ),

          // Right: Action Buttons
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min, // Keep minimal width for alignment
              children: [
                TextButton(
                  onPressed: () => context.push('/login'),
                  child: Text(
                    'Log in',
                    style: _patrickHand(
                      fontSize: 22, // Bigger
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                WiredButton(
                  onPressed: () => context.push('/signup'),
                  filled: true,
                  backgroundColor: _primaryColor,
                  borderColor: _primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // Reduced padding
                  child: Text(
                    'Get Started Free',
                    style: _patrickHand(
                      fontSize: 18, // Slightly smaller
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _navLink(String text, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Text(
        text,
        style: _patrickHand(
          fontSize: 20, // Slightly smaller to prevent overflow
          fontWeight: FontWeight.bold,
          color: _primaryColor,
        ),
      ),
    );
  }

    // _buildSketchyHeroGraphic removed as it's now integrated

}
