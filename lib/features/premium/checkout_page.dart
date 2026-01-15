import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/wired/wired_widgets.dart';

/// Checkout page for payment processing
class CheckoutPage extends StatelessWidget {
  final String planType; // 'pro' or 'elite'
  
  const CheckoutPage({
    super.key,
    required this.planType,
  });

  // Color constants
  static const Color _primaryColor = Color(0xFF2D3E50);
  static const Color _backgroundColor = Color(0xFFFDFBF7);

  TextStyle _patrickHand({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'PatrickHand',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? _primaryColor,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isPro = planType.toLowerCase() == 'pro';
    final String planName = isPro ? 'Pro' : 'Elite';
    final String price = isPro ? 'RM 10' : 'RM 29';
    final Color accentColor = isPro ? AppColors.primary : AppColors.accent;
    
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _primaryColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Checkout',
          style: _patrickHand(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _primaryColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Plan icon
                WiredCard(
                  backgroundColor: accentColor.withValues(alpha: 0.1),
                  borderColor: accentColor,
                  borderWidth: 2.5,
                  padding: const EdgeInsets.all(24),
                  child: Icon(
                    isPro ? Icons.star : Icons.diamond,
                    size: 64,
                    color: accentColor,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Plan name
                Text(
                  'Test² $planName',
                  style: _patrickHand(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Price
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: _patrickHand(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '/ month',
                        style: _patrickHand(
                          fontSize: 18,
                          color: _primaryColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 48),
                
                // Placeholder content
                WiredCard(
                  backgroundColor: Colors.white,
                  borderColor: _primaryColor.withValues(alpha: 0.3),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.construction,
                        size: 48,
                        color: Colors.amber,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Payment Integration Coming Soon!',
                        textAlign: TextAlign.center,
                        style: _patrickHand(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We\'re working on integrating payment options.\nStay tuned!',
                        textAlign: TextAlign.center,
                        style: _patrickHand(
                          fontSize: 16,
                          color: _primaryColor.withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Back button
                SizedBox(
                  width: double.infinity,
                  child: WiredButton(
                    onPressed: () => context.pop(),
                    filled: false,
                    borderColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(
                      '← Back to Plans',
                      style: _patrickHand(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
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
}
