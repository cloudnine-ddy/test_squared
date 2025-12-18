import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../keys/app_keys.dart';

class ToastService {
  // Hide any existing snackbar before showing a new one
  static void _hideCurrent() {
    rootScaffoldMessengerKey.currentState?.hideCurrentSnackBar();
  }

  // Base snackbar configuration
  static SnackBar _buildSnackBar({
    required String message,
    required IconData icon,
    required Color iconColor,
  }) {
    return SnackBar(
      content: Row(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.textWhite,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.white10,
          width: 1,
        ),
      ),
      backgroundColor: const Color(0xFF1F2937),
      duration: const Duration(milliseconds: 2500),
      showCloseIcon: true,
      closeIconColor: AppTheme.textGray,
    );
  }

  // Success toast
  static void showSuccess(String message) {
    _hideCurrent();
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      _buildSnackBar(
        message: message,
        icon: Icons.check_circle,
        iconColor: const Color(0xFF10B981), // Emerald
      ),
    );
  }

  // Error toast
  static void showError(String message) {
    _hideCurrent();
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      _buildSnackBar(
        message: message,
        icon: Icons.error_outline,
        iconColor: const Color(0xFFEF4444), // Red
      ),
    );
  }

  // Warning toast
  static void showWarning(String message) {
    _hideCurrent();
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      _buildSnackBar(
        message: message,
        icon: Icons.warning_amber,
        iconColor: const Color(0xFFF59E0B), // Amber
      ),
    );
  }

  // Info toast (for unpinned message)
  static void showInfo(String message) {
    _hideCurrent();
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      _buildSnackBar(
        message: message,
        icon: Icons.info_outline,
        iconColor: AppTheme.primaryBlue,
      ),
    );
  }
}

