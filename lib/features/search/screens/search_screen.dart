import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/analytics_service.dart';
import '../search_repository.dart';
import '../../past_papers/models/question_model.dart';
import '../../past_papers/data/past_paper_repository.dart';
import '../../past_papers/models/subject_model.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchRepo = SearchRepository();
  final _paperRepo = PastPaperRepository();
  final _searchController = TextEditingController();
  
  List<QuestionModel> _results = [];
  List<SubjectModel> _subjects = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  
  // Filters
  String? _selectedSubjectId;
  String? _selectedType; // 'mcq' or 'structured'
  
  // Debouncing
  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSubjects() async {
    try {
      final subjects = await _paperRepo.getSubjects();
      if (mounted) {
        setState(() => _subjects = subjects);
      }
    } catch (e) {
      // Silently fail
    }
  }

  void _onSearchChanged(String query) {
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    // If query is empty, clear results
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }
    
    // Start new timer
    _debounceTimer = Timer(_debounceDuration, () {
      _performSearch();
    });
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final results = await _searchRepo.searchQuestions(
        query: query,
        subjectId: _selectedSubjectId,
        questionType: _selectedType,
      );

      AnalyticsService().trackSearch(query, results.length);

      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedSubjectId = null;
      _selectedType = null;
    });
    if (_hasSearched) {
      _performSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Search Questions'),
        backgroundColor: AppColors.sidebar,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.sidebar,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search questions...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                    prefixIcon: _isLoading
                        ? Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          )
                        : const Icon(Icons.search, color: Colors.white54),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white54),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _results = [];
                                _hasSearched = false;
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) {
                    setState(() {}); // Update UI for clear button
                    _onSearchChanged(value); // Trigger debounced search
                  },
                ),
                const SizedBox(height: 12),
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Subject Filter
                      PopupMenuButton<String>(
                        child: Chip(
                          label: Text(
                            _selectedSubjectId != null
                                ? _subjects.firstWhere((s) => s.id == _selectedSubjectId).name
                                : 'All Subjects',
                          ),
                          deleteIcon: _selectedSubjectId != null ? const Icon(Icons.close, size: 18) : null,
                          onDeleted: _selectedSubjectId != null
                              ? () => setState(() => _selectedSubjectId = null)
                              : null,
                        ),
                        itemBuilder: (context) => _subjects.map((subject) {
                          return PopupMenuItem(
                            value: subject.id,
                            child: Text(subject.name),
                          );
                        }).toList(),
                        onSelected: (subjectId) {
                          setState(() => _selectedSubjectId = subjectId);
                          if (_hasSearched) _performSearch();
                        },
                      ),
                      const SizedBox(width: 8),
                      // Type Filter
                      FilterChip(
                        label: const Text('MCQ'),
                        selected: _selectedType == 'mcq',
                        onSelected: (selected) {
                          setState(() => _selectedType = selected ? 'mcq' : null);
                          if (_hasSearched) _performSearch();
                        },
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Structured'),
                        selected: _selectedType == 'structured',
                        onSelected: (selected) {
                          setState(() => _selectedType = selected ? 'structured' : null);
                          if (_hasSearched) _performSearch();
                        },
                      ),
                      const SizedBox(width: 8),
                      if (_selectedSubjectId != null || _selectedType != null)
                        TextButton.icon(
                          icon: const Icon(Icons.clear_all, size: 18),
                          label: const Text('Clear'),
                          onPressed: _clearFilters,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Results
          Expanded(
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Search for questions',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords or filters',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final question = _results[index];
        return _buildQuestionCard(question);
      },
    );
  }

  Widget _buildQuestionCard(QuestionModel question) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: InkWell(
        onTap: () => context.push('/question/${question.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Q${question.questionNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (question.isMCQ)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'MCQ',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                question.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (question.hasPaperInfo) ...[
                const SizedBox(height: 8),
                Text(
                  question.paperLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
