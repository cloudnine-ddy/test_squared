import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../past_papers/data/past_paper_repository.dart';
import '../past_papers/models/topic_model.dart';

class SubjectDetailView extends StatefulWidget {
  final String subjectName;

  const SubjectDetailView({
    super.key,
    required this.subjectName,
  });

  @override
  State<SubjectDetailView> createState() => _SubjectDetailViewState();
}

class _SubjectDetailViewState extends State<SubjectDetailView> {
  String _viewMode = 'Topics'; // 'Topics' or 'Years'
  bool _isPinned = false;

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
              // Pin Button
              IconButton(
                icon: Icon(
                  _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: _isPinned ? AppTheme.primaryBlue : AppTheme.textGray,
                ),
                onPressed: () {
                  setState(() {
                    _isPinned = !_isPinned;
                  });
                },
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

  Widget _buildTopicsView() {
    return FutureBuilder<List<TopicModel>>(
      future: PastPaperRepository().getTopics(),
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
          return const Center(
            child: Text('No topics found'),
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

