import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/past_paper_repository.dart';
import 'models/question_model.dart';
import 'widgets/question_card.dart';
import 'widgets/skeleton_card.dart';
import 'widgets/multiple_choice_feed_card.dart';
import '../../shared/wired/wired_widgets.dart';
import '../progress/data/progress_repository.dart';

/// Topic detail screen with sketchy hand-drawn aesthetic
class TopicDetailScreen extends StatefulWidget {
  final String topicId;

  const TopicDetailScreen({
    super.key,
    required this.topicId,
  });

  @override
  State<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<TopicDetailScreen> with SingleTickerProviderStateMixin {
  // Sketchy Theme Colors
  static const Color _primaryColor = Color(0xFF2D3E50); // Deep Navy
  static const Color _backgroundColor = Color(0xFFFDFBF7); // Cream beige

  TextStyle _patrickHand({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: 'PatrickHand',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? _primaryColor,
    );
  }

  List<QuestionModel> _allQuestions = [];
  Map<String, Map<String, dynamic>> _attemptsByQuestionId = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String _marksFilter = 'all';
  final _searchController = TextEditingController();
  late TabController _tabController;
  final _progressRepo = ProgressRepository();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadQuestions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;

      // First, get all questions for this topic
      final questions = await PastPaperRepository().getQuestionsByTopic(widget.topicId);

      // Then, get attempt data if user is logged in
      Map<String, Map<String, dynamic>> attemptsMap = {};
      if (userId != null && questions.isNotEmpty) {
        final questionIds = questions.map((q) => q.id).toList();

        // Get questions with attempts for this topic
        final questionsWithAttempts = await _progressRepo.getQuestionsWithAttempts(
          userId: userId,
          topicIds: [widget.topicId],
        );

        // Build a map of questionId -> latest attempt
        for (var qData in questionsWithAttempts) {
          final qId = qData['id'] as String;
          final latestAttempt = qData['latest_attempt'] as Map<String, dynamic>?;
          if (latestAttempt != null) {
            attemptsMap[qId] = latestAttempt;
            final score = latestAttempt['score'];
            final isCorrect = latestAttempt['is_correct'];
            print('✅ Q[$qId]: score=$score, correct=$isCorrect');
          }
        }

        print('✨ Total attempts: ${attemptsMap.length}/${questions.length}');
      }

      if (mounted) {
        setState(() {
          _allQuestions = questions;
          _attemptsByQuestionId = attemptsMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading questions with attempts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<QuestionModel> _getFilteredQuestionsByType(String type) {
    return _allQuestions.where((q) {
      // Type filter
      bool typeMatch = false;
      if (type == 'structured') {
        typeMatch = q.type == 'structured' || !q.isMCQ;
      } else if (type == 'mcq') {
        typeMatch = q.type == 'mcq' || q.isMCQ;
      }

      if (!typeMatch) return false;

      // Search filter
      if (_searchQuery.isNotEmpty) {
        if (!q.content.toLowerCase().contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }

      // Marks filter
      if (_marksFilter != 'all' && q.marks != null) {
        switch (_marksFilter) {
          case '1-2':
            if (q.marks! > 2) return false;
            break;
          case '3-4':
            if (q.marks! < 3 || q.marks! > 4) return false;
            break;
          case '5+':
            if (q.marks! < 5) return false;
            break;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _primaryColor),
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              GoRouter.of(context).pop();
            } else {
              GoRouter.of(context).go('/dashboard');
            }
          },
        ),
        title: Text(
          'Questions',
          style: _patrickHand(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: _primaryColor.withValues(alpha: 0.2),
            height: 1,
          ),
        ),
      ),
      body: Column(
        children: [
          // Sketchy filter bar with search and tabs
          _buildModernFilterBar(),

          // TabBarView with questions lists
          Expanded(
            child: _buildTabBarView(),
          ),
        ],
      ),
    );
  }

  Widget _buildModernFilterBar() {
    return Container(
      decoration: BoxDecoration(
        color: _backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: _primaryColor.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        children: [
          // Search and Marks Filter Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                // Search Field with WiredCard
                Expanded(
                  flex: 2,
                  child: WiredCard(
                    backgroundColor: Colors.white,
                    borderColor: _primaryColor.withValues(alpha: 0.3),
                    borderWidth: 1.5,
                    padding: const EdgeInsets.all(0),
                    child: TextField(
                      controller: _searchController,
                      style: _patrickHand(fontSize: 18),
                      decoration: InputDecoration(
                        hintText: 'Search questions...',
                        hintStyle: _patrickHand(
                          color: _primaryColor.withValues(alpha: 0.5),
                          fontSize: 18,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: _primaryColor.withValues(alpha: 0.6),
                          size: 20,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: _primaryColor.withValues(alpha: 0.4),
                                  size: 20,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Marks Filter Dropdown with WiredCard
                WiredCard(
                  backgroundColor: Colors.white,
                  borderColor: _primaryColor.withValues(alpha: 0.3),
                  borderWidth: 1.5,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _marksFilter,
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: _primaryColor,
                        size: 20,
                      ),
                      style: _patrickHand(fontSize: 16),
                      dropdownColor: Colors.white,
                      isDense: true,
                      items: [
                        DropdownMenuItem(value: 'all', child: Row(
                          children: [
                            Icon(Icons.filter_alt, size: 16, color: _primaryColor),
                            const SizedBox(width: 8),
                            Text('All Marks', style: _patrickHand(fontSize: 16)),
                          ],
                        )),
                        DropdownMenuItem(value: '1-2', child: Text('1-2 marks', style: _patrickHand(fontSize: 16))),
                        DropdownMenuItem(value: '3-4', child: Text('3-4 marks', style: _patrickHand(fontSize: 16))),
                        DropdownMenuItem(value: '5+', child: Text('5+ marks', style: _patrickHand(fontSize: 16))),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _marksFilter = value!;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Sketchy Tab Selector
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Structured Tab
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _tabController.animateTo(0);
                      setState(() {});
                    },
                    child: WiredCard(
                      backgroundColor: _tabController.index == 0
                          ? _primaryColor
                          : Colors.white,
                      borderColor: _primaryColor,
                      borderWidth: 1.5,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.edit_document,
                            size: 18,
                            color: _tabController.index == 0
                                ? Colors.white
                                : _primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Structured',
                            style: _patrickHand(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _tabController.index == 0
                                  ? Colors.white
                                  : _primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // MCQ Tab
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _tabController.animateTo(1);
                      setState(() {});
                    },
                    child: WiredCard(
                      backgroundColor: _tabController.index == 1
                          ? _primaryColor
                          : Colors.white,
                      borderColor: _primaryColor,
                      borderWidth: 1.5,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.quiz,
                            size: 18,
                            color: _tabController.index == 1
                                ? Colors.white
                                : _primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'MCQ',
                            style: _patrickHand(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _tabController.index == 1
                                  ? Colors.white
                                  : _primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }



  Widget _buildTabBarView() {
    if (_isLoading) {
      return const SkeletonList(itemCount: 5, itemHeight: 100);
    }

    if (_allQuestions.isEmpty) {
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
              'No questions found for this topic',
              style: _patrickHand(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _primaryColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildQuestionListForType('structured', 'Structured'),
        _buildQuestionListForType('mcq', 'Multiple Choice'),
      ],
    );
  }

  Widget _buildQuestionListForType(String type, String typeName) {
    final filteredQuestions = _getFilteredQuestionsByType(type);

    if (filteredQuestions.isEmpty) {
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
                  type == 'mcq' ? Icons.quiz_outlined : Icons.edit_document,
                  color: _primaryColor.withValues(alpha: 0.5),
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No $typeName questions found',
              style: _patrickHand(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _primaryColor.withValues(alpha: 0.7),
              ),
            ),
            if (_searchQuery.isNotEmpty || _marksFilter != 'all') ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _marksFilter = 'all';
                  });
                },
                icon: Icon(Icons.refresh, size: 18, color: _primaryColor),
                label: Text('Clear filters', style: _patrickHand(color: _primaryColor)),
                style: TextButton.styleFrom(
                  foregroundColor: _primaryColor,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredQuestions.length,
      itemBuilder: (context, index) {
        final question = filteredQuestions[index];

        // Construct paper name from question metadata
        String? paperName;
        if (question.hasPaperInfo) {
          paperName = '${question.paperYear} ${question.paperSeason}';
        }

        // Get attempt data for this question
        final latestAttempt = _attemptsByQuestionId[question.id];

        // Use different card types based on question type
        if (type == 'mcq') {
          return MultipleChoiceFeedCard(
            question: question,
            paperName: paperName,
            latestAttempt: latestAttempt,
            topicId: widget.topicId,
          );
        } else {
          return QuestionCard(
            question: question,
            latestAttempt: latestAttempt,
            topicId: widget.topicId,
            onReturn: _loadQuestions, // Refresh when returning from detail
          );
        }
      },
    );
  }
}
