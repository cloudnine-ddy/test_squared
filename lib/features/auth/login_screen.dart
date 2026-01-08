import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
    
    // Draw slightly wobbly rectangle
    final wobble = 2.0;
    
    // Top line
    path.moveTo(wobble * random.nextDouble(), wobble * random.nextDouble());
    path.lineTo(size.width - wobble * random.nextDouble(), wobble * random.nextDouble());
    
    // Right line  
    path.lineTo(size.width - wobble * random.nextDouble(), size.height - wobble * random.nextDouble());
    
    // Bottom line
    path.lineTo(wobble * random.nextDouble(), size.height - wobble * random.nextDouble());
    
    // Left line back to start
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

// Custom sketchy divider
class SketchyDivider extends StatelessWidget {
  final Color color;

  const SketchyDivider({super.key, this.color = AppColors.textSecondary});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 2),
      painter: _SketchyLinePainter(color: color),
    );
  }
}

class _SketchyLinePainter extends CustomPainter {
  final Color color;

  _SketchyLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final random = math.Random(42);
    final path = Path();
    
    path.moveTo(0, size.height / 2);
    
    double x = 0;
    while (x < size.width) {
      x += 5 + random.nextDouble() * 3;
      final y = size.height / 2 + (random.nextDouble() - 0.5) * 2;
      path.lineTo(x.clamp(0, size.width), y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await AuthService().signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (mounted) {
          final supabase = Supabase.instance.client;
          final user = supabase.auth.currentUser;
          if (user == null) {
            throw AuthException('No user session found.');
          }
          final profile = await supabase
              .from('profiles')
              .select('role')
              .eq('id', user.id)
              .maybeSingle();
          final role = (profile?['role'] as String?)?.toLowerCase() ?? 'student';
          setState(() {
            _isLoading = false;
          });
          if (role == 'admin') {
            context.go('/admin');
          } else {
            context.go('/dashboard');
          }
        }
      } on AuthException catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          final errorMessage = e.message.isNotEmpty
              ? e.message
              : 'Invalid email or password';
          ToastService.showError(errorMessage);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          String errorMessage = 'Login failed: Check your email or password';

          final errorString = e.toString().toLowerCase();
          if (errorString.contains('invalid login credentials') ||
              errorString.contains('invalid credentials') ||
              errorString.contains('email or password')) {
            errorMessage = 'Invalid email or password';
          } else if (errorString.contains('email not confirmed') ||
              errorString.contains('email not verified')) {
            errorMessage = 'Please verify your email first';
          } else if (errorString.contains('user not found')) {
            errorMessage = 'No account found with this email';
          } else if (errorString.contains('network') ||
              errorString.contains('connection')) {
            errorMessage = 'Network error: Please check your connection';
          }

          ToastService.showError(errorMessage);
        }
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isGoogleLoading = true;
    });

    try {
      final response = await AuthService().signInWithGoogle();

      if (response == null) {
        if (mounted) {
          setState(() {
            _isGoogleLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Sign-in cancelled'),
              backgroundColor: Colors.grey[700],
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      if (kIsWeb && response == true) {
        return;
      }

      if (mounted) {
        final supabase = Supabase.instance.client;
        final user = supabase.auth.currentUser;
        
        if (user == null) {
          throw Exception('No user session found');
        }

        final profile = await supabase
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();
            
        final role = (profile?['role'] as String?)?.toLowerCase() ?? 'student';
        
        setState(() {
          _isGoogleLoading = false;
        });
        
        if (role == 'admin') {
          context.go('/admin');
        } else {
          context.go('/dashboard');
        }
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign-In failed: ${e.toString()}'),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 3),
          ),
        );
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
                            const SizedBox(height: 8),
                            // Headline
                            const Text(
                              'Welcome Back',
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
                              'Enter your details to access your study plan.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Email Field with Sketchy styling
                            _buildSketchyTextField(
                              controller: _emailController,
                              label: 'Email',
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
                            const SizedBox(height: 8),
                            // Password Field with Sketchy styling
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
                            const SizedBox(height: 4),
                            // Forgot Password Link
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  // TODO: Implement forgot password
                                },
                                child: const Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Login Button - Filled Sketchy style
                            SketchyButton(
                              onPressed: _isLoading ? null : _handleLogin,
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
                                      'Login',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 10),
                            // Sketchy Divider with "OR"
                            Row(
                              children: [
                                const Expanded(
                                  child: SketchyDivider(),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'OR',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const Expanded(
                                  child: SketchyDivider(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Google Sign-In Button - Sketchy style
                            SketchyButton(
                              onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
                              borderColor: AppColors.textSecondary,
                              hoverColor: AppColors.background,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isGoogleLoading)
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          AppColors.primary,
                                        ),
                                      ),
                                    )
                                  else
                                    Image.asset(
                                      'assets/images/google_logo.png',
                                      width: 20,
                                      height: 20,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Icon(
                                          Icons.g_mobiledata,
                                          size: 24,
                                          color: AppColors.primary,
                                        );
                                      },
                                    ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _isGoogleLoading ? 'Signing in...' : 'Continue with Google',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Sign Up Link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account? ",
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    context.go('/signup');
                                  },
                                  child: const Text(
                                    'Sign up',
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
    return SketchyCard(
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
