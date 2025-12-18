import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';

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
      home: Scaffold(
        appBar: AppBar(
          title: const Text('TestSquared'),
        ),
      ),
    );
  }
}