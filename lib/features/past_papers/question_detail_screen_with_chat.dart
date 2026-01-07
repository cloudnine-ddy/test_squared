import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
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
      backgroundColor: AppColors.background,
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
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: AppColors.border, width: 1),
                      ),
                    ),
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
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.psychology, color: Colors.white),
              label: const Text(
                'AI Assistant',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }
}
