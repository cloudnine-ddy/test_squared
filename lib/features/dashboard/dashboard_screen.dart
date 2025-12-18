import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../past_papers/data/past_paper_repository.dart';
import '../past_papers/models/topic_model.dart';
import 'subject_detail_view.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedCurriculum = 'SPM';
  int? _selectedSubjectIndex;
  String? _selectedSubjectName;
  final List<String> _pinnedSubjects = ['Add Math', 'Physics'];
  final List<String> _allSubjects = [
    'Biology',
    'Chemistry',
    'Physics',
    'Add Math',
    'History',
    'Geography',
    'English',
    'Malay',
    'Chinese',
    'Economics',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test² Dashboard'),
      ),
      body: Row(
        children: [
          // Custom Sidebar
          Container(
            width: 260,
            color: AppTheme.surfaceDark,
            child: Column(
              children: [
                // Header Section
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // App Logo
                      const Text(
                        'Test²',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textWhite,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Curriculum Switcher
                      DropdownButton<String>(
                        value: _selectedCurriculum,
                        isExpanded: true,
                        underline: Container(),
                        dropdownColor: AppTheme.surfaceDark,
                        style: const TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 14,
                        ),
                        items: ['SPM', 'IGCSE', 'A-Level']
                            .map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedCurriculum = newValue;
                            });
                          }
                        },
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: AppTheme.textGray,
                        ),
                      ),
                    ],
                  ),
                ),
                // Primary Action Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showSubjectSelector(context);
                      },
                      icon: const Icon(Icons.grid_view),
                      label: const Text('Explore Subjects'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Divider
                const Divider(
                  color: Colors.white10,
                  thickness: 1,
                  height: 1,
                ),
                const SizedBox(height: 20),
                // Section Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'MY SUBJECTS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textGray,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Pinned Subjects List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _pinnedSubjects.length,
                    itemBuilder: (context, index) {
                      final isSelected = _selectedSubjectIndex == index;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          selected: isSelected,
                          selectedTileColor: AppTheme.primaryBlue.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          title: Text(
                            _pinnedSubjects[index],
                            style: TextStyle(
                              color: isSelected
                                  ? AppTheme.primaryBlue
                                  : AppTheme.textWhite,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedSubjectIndex = index;
                              _selectedSubjectName = _pinnedSubjects[index];
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
                // Spacer pushes footer to bottom
                const Spacer(),
                // Footer
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Divider(
                        color: Colors.white10,
                        thickness: 1,
                        height: 1,
                      ),
                      const SizedBox(height: 16),
                      // Profile Row
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 16,
                            backgroundColor: AppTheme.primaryBlue,
                            child: Icon(
                              Icons.person,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'User Name',
                              style: TextStyle(
                                color: AppTheme.textWhite,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.settings,
                              color: AppTheme.textGray,
                              size: 20,
                            ),
                            onPressed: () {
                              // TODO: Open settings
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Vertical Divider
          Container(
            width: 1,
            color: Colors.white10,
          ),
          // Main Content Area
          Expanded(
            child: _selectedSubjectName != null
                ? SubjectDetailView(subjectName: _selectedSubjectName!)
                : _buildMainContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
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

  void _showSubjectSelector(BuildContext context) {
    final TextEditingController searchController = TextEditingController();
    final List<String> filteredSubjects = List.from(_allSubjects);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: AppTheme.surfaceDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: 500,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    const Text(
                      'Select Subject',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textWhite,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Search Bar
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search for Biology, History...',
                        hintStyle: const TextStyle(color: AppTheme.textGray),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppTheme.textGray,
                        ),
                        filled: true,
                        fillColor: AppTheme.backgroundDeepest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(color: AppTheme.textWhite),
                      onChanged: (value) {
                        setDialogState(() {
                          filteredSubjects.clear();
                          if (value.isEmpty) {
                            filteredSubjects.addAll(_allSubjects);
                          } else {
                            filteredSubjects.addAll(
                              _allSubjects.where((subject) =>
                                  subject.toLowerCase().contains(
                                        value.toLowerCase(),
                                      )),
                            );
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Subjects List
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredSubjects.length,
                        itemBuilder: (context, index) {
                          final subject = filteredSubjects[index];
                          return ListTile(
                            title: Text(
                              subject,
                              style: const TextStyle(
                                color: AppTheme.textWhite,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            onTap: () {
                              setState(() {
                                _selectedSubjectName = subject;
                                // Update selected index if it's a pinned subject
                                final pinnedIndex =
                                    _pinnedSubjects.indexOf(subject);
                                if (pinnedIndex != -1) {
                                  _selectedSubjectIndex = pinnedIndex;
                                }
                              });
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

