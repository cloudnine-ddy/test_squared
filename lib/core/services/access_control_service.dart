import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../widgets/access_dialogs.dart';

/// Service to handle access control checks for login and premium features
class AccessControlService {
  /// Check if user is logged in
  /// Shows LoginRequiredDialog if not logged in
  /// Returns true if logged in, false otherwise
  static bool checkLogin(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    
    if (!isAuthenticated) {
      showDialog(
        context: context,
        builder: (context) => const LoginRequiredDialog(),
      );
      return false;
    }
    
    return true;
  }

  /// Check if user has premium access
  /// Shows PremiumUpgradeDialog if not premium
  /// Returns true if premium, false otherwise
  static bool checkPremium(
    BuildContext context, 
    WidgetRef ref, {
    String featureName = 'Premium Feature',
    List<String>? highlights,
  }) {
    final isPremium = ref.read(isPremiumProvider);
    
    if (!isPremium) {
      showDialog(
        context: context,
        builder: (context) => PremiumUpgradeDialog(
          featureName: featureName,
          highlights: highlights,
        ),
      );
      return false;
    }
    
    return true;
  }
}
