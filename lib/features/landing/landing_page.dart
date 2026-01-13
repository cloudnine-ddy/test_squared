import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../auth/providers/auth_provider.dart';
import '../../main.dart' show isPasswordRecoverySession;
import '../vending/vending_page.dart';

/// Landing page for non-authenticated users
/// Modern design inspired by SaveMyExams with clean aesthetics
class LandingPage extends ConsumerWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Main entry point - show VendingPage
    return const VendingPage();
  }
}
