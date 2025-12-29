import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/past_paper_repository.dart';
import 'models/question_model.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/question_image_header.dart';
import 'widgets/question_action_bar.dart';
import 'widgets/answer_reveal_sheet.dart';
import 'widgets/formatted_question_text.dart';

/// Full-page question detail view with figure and answer reveals
class QuestionDetailScreen extends StatefulWidget {
  final String questionId;

  const QuestionDetailScreen({
    super.key,
    required this.questionId,
  });

  @override
  State<QuestionDetailScreen> createState() => _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends State<QuestionDetailScreen> {
  QuestionModel? _question;
  bool _isLoading = true;
  bool _showAiSolution = false;
  final TextEditingController _studentAnswerController = TextEditingController();
  bool _answerSubmitted = false;
  bool _isCheckingAnswer = false;
  
  // AI Feedback
  Map<String, dynamic>? _aiFeedback;

  @override
  void initState() {
    super.initState();
    _loadQuestion();
  }

  @override
  void dispose() {
    _studentAnswerController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestion() async {
    final question = await PastPaperRepository().getQuestionById(widget.questionId);
    if (mounted) {
      setState(() {
        _question = question;
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAnswer() async {
    if (_question == null || _studentAnswerController.text.trim().isEmpty) return;
    
    setState(() {
      _isCheckingAnswer = true;
    });
    
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'check-answer',
        body: {
          'questionId': _question!.id,
          'questionContent': _question!.content,
          'officialAnswer': _question!.officialAnswer,
          'studentAnswer': _studentAnswerController.text.trim(),
          'marks': _question!.marks,
        },
      );
      
      if (response.status == 200 && response.data != null) {
        setState(() {
          _aiFeedback = response.data as Map<String, dynamic>;
          _answerSubmitted = true;
          _isCheckingAnswer = false;
        });
      } else {
        throw Exception(response.data?['error'] ?? 'Unknown error');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingAnswer = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking answer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAnswerSheet() {
    if (_question == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AnswerRevealSheet(
        officialAnswer: _question!.officialAnswer,
        aiSolution: _question!.aiSolution,
        hasOfficialAnswer: _question!.hasOfficialAnswer,
        hasAiSolution: _question!.hasAiSolution,
      ),
    );
  }

  Future<void> _showAiExplainDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.psychology, color: Colors.cyan),
            const SizedBox(width: 12),
            const Text('AI Explanation', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This feature will use AI to provide additional explanation for the question context and concepts.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.cyan, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This specific feature is coming soon!',
                        style: TextStyle(color: Colors.cyan.shade200, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _toggleAiSolution() {
    setState(() {
      _showAiSolution = !_showAiSolution;
    });
    // If opening AI, maybe scroll to bottom? (Optional, better to let user scroll)
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0E14),
        body: Center(child: CircularProgressIndicator(color: Colors.blue)),
      );
    }

    // ... Error handling remains the same ...
    if (_question == null) {
        return const Scaffold(body: Center(child: Text('Error')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFF0B0E14),
            expandedHeight: _question!.hasFigure ? 300 : 0,
            floating: false,
            pinned: true,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () {
                 if (GoRouter.of(context).canPop()) {
                    GoRouter.of(context).pop();
                } else {
                    GoRouter.of(context).go('/dashboard');
                }
              },
            ),
            actions: [
               if (_question?.marks != null)
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${_question!.marks} marks',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            flexibleSpace: _question!.hasFigure
                ? QuestionImageHeader(
                    imageUrl: _question!.imageUrl!,
                    heroTag: 'figure_${_question!.id}',
                  )
                : null,
          ),

          // Question Content
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            sliver: SliverToBoxAdapter(
              child: FormattedQuestionText(
                content: _question!.content,
                fontSize: 18,
              ),
            ),
          ),

          // Student Answer Section
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            sliver: SliverToBoxAdapter(
              child: _buildStudentAnswerSection(),
            ),
          ),

          // AI Solution Card (Animated Reveal)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100), // Bottom padding
            sliver: SliverToBoxAdapter(
              child: AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: _buildAiSolutionCard(),
                crossFadeState: _showAiSolution
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
                sizeCurve: Curves.easeInOut,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: QuestionActionBar(
        onToggleOfficialAnswer: _showAnswerSheet, // Reusing existing method name for simplicity, though it shows bottom sheet
        onToggleAiExplanation: _toggleAiSolution,
        hasAiSolution: _question!.hasAiSolution,
        isAiSolutionVisible: _showAiSolution,
      ),
    );
  }

  Widget _buildStudentAnswerSection() {
    final isCorrect = _aiFeedback?['isCorrect'] ?? false;
    final score = _aiFeedback?['score'] ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151821),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _answerSubmitted 
              ? (isCorrect ? Colors.green.withValues(alpha: 0.5) : Colors.orange.withValues(alpha: 0.5))
              : Colors.blue.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with score if submitted
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _answerSubmitted 
                      ? (isCorrect ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2))
                      : Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _answerSubmitted 
                      ? (isCorrect ? Icons.check_circle : Icons.info_outline)
                      : Icons.edit_note,
                  color: _answerSubmitted 
                      ? (isCorrect ? Colors.green : Colors.orange)
                      : Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _answerSubmitted ? 'Your Answer' : 'Your Answer',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (_answerSubmitted && _aiFeedback != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCorrect ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$score%',
                    style: TextStyle(
                      color: isCorrect ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Text Input
          TextField(
            controller: _studentAnswerController,
            maxLines: 6,
            enabled: !_answerSubmitted && !_isCheckingAnswer,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Type your answer here...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              filled: true,
              fillColor: const Color(0xFF0B0E14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blue),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Check Answer Button
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_answerSubmitted || _isCheckingAnswer)
                      ? null 
                      : () {
                          if (_studentAnswerController.text.trim().isNotEmpty) {
                            _checkAnswer();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter an answer first'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                  icon: _isCheckingAnswer 
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(_answerSubmitted ? Icons.check : Icons.send),
                  label: Text(_isCheckingAnswer 
                      ? 'Checking...' 
                      : (_answerSubmitted ? 'Checked' : 'Check Answer')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _answerSubmitted 
                        ? (isCorrect ? Colors.green.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3))
                        : Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (_answerSubmitted) ...[
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _answerSubmitted = false;
                      _aiFeedback = null;
                    });
                  },
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                  tooltip: 'Try Again',
                ),
              ],
            ],
          ),
          
          // AI Feedback Section
          if (_answerSubmitted && _aiFeedback != null) ...[
            const SizedBox(height: 20),
            const Divider(color: Colors.white24),
            const SizedBox(height: 16),
            
            // Feedback text
            Text(
              _aiFeedback!['feedback'] ?? '',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            
            // Strengths
            if ((_aiFeedback!['strengths'] as List?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 16),
              _buildFeedbackList(
                'What you did well:',
                (_aiFeedback!['strengths'] as List).cast<String>(),
                Colors.green,
                Icons.thumb_up,
              ),
            ],
            
            // Hints (if not fully correct)
            if ((_aiFeedback!['hints'] as List?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              _buildFeedbackList(
                'Hints:',
                (_aiFeedback!['hints'] as List).cast<String>(),
                Colors.amber,
                Icons.lightbulb_outline,
              ),
            ],
            
            // Improvements
            if ((_aiFeedback!['improvements'] as List?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              _buildFeedbackList(
                'To improve:',
                (_aiFeedback!['improvements'] as List).cast<String>(),
                Colors.cyan,
                Icons.trending_up,
              ),
            ],
          ],
        ],
      ),
    );
  }
  
  Widget _buildFeedbackList(String title, List<String> items, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(left: 22, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• ', style: TextStyle(color: color)),
              Expanded(
                child: Text(
                  item,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
  Widget _buildAiSolutionCard() {
    if (_question == null || !_question!.hasAiSolution) return const SizedBox.shrink();

    // Split text by double newline to form paragraphs
    final parts = _question!.aiSolution.split(RegExp(r'\n\n+'));

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E), // Subtle purple/blue tint
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.indigoAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Header
            Row(
              children: [
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.indigoAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.indigoAccent, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                    'AI Step-by-Step',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                    ),
                ),
            ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),

            // Step content
            ...parts.map((part) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SelectableText(
                    part.trim(),
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.6,
                        fontFamily: 'Roboto',
                    ),
                ),
            )),
        ],
      ),
    );
  }
}
