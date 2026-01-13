import 'package:flutter/material.dart';
import '../../../shared/wired/wired_widgets.dart';

class StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;

  const StatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2D3E50);

    return WiredCard(
      backgroundColor: Colors.white,
      borderColor: primaryColor.withValues(alpha: 0.3),
      borderWidth: 1.5,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WiredCard(
            padding: const EdgeInsets.all(10),
            backgroundColor: iconColor.withValues(alpha: 0.1),
            borderColor: iconColor.withValues(alpha: 0.5),
            borderWidth: 1,
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'PatrickHand',
              color: primaryColor.withValues(alpha: 0.7),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'PatrickHand',
              color: primaryColor,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'PatrickHand',
              color: primaryColor.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
