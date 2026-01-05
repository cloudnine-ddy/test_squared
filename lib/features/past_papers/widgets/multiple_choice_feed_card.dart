import 'package:flutter/material.dart';
import '../models/question_model.dart';
import 'formatted_question_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import 'topic_tags.dart';

/// A card for MCQ questions in a continuous feed with inline answer checking
class MultipleChoiceFeedCard extends StatefulWidget {
  final QuestionModel question;
  final String? paperName; // Optional paper source info

  const MultipleChoiceFeedCard({
    super.key,
    required this.question,
    this.paperName,
  });

  @override
  State<MultipleChoiceFeedCard> createState() => _MultipleChoiceFeedCardState();
}

class _MultipleChoiceFeedCardState extends State<MultipleChoiceFeedCard> {
  String? _selectedAnswer;
  bool _isChecked = false;
  bool _showExplanation = false;

  void _selectAnswer(String label) {
    if (!_isChecked) {
      setState(() {
        _selectedAnswer = label;
      });
    }
  }

  void _checkAnswer() {
    setState(() {
      _isChecked = true;
    });
  }

  bool get _isCorrect {
    if (!_isChecked || _selectedAnswer == null) return false;
    return _selectedAnswer == widget.question.effectiveCorrectAnswer;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      color: AppColors.sidebar,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Question number + marks
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Q${widget.question.questionNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Paper source badge
                if (widget.paperName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E1A47), // Dark purple
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      widget.paperName!,
                      style: const TextStyle(
                        color: Colors.purpleAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (widget.question.marks != null)
                  const SizedBox(width: 12),
                if (widget.question.marks != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.question.marks}',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                // Result badge
                if (_isChecked)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (_isCorrect ? Colors.green : Colors.red).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isCorrect ? Icons.check_circle : Icons.cancel,
                          color: _isCorrect ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isCorrect ? 'Correct' : 'Incorrect',
                          style: TextStyle(
                            color: _isCorrect ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 16),

            // Question text
            FormattedQuestionText(
              content: widget.question.content,
              fontSize: 15,
            ),

            // Topic tags
            if (widget.question.topicIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              TopicTags(topicIds: widget.question.topicIds),
            ],

            const SizedBox(height: 20),

            // Options
            if (widget.question.hasOptions) ...[
              ...widget.question.options!.map((option) {
                final label = option['label'] ?? '';
                final text = option['text'] ?? '';
                final isSelected = _selectedAnswer == label;
                final isCorrectOption = label == widget.question.effectiveCorrectAnswer;
                final showAsCorrect = _isChecked && isCorrectOption;
                final showAsWrong = _isChecked && isSelected && !isCorrectOption;

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
                                    ? Colors.blue.withValues(alpha: 0.2)
                                    : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: showAsCorrect
                              ? Colors.green
                              : showAsWrong
                                  ? Colors.red
                                  : isSelected
                                      ? Colors.blue
                                      : Colors.white.withValues(alpha: 0.2),
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
                                          ? Colors.blue
                                          : Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: showAsCorrect
                                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                                  : showAsWrong
                                      ? const Icon(Icons.close, color: Colors.white, size: 18)
                                      : Text(
                                          label,
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : Colors.white70,
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
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                                height: 1.4,
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

            // Check answer button
            if (_selectedAnswer != null && !_isChecked) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _checkAnswer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Check Answer',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ),
            ],

            // AI Explanation toggle
            if (_isChecked && widget.question.hasAiSolution) ...[
              const SizedBox(height: 16),
              InkWell(
                onTap: () {
                  setState(() {
                    _showExplanation = !_showExplanation;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.purple, size: 18),
                      const SizedBox(width: 10),
                      const Text(
                        'AI Explanation',
                        style: TextStyle(
                          color: Colors.purple,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        _showExplanation ? Icons.expand_less : Icons.expand_more,
                        color: Colors.purple,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Expanded AI explanation
            if (_showExplanation && widget.question.hasAiSolution) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
                ),
                child: SelectableText(
                  widget.question.aiSolution,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
