import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

void main() {
  runApp(const TestSquaredApp());
}

class TestSquaredApp extends StatelessWidget {
  const TestSquaredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TestSquared',
      theme: AppTheme.lightTheme,
      routerConfig: goRouter,
    );
  }
}
