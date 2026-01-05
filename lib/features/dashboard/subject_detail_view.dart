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
    return Column(
      children: [
        // Top Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.sidebar,
            border: Border(
              bottom: BorderSide(
                color: Colors.white10,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Subject Name
              Text(
                widget.subjectName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              // View Toggle
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'Topics',
                    label: Text('Topics'),
                  ),
                  ButtonSegment(
                    value: 'Years',
                    label: Text('Years'),
                  ),
                ],
                selected: {_viewMode},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _viewMode = newSelection.first;
                  });
                },
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: AppColors.primary,
                  selectedForegroundColor: Colors.white,
                  backgroundColor: AppColors.sidebar,
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 16),
              // Pin/Unpin Button
              IconButton(
                icon: _isTogglingPin
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      )
                    : Icon(
                        _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                        color: _isPinned ? AppColors.primary : AppColors.textSecondary,
                      ),
                tooltip: _isPinned ? 'Unpin' : 'Pin to Sidebar',
                onPressed: _isTogglingPin ? null : _handlePinToggle,
              ),
            ],
          ),
        ),
        // Body Content
        Expanded(
          child: _viewMode == 'Topics' ? _buildTopicsView() : _buildYearsView(),
        ),
      ],
    );
  }

  Future<void> _handlePinToggle() async {
    setState(() {
      _isTogglingPin = true;
    });

    try {
      if (_isPinned) {
        // Unpin the subject
        await PastPaperRepository().unpinSubject(widget.subjectId);
        setState(() {
          _isPinned = false;
        });
        if (mounted) {
          ToastService.showInfo('Subject unpinned');
        }
      } else {
        // Pin the subject
        await PastPaperRepository().pinSubject(widget.subjectId);
        setState(() {
          _isPinned = true;
        });
        if (mounted) {
          ToastService.showSuccess('Subject pinned');
        }
      }

      // Refresh the pinned subjects list in the parent
      widget.onPinChanged();
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
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return const Center(
            child: Text('Error loading topics'),
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
                  color: Colors.white24,
                ),
                const SizedBox(height: 16),
                Text(
                  'No topics available yet',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Check back later or try another subject.',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
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
            // Search Bar Only
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.sidebar,
                border: Border(
                  bottom: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search topics...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                ),
                style: TextStyle(color: AppColors.textPrimary),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            
            // Topics Grid
            Expanded(
              child: topics.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.white24),
                          const SizedBox(height: 16),
                          Text(
                            'No topics found',
                            style: TextStyle(color: Colors.grey[400], fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try a different search term',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
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

        // Determine progress color
        Color progressColor = topic.color;
        if (progressPercentage == 0) {
          progressColor = Colors.grey;
        } else if (progressPercentage < 50) {
          progressColor = Colors.orange;
        } else if (progressPercentage < 100) {
          progressColor = Colors.blue;
        } else {
          progressColor = Colors.green;
        }

        return InkWell(
          onTap: () {
            context.push('/topic/${topic.id}');
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.surface,
                  AppColors.surface.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: progressColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Background gradient accent
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          progressColor.withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(16),
                      ),
                    ),
                  ),
                ),
                
                // Content
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row with topic name and icon
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Topic icon/badge
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: progressColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.school,
                              size: 20,
                              color: progressColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Topic name
                          Expanded(
                            child: Text(
                              topic.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      
                      const Spacer(),
                      
                      // Question count badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.quiz,
                              size: 14,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$totalQuestions question${totalQuestions != 1 ? 's' : ''}',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Progress bar and percentage
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Progress',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${progressPercentage.toInt()}%',
                                style: TextStyle(
                                  color: progressColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progressPercentage / 100,
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$completedQuestions/$totalQuestions completed',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
          padding: const EdgeInsets.all(16),
          itemCount: years.length,
          itemBuilder: (context, index) {
            final year = years[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(
                  '$year',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Past papers from $year',
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  context.push('/papers/year/$year/subject/${widget.subjectId}');
                },
              ),
            );
          },
        );
      },
    );
  }
}
