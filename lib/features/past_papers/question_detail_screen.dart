import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

  @override
  void initState() {
    super.initState();
    _loadQuestion();
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
