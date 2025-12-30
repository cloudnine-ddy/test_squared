import 'package:flutter/material.dart';

class MasteryBadge extends StatelessWidget {
  final String level; // 'beginner', 'intermediate', 'advanced'

  const MasteryBadge({
    super.key,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(level);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: config.color.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config.icon,
            color: config.color,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: TextStyle(
              color: config.color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeConfig _getConfig(String level) {
    switch (level) {
      case 'beginner':
        return _BadgeConfig(
          label: 'Beginner',
          color: Colors.orange,
          icon: Icons.school_outlined,
        );
      case 'intermediate':
        return _BadgeConfig(
          label: 'Intermediate',
          color: Colors.blue,
          icon: Icons.trending_up,
        );
      case 'advanced':
        return _BadgeConfig(
          label: 'Advanced',
          color: Colors.green,
          icon: Icons.emoji_events,
        );
      default:
        return _BadgeConfig(
          label: 'Unknown',
          color: Colors.grey,
          icon: Icons.help_outline,
        );
    }
  }
}

class _BadgeConfig {
  final String label;
  final Color color;
  final IconData icon;

  _BadgeConfig({
    required this.label,
    required this.color,
    required this.icon,
  });
}
