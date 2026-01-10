import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/toast_service.dart';
import '../../shared/wired/wired_widgets.dart';
import '../past_papers/data/past_paper_repository.dart';
import '../past_papers/models/subject_model.dart';
import '../auth/services/auth_service.dart';
import '../auth/providers/auth_provider.dart';
import 'subject_detail_view.dart';
import 'widgets/dashboard_empty_state.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final bool previewMode; // Admin preview mode
  
  const DashboardScreen({super.key, this.previewMode = false});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _selectedCurriculum = 'IGCSE';
  int? _selectedSubjectIndex;
  String? _selectedSubjectName; // Nullable, initialized to null
  String? _selectedSubjectId; // Store subject ID for filtering
  List<SubjectModel> _pinnedSubjects = [];
  bool _isLoadingPinnedSubjects = false;

  final List<String> _curriculums = [
    'IGCSE',
    'SPM (Coming Soon)',
    'A-Level (Coming Soon)',
  ];

  // Sketchy Theme Colors (matching Landing Page)
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
      body: Stack(
        children: [
          Row(
            children: [
              // Custom Sidebar
              Container(
                width: 260,
                decoration: BoxDecoration(
                  color: _backgroundColor, // Beige background
                  border: const Border(
                    right: BorderSide(
                      color: _primaryColor,
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    // Header Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Curriculum Switcher (no logo)
                          PopupMenuButton<String>(
                            offset: const Offset(0, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            color: _backgroundColor,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedCurriculum,
                                  style: _patrickHand(fontSize: 18),
                                ),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  color: _primaryColor.withValues(alpha: 0.6),
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
                                    style: _patrickHand(fontSize: 16),
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
                      child: WiredButton(
                        onPressed: () => _showSubjectSelector(context),
                        filled: true,
                        backgroundColor: _primaryColor,
                        borderColor: _primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.grid_view, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Explore Subjects',
                              style: _patrickHand(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Divider (Wired)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: WiredDivider(color: _primaryColor, thickness: 1.5),
                    ),
                    const SizedBox(height: 20),
                    // Section Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'MY SUBJECTS',
                          style: _patrickHand(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _primaryColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Pinned Subjects List
                    Expanded(
                      child: _isLoadingPinnedSubjects
                          ? Center(child: CircularProgressIndicator(color: _primaryColor))
                          : _pinnedSubjects.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      'No pinned subjects',
                                      style: _patrickHand(
                                        fontSize: 14,
                                        color: _primaryColor.withValues(alpha: 0.5),
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
                                        vertical: 2,
                                      ),
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedSubjectIndex = index;
                                            _selectedSubjectName = subject.name;
                                            _selectedSubjectId = subject.id;
                                          });
                                        },
                                        child: WiredCard(
                                          borderColor: isSelected ? _primaryColor : _primaryColor.withValues(alpha: 0.3),
                                          borderWidth: isSelected ? 2 : 1,
                                          backgroundColor: isSelected 
                                              ? _primaryColor.withValues(alpha: 0.1)
                                              : Colors.transparent,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 8,
                                          ),
                                          child: Text(
                                            subject.name,
                                            style: _patrickHand(
                                              fontSize: 16,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              color: _primaryColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                    const SizedBox(height: 16), // Gap before navigation
                    // Navigation Items (just above footer)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(
                        children: [
                          _buildWiredNavButton(
                            icon: Icons.trending_up,
                            label: 'My Progress',
                            onTap: () => context.push('/progress'),
                          ),
                          const SizedBox(height: 8),
                          _buildWiredNavButton(
                            icon: Icons.bookmark,
                            label: 'Bookmarks',
                            onTap: () => context.push('/bookmarks'),
                          ),
                          const SizedBox(height: 8),
                          _buildWiredNavButton(
                            icon: Icons.search,
                            label: 'Search',
                            onTap: () => context.push('/search'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12), // Small gap before premium
                    // Footer
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Premium Upgrade Banner - Only show for non-premium users (hide in preview)
                          if (!ref.watch(isPremiumProvider) && !widget.previewMode)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: WiredButton(
                                onPressed: () => context.push('/premium'),
                                filled: true,
                                backgroundColor: _primaryColor,
                                borderColor: _primaryColor,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    const Icon(Icons.workspace_premium, color: Colors.white, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Upgrade to Premium',
                                        style: _patrickHand(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 12),
                                  ],
                                ),
                              ),
                            ),
                          WiredDivider(color: _primaryColor, thickness: 1.5),
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
                                    backgroundColor: _primaryColor,
                                    child: Text(
                                      avatarText,
                                      style: _patrickHand(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
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
                                          widget.previewMode ? 'Admin Preview' : userName,
                                          style: _patrickHand(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          widget.previewMode ? 'View as Student' : userEmail,
                                          style: _patrickHand(
                                            fontSize: 13,
                                            color: _primaryColor.withValues(alpha: 0.6),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                              if (!widget.previewMode)
                              PopupMenuButton<String>(
                                icon: Icon(
                                  Icons.settings,
                                  color: _primaryColor.withValues(alpha: 0.6),
                                  size: 20,
                                ),
                                color: Colors.white,
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: _primaryColor.withValues(alpha: 0.8), width: 1.5),
                                ),
                                itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'theme',
                                      child: Row(
                                        children: [
                                          Icon(
                                            ref.watch(themeModeProvider) == ThemeMode.dark
                                                ? Icons.light_mode
                                                : Icons.dark_mode,
                                            color: _primaryColor,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            ref.watch(themeModeProvider) == ThemeMode.dark
                                                ? 'Light Mode'
                                                : 'Dark Mode',
                                            style: _patrickHand(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  PopupMenuItem(
                                    value: 'accessibility',
                                    child: Row(
                                      children: [
                                          Icon(
                                            Icons.accessibility_new,
                                            color: _primaryColor,
                                            size: 20,
                                          ),
                                        const SizedBox(width: 12),
                                          Text(
                                            'Accessibility',
                                            style: _patrickHand(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'logout',
                                    child: Row(
                                      children: [
                                          Icon(
                                            Icons.logout,
                                            color: _primaryColor,
                                            size: 20,
                                          ),
                                        const SizedBox(width: 12),
                                          Text(
                                            'Logout',
                                            style: _patrickHand(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red[400],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                                onSelected: (value) async {
                                  if (value == 'theme') {
                                    ref.read(themeModeProvider.notifier).toggleTheme();
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
          
          // Floating Back to Admin button (only in preview mode)
          if (widget.previewMode)
            Positioned(
              top: 16,
              right: 16,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => context.go('/admin'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Back to Admin',
                          style: _patrickHand(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
              backgroundColor: Colors.transparent,
              child: WiredCard(
                backgroundColor: _backgroundColor,
                borderColor: _primaryColor,
                borderWidth: 2,
                padding: const EdgeInsets.all(24),
                width: 500,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 500),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        'Select Subject',
                        style: _patrickHand(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Search Bar (WiredCard for sketchy border)
                      WiredCard(
                        backgroundColor: Colors.white,
                        borderColor: _primaryColor.withValues(alpha: 0.6),
                        borderWidth: 1.5,
                        padding: EdgeInsets.zero,
                        child: TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'Search for Biology, History...',
                            hintStyle: _patrickHand(
                              fontSize: 16,
                              color: _primaryColor.withValues(alpha: 0.5),
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: _primaryColor.withValues(alpha: 0.6),
                            ),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          style: _patrickHand(fontSize: 16),
                          onChanged: (value) {
                            setDialogState(() {
                              searchQuery = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    // Subjects List with FutureBuilder
                    Flexible(
                      child: FutureBuilder<List<SubjectModel>>(
                        future: PastPaperRepository().getSubjects(curriculum: _selectedCurriculum),
                        builder: (context, snapshot) {
                          // Loading State
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _primaryColor,
                                ),
                              ),
                            );
                          }

                          // Error State
                          if (snapshot.hasError) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Text(
                                  'Failed to load subjects',
                                  style: _patrickHand(
                                    fontSize: 16,
                                    color: _primaryColor.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            );
                          }

                          // Empty State
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Text(
                                  'No subjects found',
                                  style: _patrickHand(
                                    fontSize: 16,
                                    color: _primaryColor.withValues(alpha: 0.6),
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
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Text(
                                  'No subjects match your search',
                                  style: _patrickHand(
                                    fontSize: 16,
                                    color: _primaryColor.withValues(alpha: 0.6),
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
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: GestureDetector(
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
                                      print('Error checking topics: \$e');
                                    }
                                  },
                                  child: WiredCard(
                                    borderColor: _primaryColor.withValues(alpha: 0.3),
                                    borderWidth: 1,
                                    backgroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    child: Text(
                                      subject.name,
                                      style: _patrickHand(fontSize: 16),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
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
          color: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15) // Slightly more visible
              : AppColors.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5) // Brighter border
                : AppColors.accent.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.secondary // Neon accent
                  : AppColors.accent,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white // High contrast white text
                    : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

  }

  // New wired nav button method (sketchy style)
  Widget _buildWiredNavButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return WiredButton(
      onPressed: onTap,
      filled: false,
      borderColor: _primaryColor.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: _primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: _patrickHand(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

