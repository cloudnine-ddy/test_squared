import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/toast_service.dart';
import 'services/auth_service.dart';

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
            // Navigate first, then show success toast on dashboard
            context.go('/dashboard');
          }
        }
      } on AuthException catch (e) {
        print('AuthException: ${e.message}');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          // Show error message from Supabase
          final errorMessage = e.message.isNotEmpty
              ? e.message
              : 'Invalid email or password';
          ToastService.showError(errorMessage);
        }
      } catch (e, stackTrace) {
        print('Login error: $e');
        print('Stack trace: $stackTrace');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          // Extract error message from various exception types
          String errorMessage = 'Login failed: Check your email or password';

          // Try to extract message from exception
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
          } else if (e is AuthException) {
            errorMessage = e.message.isNotEmpty ? e.message : errorMessage;
          } else if (e.toString().isNotEmpty &&
              !errorString.contains('exception')) {
            // Only use the error string if it's meaningful
            final cleanError = e
                .toString()
                .replaceAll('Exception: ', '')
                .trim();
            if (cleanError.isNotEmpty && cleanError.length < 100) {
              errorMessage = cleanError;
            }
          }

          // Always show error toast
          print('Showing error toast: $errorMessage');
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

      // User cancelled the sign-in
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
        return;
      }

      // WEB: If redirect initiated (response is true boolean), just wait for redirect
      if (kIsWeb && response == true) {
        return;
      }

      // Sign-in successful (Mobile / Native)
      if (mounted) {
        final supabase = Supabase.instance.client;
        final user = supabase.auth.currentUser;
        
        if (user == null) {
          throw Exception('No user session found');
        }

        // Check user role
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
        
        // Show non-intrusive error
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
        color: AppColors.background,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Card(
                color: AppColors.surface,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.border, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo
                        const Text(
                          'Test²',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 40),
                        // Headline
                        const Text(
                          'Welcome Back',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Sub-headline
                        Text(
                          'Enter your details to access your study plan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            labelStyle: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                            hintText: 'Enter your email',
                            hintStyle: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border, width: 1.5),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border, width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppTheme.primaryBlue,
                                width: 2,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.email_outlined,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          style: const TextStyle(color: AppColors.textPrimary),
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
                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                            hintText: 'Enter your password',
                            hintStyle: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border, width: 1.5),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border, width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppTheme.primaryBlue,
                                width: 2,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.lock_outlined,
                              color: AppColors.textSecondary,
                            ),
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
                          ),
                          style: const TextStyle(color: AppColors.textPrimary),
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
                                color: AppTheme.primaryBlue,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Login Button
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
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
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Divider
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: AppColors.border,
                                thickness: 1,
                              ),
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
                            Expanded(
                              child: Divider(
                                color: AppColors.border,
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Google Sign-In Button
                        SizedBox(
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
                            icon: _isGoogleLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Image.asset(
                                    'assets/images/google_logo.png',
                                    width: 20,
                                    height: 20,
                                    errorBuilder: (context, error, stackTrace) {
                                      // Fallback if image not found
                                      return const Icon(
                                        Icons.g_mobiledata,
                                        size: 24,
                                        color: Colors.blue,
                                      );
                                    },
                                  ),
                            label: Text(
                              _isGoogleLoading ? 'Signing in...' : 'Continue with Google',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: BorderSide(color: AppColors.border, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
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
                                  color: AppTheme.primaryBlue,
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
            ),
          ),
        ),
      ),
    );
  }
}
