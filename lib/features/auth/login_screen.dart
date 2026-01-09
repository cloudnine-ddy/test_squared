import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;
import '../../core/theme/app_colors.dart';
import '../../core/services/toast_service.dart';
import 'services/auth_service.dart';
import '../../shared/wired/wired_widgets.dart';



import 'package:google_fonts/google_fonts.dart';

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
              content: Text('Sign-in cancelled', style: _patrickHand(color: Colors.white)),
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
            content: Text(e.toString().replaceAll('Exception: ', ''), style: _patrickHand(color: Colors.white)),
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
            content: Text('Google Sign-In failed: ${e.toString()}', style: _patrickHand(color: Colors.white)),
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
      backgroundColor: AppColors.background, // Used system beige
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 420),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Background Paper 1 (Rotated Left)
              Positioned.fill(
                child: Transform.rotate(
                  angle: -0.04, // Slightly less rotation
                  child: WiredCard(
                    borderColor: AppColors.primary.withOpacity(0.3),
                    backgroundColor: Colors.white,
                    child: Container(), // Empty container
                  ),
                ),
              ),
              // Background Paper 2 (Rotated Right)
              Positioned.fill(
                child: Transform.rotate(
                  angle: 0.02, // Slightly less rotation
                  child: WiredCard(
                    borderColor: AppColors.primary.withOpacity(0.3),
                    backgroundColor: Colors.white,
                    child: Container(),
                  ),
                ),
              ),
              
              // Main Login Card
              WiredCard(
                borderColor: AppColors.primary,
                backgroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24), // Tighter padding
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo
                      Center(
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 80), 
                          child: Image.asset(
                            'lib/core/assets/images/logo_box_test_squared.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Text(
                                'Test²',
                                textAlign: TextAlign.center,
                                style: _patrickHand(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8), // Reduced
                      // Headline
                      Text(
                        'Welcome Back',
                        textAlign: TextAlign.center,
                        style: _patrickHand(
                          fontSize: 32, 
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4), // Reduced
                      // Sub-headline
                      Text(
                        'Enter your details to access your study plan.',
                        textAlign: TextAlign.center,
                        style: _patrickHand(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16), // Reduced
                      // Email Field
                      _buildWiredTextField(
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
                      const SizedBox(height: 12), // Reduced
                      // Password Field
                      _buildWiredTextField(
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
                            context.go('/forgot-password');
                          },
                          child: Text(
                            'Forgot password?',
                            style: _patrickHand(
                              color: AppColors.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Login Button
                      WiredButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        borderColor: AppColors.primary,
                        backgroundColor: AppColors.primary,
                        filled: true,
                        padding: const EdgeInsets.symmetric(vertical: 10), // Reduced
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                'Login',
                                style: _patrickHand(
                                  fontSize: 22, // Slightly reduced
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                      const SizedBox(height: 16), // Reduced
                      // Divider
                      Row(
                        children: [
                          const Expanded(child: WiredDivider(thickness: 1.5)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: _patrickHand(
                                color: AppColors.textSecondary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Expanded(child: WiredDivider(thickness: 1.5)),
                        ],
                      ),
                      const SizedBox(height: 16), // Reduced
                      // Google Sign-In Button
                      WiredButton(
                        onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
                        borderColor: AppColors.textSecondary,
                        hoverColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 10), // Reduced
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isGoogleLoading)
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primary,
                                  ),
                                ),
                              )
                            else
                              Image.asset(
                                'assets/images/google_logo.png', // Assuming this asset exists, keeping it safe
                                width: 24,
                                height: 24,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.g_mobiledata,
                                    size: 32,
                                    color: AppColors.primary,
                                  );
                                },
                              ),
                            const SizedBox(width: 12),
                            Text(
                              _isGoogleLoading ? 'Signing in...' : 'Continue with Google',
                              style: _patrickHand(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Sign Up Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: _patrickHand(
                              color: AppColors.textSecondary,
                              fontSize: 18,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              context.go('/signup');
                            },
                            child: Text(
                              'Sign up',
                              style: _patrickHand(
                                color: AppColors.primary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWiredTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return WiredCard(
      borderColor: AppColors.border,
      backgroundColor: Colors.white,
      padding: EdgeInsets.zero, 
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0), // Minimal vertical padding
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: _patrickHand(
              color: AppColors.textSecondary,
              fontSize: 16, // Reduced form 18
            ),
            hintText: hint,
            hintStyle: _patrickHand(
              color: AppColors.textSecondary.withValues(alpha: 0.6),
              fontSize: 14, // Reduced from 16
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            icon: Icon(
              icon,
              color: AppColors.textSecondary,
              size: 18, // Reduced from 20
            ),
            suffixIcon: suffixIcon,
          ),
          style: _patrickHand(
            color: AppColors.textPrimary,
            fontSize: 18, // Reduced from 20
          ),
          validator: validator,
        ),
      ),
    );
  }
}
