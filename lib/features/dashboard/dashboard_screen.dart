import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/toast_service.dart';
import '../past_papers/data/past_paper_repository.dart';
import '../past_papers/models/subject_model.dart';
import '../auth/services/auth_service.dart';
import 'subject_detail_view.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedCurriculum = 'IGCSE';
  int? _selectedSubjectIndex;
  String? _selectedSubjectName; // Nullable, initialized to null
  String? _selectedSubjectId; // Store subject ID for filtering
  List<SubjectModel> _pinnedSubjects = [];
  bool _isLoadingPinnedSubjects = false;
  
  final List<String> _curriculums = [
    'SPM (Coming Soon)',
    'IGCSE',
    'A-Level (Coming Soon)',
  ];

  @override
  void initState() {
    super.initState();
    _loadPinnedSubjects();
  }

  Future<void> _loadPinnedSubjects() async {
    setState(() {
      _isLoadingPinnedSubjects = true;
    });

    try {
      final subjects = await PastPaperRepository().getPinnedSubjects();
      setState(() {
        _pinnedSubjects = subjects;
        _isLoadingPinnedSubjects = false;
      });
    } catch (e) {
      print('Error loading pinned subjects: $e');
      setState(() {
        _isLoadingPinnedSubjects = false;
      });
    }
  }

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
                      // Curriculum Switcher (PopupMenuButton)
                      PopupMenuButton<String>(
                        offset: const Offset(0, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: const Color(0xFF1F2937),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedCurriculum,
                              style: const TextStyle(
                                color: AppTheme.textWhite,
                                fontSize: 14,
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              color: AppTheme.textGray,
                              size: 20,
                            ),
                          ],
                        ),
                        itemBuilder: (BuildContext context) {
                          return _curriculums.map((String curriculum) {
                            return PopupMenuItem<String>(
                              value: curriculum,
                              child: Text(
                                curriculum,
                                style: const TextStyle(
                                  color: AppTheme.textWhite,
                                  fontSize: 14,
                                ),
                              ),
                            );
                          }).toList();
                        },
                        onSelected: (String newValue) {
                          // Prevent selection of "Coming Soon" items
                          if (newValue.contains('Coming Soon')) {
                            ToastService.showWarning('This curriculum is coming soon!');
                            return;
                          }
                          setState(() {
                            _selectedCurriculum = newValue;
                          });
                        },
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
                  child: _isLoadingPinnedSubjects
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : _pinnedSubjects.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'No pinned subjects',
                                  style: TextStyle(
                                    color: AppTheme.textGray,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: _pinnedSubjects.length,
                              itemBuilder: (context, index) {
                                final subject = _pinnedSubjects[index];
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
                                      subject.name,
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
                                        _selectedSubjectName = subject.name;
                                        _selectedSubjectId = subject.id;
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
                      Builder(
                        builder: (context) {
                          final user = Supabase.instance.client.auth.currentUser;
                          final userName = user?.userMetadata?['full_name'] as String? ?? 'Student';
                          final userEmail = user?.email ?? 'No email';
                          final avatarText = userName.isNotEmpty ? userName[0].toUpperCase() : 'S';
                          
                          return Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppTheme.primaryBlue,
                                child: Text(
                                  avatarText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      userName,
                                      style: const TextStyle(
                                        color: AppTheme.textWhite,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      userEmail,
                                      style: TextStyle(
                                        color: AppTheme.textGray,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.settings,
                              color: AppTheme.textGray,
                              size: 20,
                            ),
                            color: AppTheme.surfaceDark,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'logout',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.logout,
                                      color: AppTheme.textWhite,
                                      size: 20,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Logout',
                                      style: TextStyle(
                                        color: AppTheme.textWhite,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) async {
                              if (value == 'logout') {
                                await AuthService().signOut();
                                if (mounted) {
                                  context.go('/');
                                }
                              }
                            },
                          ),
                            ],
                          );
                        },
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
            child: _selectedSubjectName != null && _selectedSubjectId != null
                ? SubjectDetailView(
                    subjectName: _selectedSubjectName!,
                    subjectId: _selectedSubjectId!,
                    isPinned: _pinnedSubjects.any((s) => s.id == _selectedSubjectId),
                    onPinChanged: () => _loadPinnedSubjects(),
                  )
                : _buildEmptyState(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 64,
            color: Colors.white10,
          ),
          const SizedBox(height: 16),
          Text(
            'Select a subject from the sidebar to start',
            style: TextStyle(
              color: Colors.white10,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  void _showSubjectSelector(BuildContext context) {
    final TextEditingController searchController = TextEditingController();
    String searchQuery = '';

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
                constraints: const BoxConstraints(maxHeight: 600),
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
                          searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Subjects List with FutureBuilder
                    Flexible(
                      child: FutureBuilder<List<SubjectModel>>(
                        future: PastPaperRepository().getSubjects(),
                        builder: (context, snapshot) {
                          // Loading State
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          }

                          // Error State
                          if (snapshot.hasError) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Text(
                                  'Failed to load subjects',
                                  style: TextStyle(
                                    color: AppTheme.textWhite,
                                  ),
                                ),
                              ),
                            );
                          }

                          // Empty State
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Text(
                                  'No subjects found',
                                  style: TextStyle(
                                    color: AppTheme.textWhite,
                                  ),
                                ),
                              ),
                            );
                          }

                          // Success State - Filter subjects based on search
                          final allSubjects = snapshot.data!;
                          final filteredSubjects = searchQuery.isEmpty
                              ? allSubjects
                              : allSubjects.where((subject) =>
                                  subject.name
                                      .toLowerCase()
                                      .contains(searchQuery.toLowerCase())).toList();

                          if (filteredSubjects.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Text(
                                  'No subjects match your search',
                                  style: TextStyle(
                                    color: AppTheme.textWhite,
                                  ),
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredSubjects.length,
                            itemBuilder: (context, index) {
                              final subject = filteredSubjects[index];
                              return ListTile(
                                title: Text(
                                  subject.name,
                                  style: const TextStyle(
                                    color: AppTheme.textWhite,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                          onTap: () async {
                            // Only set the selected subject (no auto-pinning)
                            setState(() {
                              _selectedSubjectName = subject.name;
                              _selectedSubjectId = subject.id;
                              // Update selected index if it's already in the pinned list
                              final pinnedIndex = _pinnedSubjects
                                  .indexWhere((s) => s.id == subject.id);
                              if (pinnedIndex != -1) {
                                _selectedSubjectIndex = pinnedIndex;
                              } else {
                                _selectedSubjectIndex = null;
                              }
                            });
                            
                            Navigator.of(context).pop();
                            
                            // Check if subject has topics and show warning if empty
                            try {
                              final topics = await PastPaperRepository().getTopics(subjectId: subject.id);
                              if (topics.isEmpty && mounted) {
                                ToastService.showWarning('This subject has no content yet.');
                              }
                            } catch (e) {
                              // Silently fail - we don't want to show error for this check
                              print('Error checking topics: $e');
                            }
                          },
                              );
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

