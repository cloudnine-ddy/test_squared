import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'data/past_paper_repository.dart';
import 'models/question_model.dart';
import 'widgets/question_card.dart';
import 'widgets/multiple_choice_feed_card.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';

/// Screen showing all questions from a specific paper
class PaperDetailScreen extends StatefulWidget {
  final String paperId;

  const PaperDetailScreen({
    super.key,
    required this.paperId,
  });

  @override
  State<PaperDetailScreen> createState() => _PaperDetailScreenState();
}

class _PaperDetailScreenState extends State<PaperDetailScreen> {
  List<QuestionModel> _questions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final questions = await PastPaperRepository().getQuestionsByPaper(widget.paperId);
    if (mounted) {
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String paperTitle = 'Past Paper';
    if (_questions.isNotEmpty && _questions.first.hasPaperInfo) {
      final q = _questions.first;
      paperTitle = '${q.paperYear} ${q.paperSeason}';
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.sidebar,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              GoRouter.of(context).pop();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          paperTitle,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility, color: AppColors.textSecondary),
            tooltip: 'Debug Bounding Boxes',
            onPressed: () {
              GoRouter.of(context).push('/paper/${widget.paperId}/debug');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : _questions.isEmpty
              ? _buildEmptyState()
              : _buildQuestionsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.quiz_outlined, color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          Text(
            'No questions found in this paper',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsList() {
    // Construct paper name from first question's metadata
    String? paperName;
    if (_questions.isNotEmpty && _questions.first.hasPaperInfo) {
      final q = _questions.first;
      paperName = '${q.paperYear} ${q.paperSeason}';
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _questions.length,
      itemBuilder: (context, index) {
        final question = _questions[index];

        // Use MCQ feed card for objective questions, regular card for structured
        if (question.isMCQ) {
          return MultipleChoiceFeedCard(
            question: question,
            paperName: paperName,
          );
        } else {
          return QuestionCard(question: question);
        }
      },
    );
  }
}
