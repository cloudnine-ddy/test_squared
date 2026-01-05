import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/keys/app_keys.dart';
import 'core/services/accessibility_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://cixwhueqvtetnkgazyiy.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNpeHdodWVxdnRldG5rZ2F6eWl5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjYwNDI4MTAsImV4cCI6MjA4MTYxODgxMH0.go4SSD65qzsK8_4Vnrl443rH9EJgSKNRN949NQWhNEE',
  );



  // Initialize accessibility service
  final accessibilityService = AccessibilityService();
  await accessibilityService.init();

  runApp(
    // Wrap with ProviderScope for Riverpod support
    ProviderScope(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider.value(value: accessibilityService),
        ],
        child: const TestSquaredApp(),
      ),
    ),
  );
}

class TestSquaredApp extends StatelessWidget {
  const TestSquaredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, AccessibilityService>(
      builder: (context, themeProvider, accessibilityService, child) {
        // Apply accessibility overrides to theme
        var theme = AppTheme.lightTheme;
        var darkTheme = AppTheme.darkTheme;

        if (accessibilityService.dyslexiaFriendlyFont) {
          // In a real app, you'd add the font asset.
          // For now we'll use a widely available generic font or just basic sans-serif
          // distinct from the default to show the effect.
          // Or strictly speaking, we just rely on the service to switch usage if we had assets.
          // Since we don't have the asset, let's just make sure text scaling works perfectly first.
          // But I will apply the property so it's ready.
          /*
          theme = theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: 'OpenDyslexic'));
          darkTheme = darkTheme.copyWith(textTheme: darkTheme.textTheme.apply(fontFamily: 'OpenDyslexic'));
          */
        }

        if (accessibilityService.highContrastMode) {
           // Simple high contrast adjustment demo
           final highContrastScheme = ColorScheme.highContrastDark();
           darkTheme = darkTheme.copyWith(colorScheme: highContrastScheme);
           // similar for light theme if needed
        }

        return MaterialApp.router(
          title: 'TestSquared',
          theme: theme,
          darkTheme: darkTheme,
          themeMode: themeProvider.themeMode,
          routerConfig: goRouter,
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          builder: (context, child) {
            // Apply text scaling globally
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(accessibilityService.fontSizeMultiplier),
              ),
              child: child!,
            );
          },
        );
      },
    );
  }
}
