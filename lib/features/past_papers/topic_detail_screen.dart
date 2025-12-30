import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'data/past_paper_repository.dart';
import 'models/question_model.dart';
import 'widgets/question_card.dart';
import 'widgets/skeleton_card.dart';
import 'widgets/multiple_choice_feed_card.dart';
import '../../core/theme/app_theme.dart';

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
  bool _isLoading = true;
  String _searchQuery = '';
  String _marksFilter = 'all'; // all, 1-2, 3-4, 5+
  final _searchController = TextEditingController();
  late TabController _tabController;

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
    final questions = await PastPaperRepository().getQuestionsByTopic(widget.topicId);
    if (mounted) {
      setState(() {
        _allQuestions = questions;
        _isLoading = false;
      });
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
      backgroundColor: AppTheme.backgroundDeepest,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
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
        title: const Text(
          'Topic Questions',
          style: TextStyle(color: Colors.white),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              _buildSearchBar(),
              _buildTabBar(),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Marks filter chips
          _buildMarksFilter(),

          // TabBarView with questions lists
          Expanded(
            child: _buildTabBarView(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search questions...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.5)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white54),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.blue,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
        onTap: (_) => setState(() {}), // Rebuild to update counts
        tabs: [
          Tab(
            icon: const Icon(Icons.edit_document, size: 20),
            text: 'Structured',
          ),
          Tab(
            icon: const Icon(Icons.quiz, size: 20),
            text: 'Multiple Choice',
          ),
        ],
      ),
    );
  }

  Widget _buildMarksFilter() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('All', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('1-2 marks', '1-2'),
          const SizedBox(width: 8),
          _buildFilterChip('3-4 marks', '3-4'),
          const SizedBox(width: 8),
          _buildFilterChip('5+ marks', '5+'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _marksFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _marksFilter = value;
        });
      },
      backgroundColor: AppTheme.surfaceDark,
      selectedColor: Colors.blue.withValues(alpha: 0.3),
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? Colors.blue : Colors.white24,
      ),
      checkmarkColor: Colors.blue,
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
            Icon(Icons.quiz_outlined, color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            Text(
              'No questions found for this topic',
              style: TextStyle(color: Colors.white54, fontSize: 16),
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
            Icon(
              type == 'mcq' ? Icons.quiz_outlined : Icons.edit_document,
              color: Colors.white24,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'No $typeName questions found',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            if (_searchQuery.isNotEmpty || _marksFilter != 'all') ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _marksFilter = 'all';
                  });
                },
                child: const Text('Clear filters'),
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

        // Use different card types based on question type
        if (type == 'mcq') {
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
