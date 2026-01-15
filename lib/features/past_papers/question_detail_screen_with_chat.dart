import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/providers/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/wired/wired_widgets.dart';
import 'widgets/ai_chat_panel.dart';
import 'question_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  double _splitRatio = 0.6; // Left panel takes 60% by default
  
  static const double _minLeftRatio = 0.3;
  static const double _maxLeftRatio = 0.8;
  static const double _dividerWidth = 8.0;
  static const String _ratioPrefKey = 'question_split_ratio';
  static const String _chatVisiblePrefKey = 'chat_visible_state';

  @override
  void initState() {
    super.initState();
    _loadLayoutSettings();
  }

  Future<void> _loadLayoutSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    final savedRatio = prefs.getDouble(_ratioPrefKey);
    final savedChatVisible = prefs.getBool(_chatVisiblePrefKey);

    if (mounted) {
      setState(() {
        if (savedRatio != null) {
          _splitRatio = savedRatio.clamp(_minLeftRatio, _maxLeftRatio);
        }
        if (savedChatVisible != null) {
          _showChat = savedChatVisible;
        }
      });
    }
  }

  Future<void> _saveSplitRatio(double ratio) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_ratioPrefKey, ratio);
  }

  Future<void> _saveChatVisibility(bool visible) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chatVisiblePrefKey, visible);
  }

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

          // Desktop: Split screen with resizable divider
          final totalWidth = constraints.maxWidth;
          final leftWidth = _showChat 
              ? (totalWidth - _dividerWidth) * _splitRatio 
              : totalWidth;
          final rightWidth = _showChat 
              ? (totalWidth - _dividerWidth) * (1 - _splitRatio) 
              : 0.0;

          return Row(
            children: [
              // Left: Original question screen
              SizedBox(
                width: leftWidth,
                child: QuestionDetailScreen(
                  questionId: widget.questionId,
                  topicId: widget.topicId,
                ),
              ),

              // Draggable Divider
              if (_showChat)
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        final newRatio = _splitRatio + (details.delta.dx / totalWidth);
                        _splitRatio = newRatio.clamp(_minLeftRatio, _maxLeftRatio);
                      });
                    },
                    onHorizontalDragEnd: (_) => _saveSplitRatio(_splitRatio),
                    child: Container(
                      width: _dividerWidth,
                      color: const Color(0xFFFDFBF7),
                      child: Center(
                        child: Container(
                          width: 4,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D3E50).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Right: AI Chat
              if (_showChat)
                SizedBox(
                  width: rightWidth,
                  child: Stack(
                      children: [
                         // Divider Line (sketchy)
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
                                // Chat panel
                                Expanded(
                                  child: AIChatPanel(
                                    questionId: widget.questionId,
                                    isPremium: isPremium,
                                    onClose: () {
                                      setState(() => _showChat = false);
                                      _saveChatVisibility(false);
                                    },
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
          ? Padding(
              padding: const EdgeInsets.only(bottom: 90, right: 16),
              child: UnconstrainedBox( // Force natural size
                child: WiredButton(
                  onPressed: () {
                    setState(() => _showChat = true);
                    _saveChatVisibility(true);
                  },
                  backgroundColor: const Color(0xFF2D3E50),
                  filled: true,
                  borderColor: const Color(0xFF2D3E50),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                        ),
                        child: const Icon(Icons.psychology, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Ask AI',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'PatrickHand',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
