import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'data/past_paper_repository.dart';
import 'models/question_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/question_card.dart';
import 'widgets/multiple_choice_feed_card.dart';
import '../../core/theme/app_colors.dart';
import '../progress/data/progress_repository.dart';
import '../../shared/wired/wired_widgets.dart';

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
  Map<String, Map<String, dynamic>> _attemptsByQuestionId = {};
  final _progressRepo = ProgressRepository();
  bool _isLoading = true;

  // Sketchy Theme Colors
  static const Color _primaryColor = Color(0xFF2D3E50); // Deep Navy
  static const Color _backgroundColor = Color(0xFFFDFBF7); // Cream beige

  // Patrick Hand text style helper
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
      color: color ?? _primaryColor,
      height: height,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;

      if (userId != null) {
        // Load with attempts
        final questionsWithData = await _progressRepo.getQuestionsWithAttempts(
          userId: userId,
          paperId: widget.paperId,
        );

        // Sort by question number
        questionsWithData.sort((a, b) {
          final numA = a['question_number'] as int? ?? 0;
          final numB = b['question_number'] as int? ?? 0;
          return numA.compareTo(numB);
        });

        final questions = questionsWithData
            .map((data) => QuestionModel.fromMap(data))
            .toList();

        final attemptsMap = <String, Map<String, dynamic>>{};
        for (var data in questionsWithData) {
          if (data['latest_attempt'] != null) {
            attemptsMap[data['id']] = data['latest_attempt'];
          }
        }

        if (mounted) {
          setState(() {
            _questions = questions;
            _attemptsByQuestionId = attemptsMap;
            _isLoading = false;
          });
        }
      } else {
        // Fetch without attempts (existing logic)
        final questions = await PastPaperRepository().getQuestionsByPaper(widget.paperId);
        if (mounted) {
          setState(() {
            _questions = questions;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading paper questions: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        elevation: 0,
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
          style: _patrickHand(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility_outlined, color: Colors.white70),
            tooltip: 'Debug Bounding Boxes',
            onPressed: () {
              GoRouter.of(context).push('/paper/${widget.paperId}/debug');
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'Loading questions...',
                    style: _patrickHand(
                      fontSize: 16,
                      color: _primaryColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            )
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
          CustomPaint(
            painter: WiredBorderPainter(
              color: _primaryColor.withValues(alpha: 0.2),
              strokeWidth: 1.5,
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Icon(
                Icons.quiz_outlined,
                color: _primaryColor.withValues(alpha: 0.5),
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No questions found in this paper',
            style: _patrickHand(
              fontSize: 18,
              color: _primaryColor.withValues(alpha: 0.6),
            ),
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
        final latestAttempt = _attemptsByQuestionId[question.id];

        // Use MCQ feed card for objective questions, regular card for structured
        if (question.isMCQ) {
          return MultipleChoiceFeedCard(
            question: question,
            paperName: paperName,
            latestAttempt: latestAttempt,
          );
        } else {
          return QuestionCard(
            question: question,
            latestAttempt: latestAttempt,
            onReturn: _loadQuestions, // Refresh when returning
          );
        }
      },
    );
  }
}
