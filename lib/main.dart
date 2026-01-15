import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart' as legacy_provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/keys/app_keys.dart';
import 'core/services/accessibility_service.dart';

// Global flag to indicate if this is a password recovery session
bool isPasswordRecoverySession = false;

// Global flag to indicate if this is an OAuth callback
bool isOAuthCallback = false;

// Function to reset the recovery flag (called from ResetPasswordPage)
void resetPasswordRecoveryFlag() {
  isPasswordRecoverySession = false;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Enable path-based URLs (removes # from URL)
  usePathUrlStrategy();

  // Check URL for auth-related parameters before initializing Supabase
  if (kIsWeb) {
    final currentUrl = Uri.base.toString();
    final fragment = Uri.base.fragment;
    
    print('[Main] Current URL: $currentUrl');
    print('[Main] URL Fragment: $fragment');
    
    // Check for password recovery
    if (currentUrl.contains('type=recovery') || fragment.contains('type=recovery')) {
      isPasswordRecoverySession = true;
      print('[Main] Detected password recovery session');
    }
    
    // Check for OAuth callback (access_token in fragment means OAuth completed)
    if (fragment.contains('access_token=')) {
      isOAuthCallback = true;
      print('[Main] Detected OAuth callback with access_token');
    }
  }

  await Supabase.initialize(
    url: 'https://cixwhueqvtetnkgazyiy.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNpeHdodWVxdnRldG5rZ2F6eWl5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjYwNDI4MTAsImV4cCI6MjA4MTYxODgxMH0.go4SSD65qzsK8_4Vnrl443rH9EJgSKNRN949NQWhNEE',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  // Initialize accessibility service
  final accessibilityService = AccessibilityService();
  await accessibilityService.init();

  runApp(
    // Wrap with ProviderScope for Riverpod support
    ProviderScope(
      child: legacy_provider.MultiProvider(
        providers: [
          // Keep accessibility service as pure Provider for now
          legacy_provider.ChangeNotifierProvider.value(value: accessibilityService),
        ],
        child: const TestSquaredApp(),
      ),
    ),
  );
}


class TestSquaredApp extends ConsumerStatefulWidget {
  const TestSquaredApp({super.key});

  @override
  ConsumerState<TestSquaredApp> createState() => _TestSquaredAppState();
}

class _TestSquaredAppState extends ConsumerState<TestSquaredApp> {
  @override
  void initState() {
    super.initState();
    // Redirect logic moved to GoRouter (app_router.dart) for better web support
  }


  @override
  Widget build(BuildContext context) {
    // Watch Theme Mode from Riverpod
    final themeMode = ref.watch(themeModeProvider);

    // Watch Accessibility (Legacy Provider)
    final accessibilityService = legacy_provider.Provider.of<AccessibilityService>(context);

    // Apply accessibility overrides to theme
    var theme = AppTheme.lightTheme;
    var darkTheme = AppTheme.darkTheme;

    if (accessibilityService.dyslexiaFriendlyFont) {
       // Font override logic
    }

    if (accessibilityService.highContrastMode) {
       final highContrastScheme = ColorScheme.highContrastDark();
       darkTheme = darkTheme.copyWith(colorScheme: highContrastScheme);
    }

    return MaterialApp.router(
      title: 'TestSquared',
      theme: theme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: goRouter,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(accessibilityService.fontSizeMultiplier),
          ),
          child: child!,
        );
      },
    );
  }
}
