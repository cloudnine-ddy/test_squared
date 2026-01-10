import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/wired/wired_widgets.dart';
import 'widgets/ai_chat_panel.dart';
import 'question_detail_screen.dart';

/// Wrapper that adds split-screen layout with AI chat to question detail
class QuestionDetailScreenWithChat extends ConsumerStatefulWidget {
  final String questionId;
  final String? topicId;

  const QuestionDetailScreenWithChat({
    super.key,
    required this.questionId,
    this.topicId,
  });

  @override
  ConsumerState<QuestionDetailScreenWithChat> createState() => _QuestionDetailScreenWithChatState();
}

class _QuestionDetailScreenWithChatState extends ConsumerState<QuestionDetailScreenWithChat> {
  bool _showChat = true;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final isPremium = userAsync.maybeWhen(
      data: (user) => user?.isPremium ?? false,
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7), // Sketchy Beige
      body: LayoutBuilder(
        builder: (context, constraints) {
          // On narrow screens (mobile), don't show split
          final isNarrow = constraints.maxWidth < 900;

          if (isNarrow) {
            return QuestionDetailScreen(
              questionId: widget.questionId,
              topicId: widget.topicId,
            );
          }

          // Desktop: Split screen
          return Row(
            children: [
              // Left: Original question screen (60%)
              Expanded(
                flex: _showChat ? 6 : 10,
                child: QuestionDetailScreen(
                  questionId: widget.questionId,
                  topicId: widget.topicId,
                ),
              ),

              // Right: AI Chat (40%)
              if (_showChat)
                Expanded(
                  flex: 4,
                  child: Stack(
                      children: [
                         // Divider Line
                         Positioned(
                           left: 0, 
                           top: 0, 
                           bottom: 0, 
                           width: 2,
                           child: CustomPaint(
                             painter: WiredDividerPainter(
                               axis: Axis.vertical, 
                               color: AppColors.border, 
                               thickness: 2, 
                               seed: 123
                             ),
                           ),
                         ),
                         // Content
                         Container(
                           margin: const EdgeInsets.only(left: 2),
                           child: Column(
                             children: [
                               // Chat toggle header
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                 decoration: BoxDecoration(
                                   color: AppColors.surface,
                                   border: Border(
                                     bottom: BorderSide(color: AppColors.border, width: 1),
                                   ),
                                 ),
                                 child: Row(
                                   children: [
                                     const Spacer(),
                                     IconButton(
                                       onPressed: () {
                                         setState(() => _showChat = false);
                                       },
                                       icon: Icon(Icons.close, color: AppColors.textSecondary),
                                       tooltip: 'Hide AI Assistant',
                                     ),
                                   ],
                                 ),
                               ),
                               // Chat panel
                               Expanded(
                                 child: AIChatPanel(
                                   questionId: widget.questionId,
                                   isPremium: isPremium,
                                 ),
                               ),
                             ],
                           ),
                         ),
                      ],
                  ),
                ),
            ],
          );
        },
      ),
      // FAB to toggle chat on/off
      floatingActionButton: !_showChat
          ? FloatingActionButton.extended(
              onPressed: () {
                setState(() => _showChat = true);
              },
              backgroundColor: const Color(0xFF2D3E50), // Navy
              icon: const Icon(Icons.psychology, color: Colors.white),
              label: const Text(
                'AI Assistant',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'PatrickHand',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }
}
