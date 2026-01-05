import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Riverpod
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../models/question_model.dart';
import '../../progress/utils/question_status_helper.dart';
import 'formatted_question_text.dart';
import 'topic_tags.dart';
import '../../bookmarks/widgets/bookmark_button.dart';
import '../../auth/providers/auth_provider.dart'; // Auth Provider
import 'ai_chat_panel.dart'; // AI Chat Panel

class MultipleChoiceFeedCard extends ConsumerStatefulWidget {
  final QuestionModel question;
  final String? paperName;
  final Map<String, dynamic>? latestAttempt;
  final Function(String?)? onAnswerChanged;
  final Function(bool)? onCheckResult;

  const MultipleChoiceFeedCard({
    super.key,
    required this.question,
    this.paperName,
    this.latestAttempt,
    this.onAnswerChanged,
    this.onCheckResult,
  });

  @override
  ConsumerState<MultipleChoiceFeedCard> createState() => _MultipleChoiceFeedCardState();
}

class _MultipleChoiceFeedCardState extends ConsumerState<MultipleChoiceFeedCard> {
  String? _selectedAnswer;
  bool _isChecked = false;
  bool _isCorrect = false;
  bool _showExplanation = false;
  bool _isRevealed = false; // New state for 'Reveal Answer'

  @override
  void initState() {
    super.initState();
    if (widget.latestAttempt != null) {
      // If there is a previous attempt, restore it (optional, or just show status)
      // For this feed card, we usually start fresh or show the status badge.
      // If we wanted to lock the state:
      // _selectedAnswer = widget.latestAttempt!['selected_option'];
      // _isChecked = true;
      // _isCorrect = widget.latestAttempt!['is_correct'] ?? false;
    }
  }

  void _selectAnswer(String answer) {
    if (_isChecked || _isRevealed) return; // Prevent changing after check/reveal
    setState(() {
      _selectedAnswer = answer;
    });
    widget.onAnswerChanged?.call(answer);
  }

  void _checkAnswer() {
    if (_selectedAnswer == null) return;

    final correct = widget.question.effectiveCorrectAnswer;
    final isCorrect = _selectedAnswer == correct;

    setState(() {
      _isChecked = true;
      _isCorrect = isCorrect;
      _showExplanation = true; // Show explanation immediately on check
    });

    widget.onCheckResult?.call(isCorrect);
  }

  void _retry() {
    setState(() {
      _selectedAnswer = null;
      _isChecked = false;
      _isCorrect = false;
      _isRevealed = false;
      _showExplanation = false;
    });
    widget.onAnswerChanged?.call(null);
  }

  void _revealAnswer() {
    setState(() {
      _isRevealed = true;
      _isChecked = true; // Treat as checked so options lock
      _showExplanation = true;
    });
  }

  // Opens the AI Chat Side Panel
  void _askAi() {
    // Get premium status
    // Use read/watch. Using watch inside a callback is generally okay in latest Riverpod if just reading once,
    // but ref.read is safer for callbacks to avoid widget rebuilds if provider changes (though isPremium is stable).
    // Using ref.read as it's an event handler.
    final isPremium = ref.read(isPremiumProvider);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'AI Chat',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent, // Let panel handle bg
            child: SizedBox(
              width: MediaQuery.of(context).size.width > 600 ? 450 : MediaQuery.of(context).size.width * 0.90,
              height: double.infinity,
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                child: AIChatPanel(
                  questionId: widget.question.id,
                  isPremium: isPremium,
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
         final curvedAnimation = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
         return SlideTransition(
           position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curvedAnimation),
           child: child,
         );
      },
    );
  }

  // Placeholder for "Add Note"
  void _addNote() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Note feature coming soon to feed card!')),
    );
  }

  String _getPreviousAttemptText() {
    if (widget.latestAttempt == null) return '';
    final score = widget.latestAttempt!['score'];
    final isCorrect = widget.latestAttempt!['is_correct'] ?? false;

    if (isCorrect) return 'Solved';
    return '$score%';
  }

  @override
  Widget build(BuildContext context) {
    // Determine status color for border/glow
    final statusColor = QuestionStatusHelper.getStatusColor(widget.latestAttempt);
    // If checked inline, use green/red based on _isCorrect
    final effectiveStatusColor = _isChecked
        ? (_isCorrect ? Colors.green : Colors.red)
        : (widget.latestAttempt != null ? statusColor : AppColors.border.withValues(alpha: 0.5));

    final hasAttempt = widget.latestAttempt != null || _isChecked;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasAttempt ? effectiveStatusColor.withValues(alpha: 0.5) : AppColors.border.withValues(alpha: 0.5),
          width: hasAttempt ? 2 : 1,
        ),
        boxShadow: hasAttempt ? [
          BoxShadow(
            color: effectiveStatusColor.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ] : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TOP ROW: Question Number + Question Text
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question Number Box
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${widget.question.questionNumber}',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Question Text (Formatted)
                    Expanded(
                      child: FormattedQuestionText(
                        content: widget.question.content,
                        fontSize: 16,
                        textColor: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // OPTIONS
                if (widget.question.hasOptions) ...[
                  ...widget.question.options!.map((option) {
                    final label = option['label'] ?? '';
                    final text = option['text'] ?? '';
                    final isSelected = _selectedAnswer == label;
                    final isCorrectOption = label == widget.question.effectiveCorrectAnswer;

                    // Logic for display state
                    bool showAsCorrect = false;
                    bool showAsWrong = false;

                    if (_isRevealed) {
                        // If revealed, show the correct answer as Green
                        if (isCorrectOption) showAsCorrect = true;
                        // If user selected this but it's wrong
                        if (isSelected && !isCorrectOption) showAsWrong = true;
                    } else if (_isChecked) {
                        // Normal check logic
                        if (isCorrectOption) showAsCorrect = true;
                        if (isSelected && !isCorrectOption) showAsWrong = true;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => _selectAnswer(label),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: showAsCorrect
                                ? Colors.green.withValues(alpha: 0.2)
                                : showAsWrong
                                    ? Colors.red.withValues(alpha: 0.2)
                                    : isSelected
                                        ? AppColors.primary.withValues(alpha: 0.15)
                                        : AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: showAsCorrect
                                  ? Colors.green
                                  : showAsWrong
                                      ? Colors.red
                                      : isSelected
                                          ? AppColors.primary
                                          : AppColors.border.withValues(alpha: 0.5),
                              width: showAsCorrect || showAsWrong || isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Option label circle
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: showAsCorrect
                                      ? Colors.green
                                      : showAsWrong
                                          ? Colors.red
                                          : isSelected
                                              ? AppColors.primary
                                              : AppColors.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected || showAsCorrect || showAsWrong
                                        ? Colors.transparent
                                        : AppColors.border,
                                  ),
                                ),
                                child: Center(
                                  child: showAsCorrect
                                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                                      : showAsWrong
                                          ? const Icon(Icons.close, color: Colors.white, size: 18)
                                          : Text(
                                              label,
                                              style: TextStyle(
                                                color: isSelected ? Colors.white : AppColors.textSecondary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              // Option text
                              Expanded(
                                child: Text(
                                  text,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    height: 1.4,
                                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],

                // Action Buttons (Retry, Check, Reveal)
                const SizedBox(height: 12),
                if (!_isChecked && !_isRevealed) ...[
                  // Initial State: Check Answer Button
                   SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedAnswer != null ? _checkAnswer : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                      ),
                      child: const Text(
                        'Check Answer',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ] else ...[
                   // Checked/Revealed State: Retry + (Reveal if wrong)
                   Row(
                     children: [
                       Expanded(
                         child: ElevatedButton.icon(
                            onPressed: _retry,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              foregroundColor: AppColors.textPrimary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                               shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: AppColors.border),
                              ),
                            ),
                         ),
                       ),
                       // If checked but wrong (and NOT revealed yet), show Reveal Button
                       if (!_isRevealed && _isChecked && !_isCorrect) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _revealAnswer,
                              icon: const Icon(Icons.visibility_outlined, size: 18),
                              label: const Text('Reveal Answer'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue, // Blue for reveal
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                       ],
                     ],
                   ),
                ],

                // AI Explanation toggle
                if ((_isChecked || _isRevealed) && widget.question.hasAiSolution) ...[
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _showExplanation = !_showExplanation;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'AI Explanation',
                            style: TextStyle(
                              color: Colors.amber[700] ?? Colors.amber,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            _showExplanation ? Icons.expand_less : Icons.expand_more,
                            color: Colors.amber[700] ?? Colors.amber,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Expanded AI explanation
                if (_showExplanation && widget.question.hasAiSolution) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                    ),
                    child: MarkdownBody(
                      data: widget.question.aiSolution,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: AppColors.textPrimary.withValues(alpha: 0.9),
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 16),

                // FOOTER: Metadata
                Row(
                  children: [
                    // Type indicator
                    Icon(
                      Icons.radio_button_checked,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Multiple Choice',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    // Divider
                    const SizedBox(width: 12),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Paper info
                    if (widget.paperName != null) ...[
                      Text(
                        widget.paperName!,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],

                    // Marks
                    if (widget.question.marks != null) ...[
                      const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.question.marks} marks',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],

                    const Spacer(),

                    // Attempt Status Text (Footer version)
                    if (hasAttempt)
                      Text(
                            _getPreviousAttemptText(),
                            style: TextStyle(
                              color: effectiveStatusColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ],
                ),

                // Topic Tags
                if (widget.question.topicIds.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  TopicTags(topicIds: widget.question.topicIds),
                ],
              ],
            ),
          ),

          // BOTTOM ACTION BAR (Attached to card, grey bg)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.5), // Slightly darker/different bg
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Ask AI
                InkWell(
                  onTap: _askAi,
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        'Ask AI',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // Bookmark (Reusable Widget handles state)
                BookmarkButton(
                  questionId: widget.question.id,
                  // We can pass a simplified builder or custom child if needed, but default is icon
                ),

                // Add Note
                InkWell(
                  onTap: _addNote,
                  child: Row(
                    children: [
                      Icon(Icons.edit_note, size: 20, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        'Add Note',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
