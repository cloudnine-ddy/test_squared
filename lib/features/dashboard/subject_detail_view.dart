import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/toast_service.dart';
import '../past_papers/data/past_paper_repository.dart';
import '../past_papers/models/topic_model.dart';
import '../progress/data/topic_progress_repository.dart';
import '../past_papers/widgets/circular_topic_progress.dart';
import '../../shared/wired/wired_widgets.dart';
import 'dashboard_shell.dart';

class SubjectDetailView extends StatefulWidget {
  final String subjectName;
  final String subjectId;
  final bool isPinned;
  final VoidCallback onPinChanged;

  const SubjectDetailView({
    super.key,
    required this.subjectName,
    required this.subjectId,
    required this.isPinned,
    required this.onPinChanged,
  });

  @override
  State<SubjectDetailView> createState() => _SubjectDetailViewState();
}

class _SubjectDetailViewState extends State<SubjectDetailView> {
  String _viewMode = 'Topics'; // 'Topics' or 'Years'
  bool _isPinned = false;
  bool _isTogglingPin = false;

  // Search and filter state
  String _searchQuery = '';
  String _sortBy = 'Alphabetical'; // 'Alphabetical', 'Progress', 'Questions'
  final TextEditingController _searchController = TextEditingController();

  // Sketchy Theme Colors (matching sidebar)
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
    _isPinned = widget.isPinned;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SubjectDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPinned != widget.isPinned) {
      _isPinned = widget.isPinned;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _backgroundColor,
      child: Column(
        children: [
          // Top Bar (Sketchy style)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: _backgroundColor,
              border: Border(
                bottom: BorderSide(
                  color: _primaryColor.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
            ),
            child: Row(
              children: [
                // Subject Name
                Text(
                  widget.subjectName,
                  style: _patrickHand(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // View Toggle (Custom sketchy buttons)
                Row(
                  children: [
                    _buildToggleButton('Topics', _viewMode == 'Topics'),
                    const SizedBox(width: 8),
                    _buildToggleButton('Years', _viewMode == 'Years'),
                  ],
                ),
                const SizedBox(width: 16),
                // Pin/Unpin Button
                GestureDetector(
                  onTap: _isTogglingPin ? null : _handlePinToggle,
                  child: WiredCard(
                    backgroundColor: _isPinned ? _primaryColor.withValues(alpha: 0.1) : Colors.white,
                    borderColor: _primaryColor.withValues(alpha: 0.5),
                    borderWidth: 1.5,
                    padding: const EdgeInsets.all(8),
                    child: _isTogglingPin
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _primaryColor,
                            ),
                          )
                        : Icon(
                            _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                            color: _isPinned ? _primaryColor : _primaryColor.withValues(alpha: 0.6),
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          ),
          // Body Content
          Expanded(
            child: _viewMode == 'Topics' ? _buildTopicsView() : _buildYearsView(),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _viewMode = label;
        });
      },
      child: WiredCard(
        backgroundColor: isSelected ? _primaryColor : Colors.white,
        borderColor: _primaryColor,
        borderWidth: 1.5,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.check, size: 16, color: Colors.white),
              ),
            Text(
              label,
              style: _patrickHand(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : _primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePinToggle() async {
    setState(() {
      _isTogglingPin = true;
    });

    try {
      final curriculum = DashboardShell.currentCurriculum;
      if (_isPinned) {
        // Unpin the subject
        await PastPaperRepository().unpinSubject(
          widget.subjectId,
          curriculum: curriculum,
        );
        setState(() {
          _isPinned = false;
        });
        if (mounted) {
          ToastService.showInfo('Subject unpinned');
        }
      } else {
        // Pin the subject
        await PastPaperRepository().pinSubject(
          widget.subjectId,
          curriculum: curriculum,
        );
        setState(() {
          _isPinned = true;
        });
        if (mounted) {
          ToastService.showSuccess('Subject pinned');
        }
      }

      // Refresh the pinned subjects list in the parent
      widget.onPinChanged();

      // Also refresh the sidebar in DashboardShell
      DashboardShell.refreshPinnedSubjects();
    } catch (e) {
      print('Error toggling pin: $e');
      if (mounted) {
        ToastService.showError('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingPin = false;
        });
      }
    }
  }

  Widget _buildTopicsView() {
    return FutureBuilder<List<TopicModel>>(
      key: ValueKey('topics_${widget.subjectId}'), // Force rebuild when subjectId changes
      future: PastPaperRepository().getTopics(subjectId: widget.subjectId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: _primaryColor),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading topics',
              style: _patrickHand(fontSize: 18, color: _primaryColor.withValues(alpha: 0.6)),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: _primaryColor.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No topics available yet',
                  style: _patrickHand(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Check back later or try another subject.',
                  style: _patrickHand(
                    fontSize: 16,
                    color: _primaryColor.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          );
        }

        var topics = snapshot.data!;

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          topics = topics.where((topic) {
            return topic.name.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();
        }

        // Default alphabetical sort
        topics = List.from(topics);
        topics.sort((a, b) => a.name.compareTo(b.name));

        return Column(
          children: [
            // Search Bar (WiredCard)
            Padding(
              padding: const EdgeInsets.all(16),
              child: WiredCard(
                backgroundColor: Colors.white,
                borderColor: _primaryColor.withValues(alpha: 0.5),
                borderWidth: 1.5,
                padding: EdgeInsets.zero,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search topics...',
                    hintStyle: _patrickHand(
                      fontSize: 16,
                      color: _primaryColor.withValues(alpha: 0.5),
                    ),
                    prefixIcon: Icon(Icons.search, size: 20, color: _primaryColor.withValues(alpha: 0.6)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 20, color: _primaryColor.withValues(alpha: 0.6)),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  style: _patrickHand(fontSize: 16),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
            ),

            // Topics Grid
            Expanded(
              child: topics.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: _primaryColor.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          Text(
                            'No topics found',
                            style: _patrickHand(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryColor.withValues(alpha: 0.7)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try a different search term',
                            style: _patrickHand(fontSize: 16, color: _primaryColor.withValues(alpha: 0.5)),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 300,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: topics.length,
                      itemBuilder: (context, index) {
                        final topic = topics[index];
                        return _buildTopicCard(topic);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopicCard(TopicModel topic) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getTopicProgress(topic.id),
      builder: (context, progressSnapshot) {
        final progress = progressSnapshot.data;
        final progressPercentage = progress?['progress_percentage'] ?? 0.0;
        final completedQuestions = progress?['completed_questions'] ?? 0;
        final totalQuestions = progress?['total_questions'] ?? topic.questionCount;

        return GestureDetector(
          onTap: () {
            context.push('/topic/${topic.id}');
          },
          child: WiredCard(
            backgroundColor: Colors.white,
            borderColor: _primaryColor.withValues(alpha: 0.4),
            borderWidth: 1.5,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row with topic icon and name
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Topic icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.school_outlined,
                        size: 18,
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Topic name
                    Expanded(
                      child: Text(
                        topic.name,
                        style: _patrickHand(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Question count badge
                // Question count badge with breakdown
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (topic.mcqCount > 0)
                      WiredCard(
                        backgroundColor: _primaryColor.withValues(alpha: 0.08),
                        borderColor: _primaryColor.withValues(alpha: 0.3),
                        borderWidth: 1,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: Text(
                          '${topic.mcqCount} MCQ',
                          style: _patrickHand(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    if (topic.structuredCount > 0)
                      WiredCard(
                        backgroundColor: _primaryColor.withValues(alpha: 0.08),
                        borderColor: _primaryColor.withValues(alpha: 0.3),
                        borderWidth: 1,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: Text(
                          '${topic.structuredCount} Structured',
                          style: _patrickHand(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    if (topic.mcqCount == 0 && topic.structuredCount == 0)
                      WiredCard(
                        backgroundColor: _primaryColor.withValues(alpha: 0.08),
                        borderColor: _primaryColor.withValues(alpha: 0.3),
                        borderWidth: 1,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.quiz_outlined,
                              size: 16,
                              color: _primaryColor.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$totalQuestions question${totalQuestions != 1 ? 's' : ''}',
                              style: _patrickHand(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _primaryColor.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Progress section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress',
                          style: _patrickHand(
                            fontSize: 15,
                            color: _primaryColor.withValues(alpha: 0.6),
                          ),
                        ),
                        Text(
                          '${progressPercentage.toInt()}%',
                          style: _patrickHand(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFEF6C00), // Orange 800 for contrast
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Progress bar with sketchy look
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _primaryColor.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (progressPercentage / 100).clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD54F), Color(0xFFFFA726)], // Amber to Orange
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(4.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$completedQuestions/$totalQuestions completed',
                      style: _patrickHand(
                        fontSize: 14,
                        color: _primaryColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getTopicProgress(String topicId) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        return {
          'topic_id': topicId,
          'total_questions': 0,
          'completed_questions': 0,
          'progress_percentage': 0.0,
        };
      }

      final progressRepo = TopicProgressRepository();
      return await progressRepo.getTopicProgress(
        userId: userId,
        topicId: topicId,
      );
    } catch (e) {
      return {
        'topic_id': topicId,
        'total_questions': 0,
        'completed_questions': 0,
        'progress_percentage': 0.0,
      };
    }
  }

  Widget _buildYearsView() {
    return FutureBuilder<List<int>>(
      key: ValueKey('years_${widget.subjectId}'), // Force rebuild when subjectId changes
      future: PastPaperRepository().fetchAvailableYears(widget.subjectId),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading papers',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try again later',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        // Empty state
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 64,
                  color: Colors.white24,
                ),
                const SizedBox(height: 16),
                Text(
                  'No past papers found',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Papers will appear here once added to the database.',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        // Success state - display years
        final years = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: years.length,
          itemBuilder: (context, index) {
            final year = years[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: () {
                  context.push('/papers/year/$year/subject/${widget.subjectId}');
                },
                borderRadius: BorderRadius.circular(8),
                child: WiredCard(
                  backgroundColor: Colors.white,
                  borderColor: _primaryColor.withValues(alpha: 0.3),
                  borderWidth: 2,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      // Year badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: _primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _primaryColor.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '$year',
                          style: _patrickHand(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Past Papers',
                              style: _patrickHand(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _primaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'View all papers from $year',
                              style: _patrickHand(
                                fontSize: 14,
                                color: _primaryColor.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Arrow
                      Icon(
                        Icons.chevron_right,
                        color: _primaryColor.withValues(alpha: 0.5),
                        size: 28,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
