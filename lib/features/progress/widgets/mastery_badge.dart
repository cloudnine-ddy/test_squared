import 'package:flutter/material.dart';
import '../../../shared/wired/wired_widgets.dart';

class MasteryBadge extends StatelessWidget {
  final String level; // 'beginner', 'intermediate', 'advanced'

  const MasteryBadge({
    super.key,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(level);

    return WiredCard(
      backgroundColor: config.color.withValues(alpha: 0.1),
      borderColor: config.color.withValues(alpha: 0.5),
      borderWidth: 1.0,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config.icon,
            color: config.color,
            size: 18,
          ),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: TextStyle(
              fontFamily: 'PatrickHand',
              color: config.color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
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
