import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/toast_service.dart';
import '../past_papers/data/past_paper_repository.dart';
import '../past_papers/models/subject_model.dart';
import '../auth/services/auth_service.dart';
import 'subject_detail_view.dart';
import 'widgets/dashboard_empty_state.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedCurriculum = 'SPM';
  int? _selectedSubjectIndex;
  String? _selectedSubjectName; // Nullable, initialized to null
  String? _selectedSubjectId; // Store subject ID for filtering
  List<SubjectModel> _pinnedSubjects = [];
  bool _isLoadingPinnedSubjects = false;
  
  final List<String> _curriculums = [
    'SPM',
    'IGCSE (Coming Soon)',
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
            decoration: BoxDecoration(
              color: AppColors.sidebar,
              border: Border(
                right: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: Column(
              children: [
                // Header Section
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // App Logo
                      Text(
                        'Test²',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Curriculum Switcher (PopupMenuButton)
                      PopupMenuButton<String>(
                        offset: const Offset(0, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: AppColors.surface,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedCurriculum,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down,
                              color: AppColors.textSecondary,
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
                                style: TextStyle(
                                  color: AppColors.textPrimary,
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
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnDark,
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
                Divider(
                  color: AppColors.divider,
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
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Pinned Subjects List
                Expanded(
                  child: _isLoadingPinnedSubjects
                      ? const Center(child: CircularProgressIndicator())
                      : _pinnedSubjects.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'No pinned subjects',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _pinnedSubjects.length,
                              itemBuilder: (context, index) {
                                final subject = _pinnedSubjects[index];
                                final isSelected = _selectedSubjectIndex == index;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        setState(() {
                                          _selectedSubjectIndex = index;
                                          _selectedSubjectName = subject.name;
                                          _selectedSubjectId = subject.id;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppColors.primary.withValues(alpha: 0.1)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isSelected
                                                ? AppColors.primary
                                                : Colors.transparent,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          subject.name,
                                          style: TextStyle(
                                            color: isSelected
                                                ? AppColors.primary
                                                : AppColors.textPrimary,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
                // Navigation Items
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      _buildNavButton(
                        icon: Icons.trending_up,
                        label: 'My Progress',
                        onTap: () => context.push('/progress'),
                      ),
                      const SizedBox(height: 8),
                      _buildNavButton(
                        icon: Icons.bookmark,
                        label: 'Bookmarks',
                        onTap: () => context.push('/bookmarks'),
                      ),
                      const SizedBox(height: 8),
                      _buildNavButton(
                        icon: Icons.search,
                        label: 'Search',
                        onTap: () => context.push('/search'),
                      ),
                    ],
                  ),
                ),
                // Spacer pushes footer to bottom
                const Spacer(),
                // Footer
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Premium Upgrade Banner
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.accent,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => context.push('/premium'),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.workspace_premium,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Upgrade to Premium',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Divider(
                        color: AppColors.divider,
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
                                backgroundColor: AppColors.primary,
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
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      userEmail,
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.settings,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            color: AppColors.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'theme',
                                child: Consumer<ThemeProvider>(
                                  builder: (context, themeProvider, _) => Row(
                                    children: [
                                      Icon(
                                        themeProvider.isDarkMode 
                                            ? Icons.light_mode 
                                            : Icons.dark_mode,
                                        color: AppColors.textPrimary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        themeProvider.isDarkMode 
                                            ? 'Light Mode' 
                                            : 'Dark Mode',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'accessibility',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.accessibility_new,
                                      color: AppColors.textPrimary,
                                      size: 20,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Accessibility',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'logout',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.logout,
                                      color: AppColors.textPrimary,
                                      size: 20,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Logout',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) async {
                              if (value == 'theme') {
                                Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
                              } else if (value == 'accessibility') {
                                context.push('/settings/accessibility');
                              } else if (value == 'logout') {
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
            color: AppColors.divider,
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
    return DashboardEmptyState(
      onExploreSubjects: () => _showSubjectSelector(context),
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
              backgroundColor: AppColors.surface,
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
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Search Bar
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search for Biology, History...',
                        hintStyle: TextStyle(color: AppColors.textSecondary),
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: TextStyle(color: AppColors.textPrimary),
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
                        future: PastPaperRepository().getSubjects(curriculum: 'SPM'),
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
                                    color: AppColors.textPrimary,
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
                                    color: AppColors.textPrimary,
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
                                    color: AppColors.textPrimary,
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
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
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

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

