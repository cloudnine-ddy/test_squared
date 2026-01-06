import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/past_paper_repository.dart';
import 'models/question_model.dart';
import 'widgets/question_card.dart';
import 'widgets/skeleton_card.dart';
import 'widgets/multiple_choice_feed_card.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../progress/data/progress_repository.dart';

/// Topic detail screen with dark theme, search, and marks filter
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
  List<QuestionModel> _allQuestions = [];
  Map<String, Map<String, dynamic>> _attemptsByQuestionId = {}; // questionId -> attempt data
  bool _isLoading = true;
  String _searchQuery = '';
  String _marksFilter = 'all'; // all, 1-2, 3-4, 5+
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
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).scaffoldBackgroundColor
          : AppColors.background,
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).appBarTheme.backgroundColor
            : AppColors.sidebar,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
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
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.onSurface
                : AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Modern filter bar with search and tabs
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
        color: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).cardTheme.color
            : AppColors.sidebar,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).dividerColor
                : Colors.white.withValues(alpha: 0.1),
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
                // Search Field
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.onSurface
                          : AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search questions...',
                      hintStyle: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                            : AppColors.textPrimary.withValues(alpha: 0.5),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.7),
                        size: 20
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white54, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).scaffoldBackgroundColor
                          : AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).dividerColor
                              : AppColors.border,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context).dividerColor
                              : AppColors.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue, width: 2),
                      ),
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
                const SizedBox(width: 12),
                // Marks Filter Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).cardTheme.color
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).dividerColor
                          : AppColors.border,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _marksFilter,
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(context).colorScheme.onSurface
                            : AppColors.textPrimary,
                        size: 20
                      ),
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(context).colorScheme.onSurface
                            : AppColors.textPrimary,
                        fontSize: 14
                      ),
                      dropdownColor: Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).cardTheme.color
                          : AppColors.surface,
                      isDense: true,
                      items: [
                        DropdownMenuItem(value: 'all', child: Row(
                          children: [
                            Icon(Icons.filter_alt, size: 16, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('All Marks'),
                          ],
                        )),
                        DropdownMenuItem(value: '1-2', child: Text('1-2 marks')),
                        DropdownMenuItem(value: '3-4', child: Text('3-4 marks')),
                        DropdownMenuItem(value: '5+', child: Text('5+ marks')),
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
          // Modern Tab Selector
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).cardTheme.color
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(4),
              labelColor: Colors.white,
              unselectedLabelColor: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)
                  : AppColors.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
              dividerColor: Colors.transparent,
              onTap: (_) => setState(() {}),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit_document, size: 18),
                      SizedBox(width: 8),
                      Text('Structured'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.quiz, size: 18),
                      SizedBox(width: 8),
                      Text('MCQ'),
                    ],
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
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.quiz_outlined, color: AppColors.primary, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              'No questions found for this topic',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
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
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                type == 'mcq' ? Icons.quiz_outlined : Icons.edit_document,
                color: AppColors.primary,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No $typeName questions found',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
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
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Clear filters'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
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
