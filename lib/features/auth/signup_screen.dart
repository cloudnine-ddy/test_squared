import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math' as math;
import '../../core/theme/app_colors.dart';
import '../../core/services/toast_service.dart';
import 'services/auth_service.dart';
import '../../shared/wired/wired_widgets.dart';



import 'package:google_fonts/google_fonts.dart';

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
          
          // Check if email confirmation is required
          final supabase = Supabase.instance.client;
          final user = supabase.auth.currentUser;
          
          if (user != null && user.emailConfirmedAt != null) {
            // Email already confirmed (or confirmation not required)
            ToastService.showSuccess('Account created successfully!');
            context.go('/dashboard');
          } else {
            // Email confirmation required - show message and stay on page
            _showEmailConfirmationDialog();
          }
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

  void _showEmailConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          'Check Your Email 📧',
          style: _patrickHand(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'We\'ve sent a confirmation link to:',
              style: _patrickHand(fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              _emailController.text.trim(),
              style: _patrickHand(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Please click the link in the email to verify your account, then come back to login.',
              style: _patrickHand(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/login');
            },
            child: Text(
              'Go to Login',
              style: _patrickHand(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
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
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Background Paper 1 (Rotated Left)
                Positioned.fill(
                  child: Transform.rotate(
                    angle: -0.04,
                    child: WiredCard(
                      borderColor: AppColors.primary.withOpacity(0.3),
                      backgroundColor: Colors.white,
                      child: Container(),
                    ),
                  ),
                ),
                // Background Paper 2 (Rotated Right)
                Positioned.fill(
                  child: Transform.rotate(
                    angle: 0.02,
                    child: WiredCard(
                      borderColor: AppColors.primary.withOpacity(0.3),
                      backgroundColor: Colors.white,
                      child: Container(),
                    ),
                  ),
                ),
                
                // Main Sign Up Card
                WiredCard(
                  borderColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo
                        Center(
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 70), // Reduced from 100
                            child: Image.asset(
                              'lib/core/assets/images/logo_box_test_squared.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Text(
                                  'Test²',
                                  textAlign: TextAlign.center,
                                  style: _patrickHand(
                                    fontSize: 32, // Reduced from 36
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8), // Reduced from 12
                        // Headline
                        Text(
                          'Create Account',
                          textAlign: TextAlign.center,
                          style: _patrickHand(
                            fontSize: 28, // Reduced from 32
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2), // Reduced from 4
                        // Sub-headline
                        Text(
                          'Join Test² Today',
                          textAlign: TextAlign.center,
                          style: _patrickHand(
                            fontSize: 14, // Reduced from 16
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12), // Reduced from 20
                        // Full Name Field
                        _buildWiredTextField(
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
                        const SizedBox(height: 8), // Reduced from 12
                        // Email Field
                        _buildWiredTextField(
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
                        const SizedBox(height: 12),
                        // Confirm Password Field
                        _buildWiredTextField(
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
                        const SizedBox(height: 12), // Reduced from 20
                        // Sign Up Button
                        WiredButton(
                          onPressed: _isLoading ? null : _handleSignUp,
                          borderColor: AppColors.primary,
                          backgroundColor: AppColors.primary,
                          filled: true,
                          padding: const EdgeInsets.symmetric(vertical: 10),
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
                                  'Sign Up',
                                  style: _patrickHand(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 12), // Reduced from 16
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
                        const SizedBox(height: 12), // Reduced from 16
                        // Google Sign-In Button
                        WiredButton(
                          onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
                          borderColor: AppColors.textSecondary,
                          hoverColor: AppColors.background,
                          padding: const EdgeInsets.symmetric(vertical: 10),
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
                        const SizedBox(height: 12), // Reduced from 16
                        // Login Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: _patrickHand(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                context.go('/login');
                              },
                              child: Text(
                                'Login',
                                style: _patrickHand(
                                  color: AppColors.primary,
                                  fontSize: 16,
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
      ),
    );
  }

  Widget _buildWiredTextField({
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
    return WiredCard(
      borderColor: AppColors.border,
      backgroundColor: Colors.white,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          obscureText: obscureText,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: _patrickHand(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
            hintText: hint,
            hintStyle: _patrickHand(
              color: AppColors.textSecondary.withValues(alpha: 0.6),
              fontSize: 14,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            icon: Icon(
              icon,
              color: AppColors.textSecondary,
              size: 18,
            ),
            suffixIcon: suffixIcon,
          ),
          style: _patrickHand(
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
          validator: validator,
        ),
      ),
    );
  }
}
