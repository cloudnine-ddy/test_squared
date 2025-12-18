import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../past_papers/data/past_paper_repository.dart';
import '../past_papers/models/topic_model.dart';

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

  @override
  void initState() {
    super.initState();
    _isPinned = widget.isPinned;
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
            color: AppTheme.surfaceDark,
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
                  color: AppTheme.textWhite,
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
                  selectedBackgroundColor: AppTheme.primaryBlue,
                  selectedForegroundColor: Colors.white,
                  backgroundColor: AppTheme.surfaceDark,
                  foregroundColor: AppTheme.textGray,
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
                            AppTheme.primaryBlue,
                          ),
                        ),
                      )
                    : Icon(
                        _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                        color: _isPinned ? AppTheme.primaryBlue : AppTheme.textGray,
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subject unpinned'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Pin the subject
        await PastPaperRepository().pinSubject(widget.subjectId);
        setState(() {
          _isPinned = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subject pinned'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
      
      // Refresh the pinned subjects list in the parent
      widget.onPinChanged();
    } catch (e) {
      print('Error toggling pin: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
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

        final topics = snapshot.data!;

        return GridView.builder(
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
            return InkWell(
              onTap: () {
                context.go('/topic/${topic.id}');
              },
              borderRadius: BorderRadius.circular(12),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border(
                      top: BorderSide(
                        color: topic.color,
                        width: 4,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topic.name,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              topic.description,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${topic.questionCount} questions',
                          style: TextStyle(
                            fontSize: 14,
                            color: topic.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildYearsView() {
    final years = List.generate(10, (index) => 2024 - index);

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
              // TODO: Navigate to year detail
            },
          ),
        );
      },
    );
  }
}

