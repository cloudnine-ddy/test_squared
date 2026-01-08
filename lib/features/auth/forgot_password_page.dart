import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import '../../core/theme/app_colors.dart';
import '../../core/services/toast_service.dart';
import 'services/auth_service.dart';

// Custom painter for hand-drawn/sketchy border effect
class _SketchyBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int seed;

  _SketchyBorderPainter({
    required this.color,
    this.strokeWidth = 2.0,
    this.seed = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final random = math.Random(seed);
    final path = Path();
    
    final wobble = 2.0;
    
    path.moveTo(wobble * random.nextDouble(), wobble * random.nextDouble());
    path.lineTo(size.width - wobble * random.nextDouble(), wobble * random.nextDouble());
    path.lineTo(size.width - wobble * random.nextDouble(), size.height - wobble * random.nextDouble());
    path.lineTo(wobble * random.nextDouble(), size.height - wobble * random.nextDouble());
    path.lineTo(wobble * random.nextDouble(), wobble * random.nextDouble());

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom sketchy card widget
class _SketchyCard extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  final Color? backgroundColor;
  final double borderWidth;

  const _SketchyCard({
    required this.child,
    this.borderColor = AppColors.primary,
    this.backgroundColor,
    this.borderWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SketchyBorderPainter(
        color: borderColor,
        strokeWidth: borderWidth,
        seed: hashCode,
      ),
      child: Container(
        color: backgroundColor,
        child: child,
      ),
    );
  }
}

// Custom sketchy button widget
class _SketchyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color borderColor;
  final Color? backgroundColor;
  final Color hoverColor;
  final bool filled;

  const _SketchyButton({
    required this.child,
    this.onPressed,
    this.borderColor = AppColors.primary,
    this.backgroundColor,
    this.hoverColor = const Color(0xFFE8E0D0),
    this.filled = false,
  });

  @override
  State<_SketchyButton> createState() => _SketchyButtonState();
}

class _SketchyButtonState extends State<_SketchyButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    if (widget.filled) {
      bgColor = _isHovered 
          ? widget.backgroundColor?.withAlpha(220) ?? AppColors.primary.withAlpha(220)
          : widget.backgroundColor ?? AppColors.primary;
    } else {
      bgColor = _isHovered ? widget.hoverColor : Colors.transparent;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          child: CustomPaint(
            painter: _SketchyBorderPainter(
              color: widget.borderColor,
              strokeWidth: 2.0,
              seed: hashCode,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              color: bgColor,
              child: Center(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleResetRequest() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        await AuthService().resetPasswordForEmail(_emailController.text.trim());
        
        if (mounted) {
          setState(() {
            _isLoading = false;
            _emailSent = true;
          });
          ToastService.showSuccess('Password reset email sent! Check your inbox.');
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ToastService.showError('Failed to send reset email. Please try again.');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SketchyCard(
                    borderColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Logo
                            Center(
                              child: Container(
                                constraints: const BoxConstraints(maxHeight: 150),
                                child: Image.asset(
                                  'lib/core/assets/images/testsquared_logo.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Text(
                                      'Test²',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                        letterSpacing: 1.2,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Headline
                            const Text(
                              'Reset Password',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Sub-headline
                            Text(
                              _emailSent 
                                ? 'Check your email for the reset link.'
                                : 'Enter your email to receive a password reset link.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            if (_emailSent) ...[
                              // Success state
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.green.withAlpha(30),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.withAlpha(100)),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.mark_email_read_outlined,
                                      size: 48,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Email sent to ${_emailController.text}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.green,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Back to Login Button
                              _SketchyButton(
                                onPressed: () => context.go('/login'),
                                borderColor: AppColors.primary,
                                backgroundColor: AppColors.primary,
                                filled: true,
                                child: const Text(
                                  'Back to Login',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ] else ...[
                              // Email Input
                              _buildSketchyTextField(
                                controller: _emailController,
                                label: 'Email',
                                hint: 'Enter your email address',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              // Send Reset Link Button
                              _SketchyButton(
                                onPressed: _isLoading ? null : _handleResetRequest,
                                borderColor: AppColors.primary,
                                backgroundColor: AppColors.primary,
                                filled: true,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Text(
                                        'Send Reset Link',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            // Back to Login Link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Remember your password? ',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => context.go('/login'),
                                  child: const Text(
                                    'Login',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSketchyTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return _SketchyCard(
      borderColor: AppColors.border,
      backgroundColor: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(
              color: AppColors.textSecondary,
            ),
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.textSecondary.withAlpha(150),
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            filled: true,
            fillColor: Colors.transparent,
            prefixIcon: Icon(
              icon,
              color: AppColors.textSecondary,
            ),
            suffixIcon: suffixIcon,
          ),
          style: const TextStyle(color: AppColors.textPrimary),
          validator: validator,
        ),
      ),
    );
  }
}
