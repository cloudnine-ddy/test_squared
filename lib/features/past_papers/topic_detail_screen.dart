import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'data/past_paper_repository.dart';
import 'models/question_model.dart';
import 'widgets/question_card.dart';
import 'widgets/skeleton_card.dart';
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

class _TopicDetailScreenState extends State<TopicDetailScreen> {
  List<QuestionModel> _allQuestions = [];
  List<QuestionModel> _filteredQuestions = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _marksFilter = 'all'; // all, 1-2, 3-4, 5+
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    final questions = await PastPaperRepository().getQuestionsByTopic(widget.topicId);
    if (mounted) {
      setState(() {
        _allQuestions = questions;
        _filteredQuestions = questions;
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredQuestions = _allQuestions.where((q) {
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
    });
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
        title: Text(
          'Topic Questions',
          style: const TextStyle(color: Colors.white),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: _buildSearchBar(),
        ),
      ),
      body: Column(
        children: [
          // Marks filter chips
          _buildMarksFilter(),
          
          // Questions list
          Expanded(
            child: _buildQuestionsList(),
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
                    _searchQuery = '';
                    _applyFilters();
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
          _searchQuery = value;
          _applyFilters();
        },
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
        _applyFilters();
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

  Widget _buildQuestionsList() {
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

    if (_filteredQuestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            Text(
              'No questions match your filters',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _marksFilter = 'all';
                });
                _applyFilters();
              },
              child: const Text('Clear filters'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredQuestions.length,
      itemBuilder: (context, index) {
        return QuestionCard(question: _filteredQuestions[index]);
      },
    );
  }
}
