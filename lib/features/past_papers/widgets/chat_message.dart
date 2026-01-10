import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/wired/wired_widgets.dart'; // Sketchy widgets

const _primaryColor = Color(0xFF2D3E50);

TextStyle _patrickHand({
  double fontSize = 16,
  FontWeight fontWeight = FontWeight.normal,
  Color? color,
  double? height,
}) {
  return TextStyle(
    fontFamily: 'PatrickHand',
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
  );
}

/// Individual chat message bubble
class ChatMessage extends StatelessWidget {
  final String message;
  final bool isAI;
  final DateTime timestamp;
  final Widget? contentWidget;

  const ChatMessage({
    super.key,
    required this.message,
    required this.isAI,
    required this.timestamp,
    this.contentWidget,
  });



  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isAI ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAI) ...[
            // AI Avatar
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _primaryColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Message bubble
          Flexible(
            child: WiredCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              // AI: White/Beige fill, Dark border. User: Dark fill, Dark border (or Light border?). 
              // User bubbles commonly solid color.
              // AI: White/Beige fill, Dark border. User: Dark fill, Dark border (or Light border?). 
              // User bubbles commonly solid color.
              backgroundColor: isAI ? Colors.white : _primaryColor,
              borderColor: _primaryColor, 
              borderWidth: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(
                    data: message,
                    styleSheet: MarkdownStyleSheet(
                      p: _patrickHand(
                        color: isAI ? AppColors.textPrimary : Colors.white,
                        fontSize: 16,
                        height: 1.3,
                      ),
                      strong: _patrickHand(
                        color: isAI ? AppColors.textPrimary : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16, // Ensure bold font size matches
                      ),
                      // Add more styles specific to markdown if needed (lists, code blocks etc)
                      listBullet: _patrickHand(
                         color: isAI ? AppColors.textPrimary : Colors.white,
                      ),
                    ),
                  ),
                  if (contentWidget != null) ...[
                    const SizedBox(height: 12),
                    contentWidget!,
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(timestamp),
                    style: _patrickHand(
                      color: isAI
                          ? AppColors.textSecondary.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (!isAI) ...[
            const SizedBox(width: 8),
            // User Avatar
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.person,
                color: AppColors.textPrimary,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// Typing indicator for AI
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // AI Avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _primaryColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),

          // Typing dots
          WiredCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            backgroundColor: Colors.white,
            borderColor: _primaryColor,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final delay = index * 0.2;
                    final value = (_controller.value - delay).clamp(0.0, 1.0);
                    final opacity = (value * 2).clamp(0.3, 1.0);

                    return Padding(
                      padding: EdgeInsets.only(left: index > 0 ? 4 : 0),
                      child: Opacity(
                        opacity: opacity,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
