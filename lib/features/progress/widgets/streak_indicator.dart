import 'package:flutter/material.dart';

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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFFFFECD2), // Peach
            const Color(0xFFFCB69F), // Orange
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
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
                    color: Colors.black.withValues(alpha: 0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '$currentStreak',
                      style: const TextStyle(
                        color: Color(0xFFE65100), // Deep Orange
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'day${currentStreak != 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.7),
                        fontSize: 18,
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
                      color: Colors.black.withValues(alpha: 0.5),
                      fontSize: 13,
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
