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
import '../../../shared/wired/wired_widgets.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchRepo = SearchRepository();
  final _paperRepo = PastPaperRepository();
  final _searchController = TextEditingController();

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
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          'Search Questions',
          style: _patrickHand(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: _primaryColor,
        ),
      ),
      body: Column(
        children: [
          // Search Bar with light background
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: _backgroundColor,
            child: Column(
              children: [
                // Prominent search bar with sketchy style
                WiredCard(
                  backgroundColor: Colors.white,
                  borderColor: _primaryColor,
                  borderWidth: 1.5,
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search questions...',
                      hintStyle: _patrickHand(
                        color: _primaryColor.withValues(alpha: 0.5),
                        fontSize: 18,
                      ),
                      prefixIcon: _isLoading
                          ? Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _primaryColor,
                                  ),
                                ),
                              ),
                            )
                          : Icon(Icons.search, color: _primaryColor),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: _primaryColor),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _results = [];
                                  _hasSearched = false;
                                });
                              },
                            )
                          : null,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    style: _patrickHand(
                      color: _primaryColor,
                      fontSize: 18,
                    ),
                    onChanged: (value) {
                      setState(() {});
                      _onSearchChanged(value);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Filter Chips Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // All Subjects chip
                      _buildFilterChip(
                        'All Subjects',
                        _selectedSubjectId == null && _selectedType == null,
                        () {
                          setState(() {
                            _selectedSubjectId = null;
                            _selectedType = null;
                          });
                          if (_hasSearched) _performSearch();
                        },
                      ),
                      const SizedBox(width: 12),
                      // MCQ chip
                      _buildFilterChip(
                        'MCQ',
                        _selectedType == 'mcq',
                        () {
                          setState(() {
                            _selectedType = _selectedType == 'mcq' ? null : 'mcq';
                          });
                          if (_hasSearched) _performSearch();
                        },
                      ),
                      const SizedBox(width: 12),
                      // Structured chip
                      _buildFilterChip(
                        'Structured',
                        _selectedType == 'structured',
                        () {
                          setState(() {
                            _selectedType = _selectedType == 'structured' ? null : 'structured';
                          });
                          if (_hasSearched) _performSearch();
                        },
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

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: WiredCard(
        backgroundColor: isSelected ? _primaryColor : Colors.white,
        borderColor: _primaryColor,
        borderWidth: 1.5,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Text(
          label,
          style: _patrickHand(
            color: isSelected ? Colors.white : _primaryColor,
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Sketchy Empty State Illustration
            CustomPaint(
              painter: WiredBorderPainter(
                color: _primaryColor.withValues(alpha: 0.2),
                strokeWidth: 1.5,
              ),
              child: Container(
                width: 140,
                height: 140,
                padding: const EdgeInsets.all(30),
                child: Icon(
                  Icons.manage_search_rounded,
                  size: 70,
                  color: _primaryColor.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Start your search or browse by category',
              textAlign: TextAlign.center,
              style: _patrickHand(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: _primaryColor,
        )
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: _primaryColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 20),
            Text(
              'No results found',
              style: _patrickHand(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords or filters',
              style: _patrickHand(
                color: _primaryColor.withValues(alpha: 0.7),
                fontSize: 18,
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
    return GestureDetector(
      onTap: () => context.push('/question/${question.id}'),
      child: WiredCard(
        backgroundColor: Colors.white,
        borderColor: _primaryColor.withValues(alpha: 0.3),
        borderWidth: 1.5,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _primaryColor, width: 1),
                  ),
                  child: Text(
                    'Q${question.questionNumber}',
                    style: _patrickHand(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (question.isMCQ)
                  WiredCard(
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    borderColor: Colors.blue.withValues(alpha: 0.4),
                    borderWidth: 1,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'MCQ',
                      style: _patrickHand(
                        color: Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              question.content,
              style: _patrickHand(
                color: _primaryColor,
                fontSize: 16,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (question.hasPaperInfo) ...[
              const SizedBox(height: 8),
              Text(
                question.paperLabel,
                style: _patrickHand(
                  color: _primaryColor.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
