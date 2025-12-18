import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';

void main() {
  runApp(const TestSquaredApp());
}

class TestSquaredApp extends StatelessWidget {
  const TestSquaredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TestSquared',
      theme: AppTheme.lightTheme,
      home: const LoginScreen(),
    );
  }
}
