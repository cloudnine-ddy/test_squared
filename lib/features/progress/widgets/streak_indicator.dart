import 'package:flutter/material.dart';
import '../../../shared/wired/wired_widgets.dart';

class StreakIndicator extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;

  const StreakIndicator({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2D3E50);

    return WiredCard(
      backgroundColor: const Color(0xFFFFF8E1), // Light yellow/orange tint
      borderColor: Colors.orange.withValues(alpha: 0.5),
      borderWidth: 1.5,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          WiredCard(
            padding: const EdgeInsets.all(12),
            backgroundColor: Colors.white,
            borderColor: Colors.orange.withValues(alpha: 0.5),
            borderWidth: 1.5,
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: Colors.deepOrange,
              size: 36,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Study Streak',
                  style: TextStyle(
                    fontFamily: 'PatrickHand',
                    color: primaryColor.withValues(alpha: 0.7),
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '$currentStreak',
                      style: const TextStyle(
                        fontFamily: 'PatrickHand',
                        color: Color(0xFFE65100), // Deep Orange
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'day${currentStreak != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontFamily: 'PatrickHand',
                        color: primaryColor.withValues(alpha: 0.7),
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (longestStreak > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Best: $longestStreak day${longestStreak != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontFamily: 'PatrickHand',
                      color: primaryColor.withValues(alpha: 0.5),
                      fontSize: 17,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
