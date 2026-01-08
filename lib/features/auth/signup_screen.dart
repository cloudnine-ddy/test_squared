import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;
import '../../core/theme/app_colors.dart';
import '../../core/services/toast_service.dart';
import 'services/auth_service.dart';

// Custom painter for hand-drawn/sketchy border effect
class SketchyBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int seed;

  SketchyBorderPainter({
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
class SketchyCard extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  final Color? backgroundColor;
  final double borderWidth;

  const SketchyCard({
    super.key,
    required this.child,
    this.borderColor = AppColors.primary,
    this.backgroundColor,
    this.borderWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: SketchyBorderPainter(
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
class SketchyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color borderColor;
  final Color? backgroundColor;
  final Color hoverColor;
  final bool filled;

  const SketchyButton({
    super.key,
    required this.child,
    this.onPressed,
    this.borderColor = AppColors.primary,
    this.backgroundColor,
    this.hoverColor = const Color(0xFFE8E0D0),
    this.filled = false,
  });

  @override
  State<SketchyButton> createState() => _SketchyButtonState();
}

class _SketchyButtonState extends State<SketchyButton> {
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
            painter: SketchyBorderPainter(
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

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await AuthService().signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _nameController.text.trim(),
        );

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          ToastService.showSuccess('Account created successfully!');
          context.go('/dashboard');
        }
      } on AuthException catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ToastService.showError(e.message);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ToastService.showError('An error occurred: ${e.toString()}');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppColors.background,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sketchy Card container
                  SketchyCard(
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
                            const SizedBox(height: 16),
                            // Headline
                            const Text(
                              'Create Account',
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
                              'Join Test² Today',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Full Name Field
                            _buildSketchyTextField(
                              controller: _nameController,
                              label: 'Full Name',
                              hint: 'Enter your full name',
                              icon: Icons.person_outlined,
                              keyboardType: TextInputType.name,
                              textCapitalization: TextCapitalization.words,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your full name';
                                }
                                if (value.length < 2) {
                                  return 'Name must be at least 2 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            // Email Field
                            _buildSketchyTextField(
                              controller: _emailController,
                              label: 'Email Address',
                              hint: 'Enter your email',
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
                            const SizedBox(height: 12),
                            // Password Field
                            _buildSketchyTextField(
                              controller: _passwordController,
                              label: 'Password',
                              hint: 'Enter your password',
                              icon: Icons.lock_outlined,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            // Confirm Password Field
                            _buildSketchyTextField(
                              controller: _confirmPasswordController,
                              label: 'Confirm Password',
                              hint: 'Re-enter your password',
                              icon: Icons.lock_outlined,
                              obscureText: _obscureConfirmPassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword = !_obscureConfirmPassword;
                                  });
                                },
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please confirm your password';
                                }
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            // Sign Up Button - Filled Sketchy style
                            SketchyButton(
                              onPressed: _isLoading ? null : _handleSignUp,
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
                                      'Sign Up',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 16),
                            // Login Link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Already have an account? ',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    context.go('/login');
                                  },
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
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return SketchyCard(
      borderColor: AppColors.border,
      backgroundColor: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
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
