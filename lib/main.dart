import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://cixwhueqvtetnkgazyiy.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNpeHdodWVxdnRldG5rZ2F6eWl5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjYwNDI4MTAsImV4cCI6MjA4MTYxODgxMH0.go4SSD65qzsK8_4Vnrl443rH9EJgSKNRN949NQWhNEE',
  );

  runApp(const TestSquaredApp());
}

class TestSquaredApp extends StatelessWidget {
  const TestSquaredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TestSquared',
      theme: AppTheme.darkTheme,
      routerConfig: goRouter,
    );
  }
}
