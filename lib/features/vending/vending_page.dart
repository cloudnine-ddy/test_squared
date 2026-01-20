
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/wired/wired_widgets.dart';
import 'demo_video_player.dart';

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
                                  flex: 6,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Experience\nFrictionless Studying.',
                                        style: _patrickHand(
                                          fontSize: 64,
                                          fontWeight: FontWeight.bold,
                                          color: _primaryColor,
                                          height: 1.1,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        'Stop juggling tabs. Stop guessing. Get questions, answers, and AI-powered explanations all on a single page.',
                                        style: _patrickHand(
                                          fontSize: 22,
                                          color: _primaryColor.withValues(alpha: 0.8),
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 40),
                                      Row(
                                        children: [
                                          WiredButton(
                                            onPressed: () => context.push('/login'),
                                            filled: false,
                                            borderColor: _primaryColor,
                                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                            child: Text(
                                              'Log in',
                                              style: _patrickHand(
                                                color: _primaryColor,
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 24),
                                          WiredButton(
                                            onPressed: () => context.push('/signup'),
                                            filled: true,
                                            backgroundColor: _primaryColor,
                                            borderColor: _primaryColor,
                                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                            child: Text(
                                              'Sign up for free',
                                              style: _patrickHand(
                                                color: Colors.white,
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
                                const SizedBox(width: 32),
                                // Right Content (Image)
                                Expanded(
                                  flex: 5,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      constraints: const BoxConstraints(maxHeight: 400),
                                      margin: const EdgeInsets.only(right: 20),
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
                                  'Experience\nFrictionless Studying.',
                                  textAlign: TextAlign.center,
                                  style: _patrickHand(
                                    fontSize: 42,
                                    fontWeight: FontWeight.bold,
                                    color: _primaryColor,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Stop juggling tabs. Stop guessing. Get questions, answers, and AI-powered explanations all on a single page.',
                                  textAlign: TextAlign.center,
                                  style: _patrickHand(
                                    fontSize: 16,
                                    color: _primaryColor.withValues(alpha: 0.8),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 16,
                                    runSpacing: 16,
                                    children: [
                                      WiredButton(
                                        onPressed: () => context.push('/login'),
                                        filled: false,
                                        borderColor: _primaryColor,
                                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                        child: Text(
                                          'Log in',
                                          style: _patrickHand(
                                            color: _primaryColor,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      WiredButton(
                                        onPressed: () => context.push('/signup'),
                                        filled: true,
                                        backgroundColor: _primaryColor,
                                        borderColor: _primaryColor,
                                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                        child: Text(
                                          'Sign up for free',
                                          style: _patrickHand(
                                            color: Colors.white,
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
                        // Content - Demo Video
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                            child: const DemoVideoPlayer(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 80),

            // Section Divider
            _buildSectionDivider(),

            // NEW: Teacher Endorsement Section
            _buildTeacherEndorsementSection(context),

            const SizedBox(height: 100),

            // Section Divider
            _buildSectionDivider(),

            // NEW: Problem Section - "Why is studying so hard?"
            _buildProblemSection(context),

            const SizedBox(height: 100),

            // Section Divider
            _buildSectionDivider(),

            // NEW: Solution Section - "How We Fix It"
            _buildSolutionSection(context),

            const SizedBox(height: 100),

            // Section Divider
            _buildSectionDivider(),

            // NEW: Killer Feature Section - "Prepare for the Future"
            _buildKillerFeatureSection(context),

            const SizedBox(height: 100),

             // 7. Testimonials (no divider before - has its own background)
            _buildTestimonialsSection(context),

            const SizedBox(height: 100),

            // 8. CTA Section
            _buildCtaSection(context),

            const SizedBox(height: 100),

            // 9. Footer
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  // Sketchy section divider
  Widget _buildSectionDivider() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      margin: const EdgeInsets.only(bottom: 60),
      child: Row(
        children: [
          Expanded(
            child: WiredDivider(
              color: _primaryColor.withValues(alpha: 0.25),
              thickness: 2,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Transform.rotate(
              angle: 0.1,
              child: Text(
                '✦',
                style: TextStyle(
                  fontSize: 18,
                  color: _primaryColor.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
          Expanded(
            child: WiredDivider(
              color: _primaryColor.withValues(alpha: 0.25),
              thickness: 2,
            ),
          ),
        ],
      ),
    );
  }

  // Teacher Endorsement Section
  Widget _buildTeacherEndorsementSection(BuildContext context) {
    final teachers = [
      {
        'name': 'Cikgu Kalai',
        'role': 'Sejarah Teacher',
        'photo': 'lib/core/assets/images/teacher_cikgu_kalai.png',
        'highlights': [
          '23+ years teaching in KL & Selangor',
          'Runs her own tuition centre',
          'SPM seminar specialist',
        ],
        'color': const Color(0xFFFFF59D), // Yellow sticky note
      },
      {
        'name': 'Lee Min Kyung',
        'role': 'IGCSE Computer Science Teacher',
        'photo': 'lib/core/assets/images/teacher_lee_min_kyung.jpg',
        'highlights': [
          'Computer Science graduate from HKU',
          'Teaching IGCSE in Vietnam',
          'Expert in exam techniques & problem-solving',
        ],
        'color': const Color(0xFFB2EBF2), // Cyan sticky note
      },
    ];

    return Container(
      constraints: const BoxConstraints(maxWidth: 1000),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Section Header
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Icon(
                Icons.school_outlined,
                color: _primaryColor.withValues(alpha: 0.6),
                size: 36,
              ),
              Text(
                'Trusted by Educators',
                textAlign: TextAlign.center,
                style: _patrickHand(
                  fontSize: MediaQuery.of(context).size.width > 600 ? 52 : 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Hear from teachers who love Test²',
            style: _patrickHand(
              fontSize: 20,
              color: _primaryColor.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 48),

          // Teacher Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              
              if (isWide) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: teachers.map((t) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildTeacherCard(t),
                      ),
                    )).toList(),
                  ),
                );
              } else {
                return Column(
                  children: teachers.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _buildTeacherCard(t),
                  )).toList(),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherCard(Map<String, dynamic> teacher) {
    final color = teacher['color'] as Color;
    final highlights = teacher['highlights'] as List<String>;
    final photo = teacher['photo'] as String?;
    
    return Transform.rotate(
      angle: teacher['name'] == 'Cikgu Kalai' ? -0.02 : 0.02,
      child: WiredCard(
        backgroundColor: color,
        borderColor: _primaryColor.withValues(alpha: 0.4),
        borderWidth: 2,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circular Photo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _primaryColor.withValues(alpha: 0.5),
                  width: 3,
                ),
                image: photo != null
                    ? DecorationImage(
                        image: AssetImage(photo),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: photo == null
                  ? Center(
                      child: Icon(
                        Icons.person,
                        size: 60,
                        color: _primaryColor.withValues(alpha: 0.4),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 20),
            
            // Name
            Text(
              teacher['name'] as String,
              style: _patrickHand(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            
            // Role
            Text(
              teacher['role'] as String,
              style: _patrickHand(
                fontSize: 16,
                color: _primaryColor.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            
            // Sketchy Divider
            WiredDivider(
              color: _primaryColor.withValues(alpha: 0.3),
              thickness: 1.5,
            ),
            const SizedBox(height: 16),
            
            // Highlights (Bullet Points)
            ...highlights.map((highlight) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: _patrickHand(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      highlight,
                      style: _patrickHand(
                        fontSize: 17,
                        color: _primaryColor.withValues(alpha: 0.85),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )),
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
    final testimonials = [
      {
        'name': 'Sarah J.',
        'role': 'A-Level Student',
        'quote': 'The AI marking is a lifesaver. It feels like having a tutor available 24/7! My grades improved dramatically.',
        'color': const Color(0xFFFFF59D), // Yellow
        'rotation': -0.03,
        'offsetX': 0.0,
        'offsetY': 0.0,
      },
      {
        'name': 'Michael T.',
        'role': 'IGCSE Student',
        'quote': 'I used to hate past papers. Now I actually enjoy practicing because I can see my progress!',
        'color': const Color(0xFFB2EBF2), // Cyan
        'rotation': 0.025,
        'offsetX': 20.0,
        'offsetY': -15.0,
      },
      {
        'name': 'Aisha K.',
        'role': 'SPM Candidate',
        'quote': 'Topic filtering saved me so much time. No more wasting hours on random questions I\'m not ready for!',
        'color': const Color(0xFFF8BBD9), // Pink
        'rotation': -0.015,
        'offsetX': -10.0,
        'offsetY': 10.0,
      },
      {
        'name': 'David L.',
        'role': 'A-Level Student',
        'quote': 'Finally, a site that explains WHY an answer is correct. This is a total game changer for understanding concepts.',
        'color': const Color(0xFFC8E6C9), // Green
        'rotation': 0.035,
        'offsetX': 15.0,
        'offsetY': -20.0,
      },
      {
        'name': 'Emma W.',
        'role': 'IGCSE Student',
        'quote': 'The AI-generated questions are scary accurate. Felt like cheating when I saw similar ones in my actual exam!',
        'color': const Color(0xFFFFCCBC), // Orange
        'rotation': -0.02,
        'offsetX': -15.0,
        'offsetY': 5.0,
      },
    ];

    return Container(
      color: _primaryColor.withValues(alpha: 0.03),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      child: Column(
        children: [
          // Title
          Text(
            'What Students Are Saying',
            style: _patrickHand(fontSize: 52, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '💬 Real feedback from real students',
            style: _patrickHand(
              fontSize: 18,
              color: _primaryColor.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 60),
          
          // Scattered Sticky Notes
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              
              if (isWide) {
                // Wide: 2-row scattered layout
                return Column(
                  children: [
                    // Row 1: 3 notes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStickyNote(testimonials[0]),
                        const SizedBox(width: 30),
                        Transform.translate(
                          offset: const Offset(0, 30),
                          child: _buildStickyNote(testimonials[1]),
                        ),
                        const SizedBox(width: 30),
                        Transform.translate(
                          offset: const Offset(0, -10),
                          child: _buildStickyNote(testimonials[2]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    // Row 2: 2 notes (offset)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Transform.translate(
                          offset: const Offset(50, 0),
                          child: _buildStickyNote(testimonials[3]),
                        ),
                        const SizedBox(width: 60),
                        Transform.translate(
                          offset: const Offset(-30, 20),
                          child: _buildStickyNote(testimonials[4]),
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                // Mobile: stacked with offsets
                return Column(
                  children: testimonials.asMap().entries.map((entry) {
                    final index = entry.key;
                    final t = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: 24,
                        left: index.isEven ? 0 : 20,
                        right: index.isEven ? 20 : 0,
                      ),
                      child: _buildStickyNote(t),
                    );
                  }).toList(),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStickyNote(Map<String, dynamic> testimonial) {
    final color = testimonial['color'] as Color;
    final rotation = testimonial['rotation'] as double;
    
    return Transform.rotate(
      angle: rotation,
      child: WiredCard(
        backgroundColor: color,
        borderColor: _primaryColor.withValues(alpha: 0.4),
        borderWidth: 2,
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 260,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Quote icon
              Icon(
                Icons.format_quote,
                color: _primaryColor.withValues(alpha: 0.3),
                size: 28,
              ),
              const SizedBox(height: 8),
              // Quote text
              Text(
                testimonial['quote'] as String,
                style: _patrickHand(
                  fontSize: 17,
                  height: 1.5,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              // Sketchy divider
              WiredDivider(
                color: _primaryColor.withValues(alpha: 0.3),
                thickness: 1.5,
              ),
              const SizedBox(height: 16),
              // Name and Role
              Row(
                children: [
                  // Avatar circle
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _primaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _primaryColor.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        (testimonial['name'] as String)[0],
                        style: _patrickHand(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        testimonial['name'] as String,
                        style: _patrickHand(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                      Text(
                        testimonial['role'] as String,
                        style: _patrickHand(
                          fontSize: 14,
                          color: _primaryColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCtaSection(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 800),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: WiredCard(
        backgroundColor: _primaryColor.withValues(alpha: 0.05),
        borderColor: _primaryColor.withValues(alpha: 0.4),
        borderWidth: 2,
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
        child: Column(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.rocket_launch_outlined,
                color: _primaryColor,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            // Headline
            Text(
              'Ready to stop wasting time?',
              textAlign: TextAlign.center,
              style: _patrickHand(
                fontSize: 52,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Join thousands of students who are studying smarter, not harder.',
              textAlign: TextAlign.center,
              style: _patrickHand(
                fontSize: 18,
                color: _primaryColor.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            // CTA Button
            WiredButton(
              onPressed: () => context.push('/signup'),
              filled: true,
              backgroundColor: _primaryColor,
              borderColor: _primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Get Started for Free',
                    style: _patrickHand(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.push('/login'),
              child: Text(
                'Already have an account? Log in',
                style: _patrickHand(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
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
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => context.push('/login'),
                  child: Text(
                    'Log in',
                    style: _patrickHand(
                      fontSize: MediaQuery.of(context).size.width > 450 ? 22 : 18,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                ),
                SizedBox(width: MediaQuery.of(context).size.width > 450 ? 20 : 10),
                WiredButton(
                  onPressed: () => context.push('/signup'),
                  filled: true,
                  backgroundColor: _primaryColor,
                  borderColor: _primaryColor,
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width > 450 ? 20 : 12, 
                    vertical: 10,
                  ), 
                  child: Text(
                    'Get Started for Free',
                    style: _patrickHand(
                      fontSize: MediaQuery.of(context).size.width > 450 ? 18 : 14,
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

  // =============================================
  // NEW SECTIONS: Problem, Solution, Killer Feature
  // =============================================

  Widget _buildProblemSection(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1200),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Section Header
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Icon(Icons.psychology_outlined, color: _primaryColor.withValues(alpha: 0.6), size: 36),
              Text(
                'Why is studying so hard?',
                textAlign: TextAlign.center,
                style: _patrickHand(
                  fontSize: MediaQuery.of(context).size.width > 600 ? 52 : 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'We understand your frustrations.',
            style: _patrickHand(
              fontSize: 20,
              color: _primaryColor.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 48),

          // Problem Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              final problems = [
                {
                  'icon': Icons.tab_unselected,
                  'title': 'The Tab Fatigue',
                  'description': 'Traditional sites force you to open one tab for questions and another for answers. It breaks your flow.',
                  'color': Colors.red,
                },
                {
                  'icon': Icons.help_outline,
                  'title': 'The "Why" Gap',
                  'description': 'Seeing the answer isn\'t enough. If you don\'t understand WHY, you waste hours figuring it out.',
                  'color': Colors.orange,
                },
                {
                  'icon': Icons.block,
                  'title': 'The Knowledge Trap',
                  'description': 'Attempting questions on topics you haven\'t learned yet is frustrating and leads to giving up.',
                  'color': Colors.purple,
                },
              ];

              if (isWide) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: problems.map((p) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _buildProblemCard(p),
                      ),
                    )).toList(),
                  ),
                );
              } else {
                return Column(
                  children: problems.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _buildProblemCard(p),
                  )).toList(),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProblemCard(Map<String, dynamic> problem) {
    final color = problem['color'] as Color;
    return WiredCard(
      backgroundColor: color.withValues(alpha: 0.05),
      borderColor: color.withValues(alpha: 0.4),
      borderWidth: 1.5,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(problem['icon'] as IconData, color: color, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            problem['title'] as String,
            style: _patrickHand(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            problem['description'] as String,
            style: _patrickHand(
              fontSize: 17,
              color: _primaryColor.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSolutionSection(BuildContext context) {
    final solutions = [
      {
        'number': '1',
        'title': 'Everything in One View',
        'description': 'No more switching tabs. See the question, toggle the answer, and read a detailed AI explanation instantly. We remove the friction so you can focus on learning.',
        'icon': Icons.view_agenda_outlined,
        'color': Colors.blue,
      },
      {
        'number': '2',
        'title': 'Topic-Based Filtering',
        'description': 'Don\'t test yourself on what you haven\'t learned. Select only the topics you have studied and get relevant questions immediately.',
        'icon': Icons.filter_list,
        'color': Colors.green,
      },
      {
        'number': '3',
        'title': 'Progressive Difficulty',
        'description': 'We categorize questions from Easy to Hard. Build your confidence with the basics before tackling the complex application questions.',
        'icon': Icons.trending_up,
        'color': Colors.orange,
      },
    ];

    return Container(
      color: _primaryColor.withValues(alpha: 0.03),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              // Section Header
              Text(
                'How We Fix It',
                style: _patrickHand(
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 60),

              // Timeline-style alternating layout
              ...solutions.asMap().entries.map((entry) {
                final index = entry.key;
                final solution = entry.value;
                final isEven = index % 2 == 0;
                
                return _buildSolutionStep(
                  solution: solution,
                  isLeft: isEven,
                  isLast: index == solutions.length - 1,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSolutionStep({
    required Map<String, dynamic> solution,
    required bool isLeft,
    required bool isLast,
  }) {
    final color = solution['color'] as Color;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        
        // Mobile: always stack vertically
        if (!isWide) {
          return Column(
            children: [
              _buildSolutionStepContent(solution),
              if (!isLast) ...[
                const SizedBox(height: 16),
                // Connecting doodle arrow
                Transform.rotate(
                  angle: 0.1,
                  child: Icon(
                    Icons.arrow_downward,
                    color: _primaryColor.withValues(alpha: 0.3),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          );
        }
        
        // Desktop: alternating left-right layout
        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side
                Expanded(
                  child: isLeft 
                    ? _buildSolutionStepContent(solution)
                    : const SizedBox(),
                ),
                // Center - Number bubble with connecting line
                SizedBox(
                  width: 80,
                  child: Column(
                    children: [
                      // Number bubble
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color,
                            width: 3,
                            strokeAlign: BorderSide.strokeAlignOutside,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            solution['number'] as String,
                            style: _patrickHand(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                      ),
                      // Connecting sketchy line (except for last item)
                      if (!isLast)
                        CustomPaint(
                          size: const Size(4, 100),
                          painter: _SketchyLinePainter(color: _primaryColor.withValues(alpha: 0.3)),
                        ),
                    ],
                  ),
                ),
                // Right side
                Expanded(
                  child: !isLeft 
                    ? _buildSolutionStepContent(solution)
                    : const SizedBox(),
                ),
              ],
            ),
            if (!isLast) const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildSolutionStepContent(Map<String, dynamic> solution) {
    final color = solution['color'] as Color;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + Title row
          Row(
            children: [
              Icon(
                solution['icon'] as IconData,
                color: color,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  solution['title'] as String,
                  style: _patrickHand(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Description
          Text(
            solution['description'] as String,
            style: _patrickHand(
              fontSize: 17,
              color: _primaryColor.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKillerFeatureSection(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1100),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 750;
          
          return Column(
            children: [
              // Headline with sparkle
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 16,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber[400]!, Colors.orange[400]!],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
                  ),
                  Column(
                    crossAxisAlignment: isWide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Prepare for the Future,',
                        textAlign: isWide ? TextAlign.left : TextAlign.center,
                        style: _patrickHand(
                          fontSize: isWide ? 40 : 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [Colors.amber[600]!, Colors.orange[600]!],
                        ).createShader(bounds),
                        child: Text(
                          'Not Just the Past.',
                          textAlign: isWide ? TextAlign.left : TextAlign.center,
                          style: _patrickHand(
                            fontSize: isWide ? 40 : 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 48),

              // Before / After comparison cards
              if (isWide)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Before - The Problem
                      Expanded(child: _buildComparisonCard(
                        title: 'The Problem',
                        emoji: '😓',
                        description: 'Application-type questions are rare—appearing only once or twice a year. Once you finish them, you have nothing left to practice.',
                        isNegative: true,
                      )),
                      const SizedBox(width: 24),
                      // Arrow
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _primaryColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.arrow_forward, color: _primaryColor, size: 24),
                          ),
                        ],
                      ),
                      const SizedBox(width: 24),
                      // After - Our Solution
                      Expanded(child: _buildComparisonCard(
                        title: 'Our Solution',
                        emoji: '🚀',
                        description: 'Our AI analyzes past trends to generate NEW, unlimited application questions. Practice for what might come out this year!',
                        isNegative: false,
                      )),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    _buildComparisonCard(
                      title: 'The Problem',
                      emoji: '😓',
                      description: 'Application-type questions are rare—appearing only once or twice a year. Once you finish them, you have nothing left to practice.',
                      isNegative: true,
                    ),
                    const SizedBox(height: 16),
                    Icon(Icons.arrow_downward, color: _primaryColor.withValues(alpha: 0.5), size: 32),
                    const SizedBox(height: 16),
                    _buildComparisonCard(
                      title: 'Our Solution',
                      emoji: '🚀',
                      description: 'Our AI analyzes past trends to generate NEW, unlimited application questions. Practice for what might come out this year!',
                      isNegative: false,
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildComparisonCard({
    required String title,
    required String emoji,
    required String description,
    required bool isNegative,
  }) {
    final color = isNegative ? Colors.red : Colors.green;
    return WiredCard(
      backgroundColor: color.withValues(alpha: 0.05),
      borderColor: color.withValues(alpha: 0.4),
      borderWidth: 2,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emoji + Title
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Text(
                title,
                style: _patrickHand(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Description
          Text(
            description,
            style: _patrickHand(
              fontSize: 18,
              color: _primaryColor.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          // Visual indicator
          Row(
            children: List.generate(
              isNegative ? 2 : 5,
              (i) => Container(
                width: 24,
                height: 6,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

// Custom painter for sketchy dashed line
class _SketchyLinePainter extends CustomPainter {
  final Color color;
  
  _SketchyLinePainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    
    // Draw sketchy dashed line with slight wobble
    double y = 0;
    while (y < size.height) {
      final wobble = (y % 20 < 10) ? 1.0 : -1.0;
      canvas.drawLine(
        Offset(size.width / 2 + wobble, y),
        Offset(size.width / 2 - wobble, y + 8),
        paint,
      );
      y += 15; // Gap between dashes
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
