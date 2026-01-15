import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/toast_service.dart';
import '../../shared/wired/wired_widgets.dart';
import '../auth/services/auth_service.dart';
import '../auth/providers/auth_provider.dart';
import '../past_papers/data/past_paper_repository.dart';
import '../past_papers/models/subject_model.dart';
import 'widgets/explore_subjects_sheet.dart';

/// A shell wrapper for the dashboard that keeps the sidebar persistent
class DashboardShell extends ConsumerStatefulWidget {
  final Widget child;
  
  const DashboardShell({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  String _selectedCurriculum = 'IGCSE';
  List<SubjectModel> _pinnedSubjects = [];
  bool _isLoadingPinnedSubjects = false;

  final List<String> _curriculums = [
    'IGCSE',
    'SPM (Coming Soon)',
    'A-Level (Coming Soon)',
  ];

  static const Color _primaryColor = Color(0xFF2D3E50);
  static const Color _backgroundColor = Color(0xFFFDFBF7);

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
    setState(() => _isLoadingPinnedSubjects = true);
    try {
      final subjects = await PastPaperRepository().getPinnedSubjects();
      setState(() {
        _pinnedSubjects = subjects;
        _isLoadingPinnedSubjects = false;
      });
    } catch (e) {
      setState(() => _isLoadingPinnedSubjects = false);
    }
  }

  void _showSubjectSelector(BuildContext context) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const ExploreSubjectsSheet(),
    );

    if (result != null && context.mounted) {
      final id = result['id'];
      final name = result['name'];
      if (id != null && name != null) {
        context.go('/dashboard?subjectId=$id&subjectName=${Uri.encodeComponent(name)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 260,
            decoration: const BoxDecoration(
              color: _backgroundColor,
              border: Border(
                right: BorderSide(color: _primaryColor, width: 2),
              ),
            ),
            child: Column(
              children: [
                // Header / Curriculum Switcher
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      popupMenuTheme: PopupMenuThemeData(
                        shape: WiredShapeBorder(color: _primaryColor, width: 2),
                        elevation: 0,
                        color: _backgroundColor,
                      ),
                    ),
                    child: PopupMenuButton<String>(
                      offset: const Offset(0, 50),
                      child: WiredCard(
                        borderColor: _primaryColor,
                        borderWidth: 2,
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedCurriculum,
                              style: _patrickHand(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const Icon(Icons.keyboard_arrow_down, color: _primaryColor, size: 20),
                          ],
                        ),
                      ),
                      itemBuilder: (context) => _curriculums.map((c) => PopupMenuItem(
                        value: c,
                        child: Text(c, style: _patrickHand()),
                      )).toList(),
                      onSelected: (newValue) {
                        if (newValue.contains('Coming Soon')) {
                          ToastService.showWarning('This curriculum is coming soon!');
                          return;
                        }
                        setState(() => _selectedCurriculum = newValue);
                      },
                    ),
                  ),
                ),

                // Secondary Navigation Header (Explore Subjects)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: WiredButton(
                    onPressed: () => _showSubjectSelector(context),
                    filled: true,
                    backgroundColor: _primaryColor,
                    borderColor: _primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search, color: Colors.white, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          'Explore Subjects',
                          style: _patrickHand(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: WiredDivider(color: _primaryColor, thickness: 1.5),
                ),
                const SizedBox(height: 20),
                
                // My Subjects Title
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
                
                // Subjects List
                Expanded(
                  child: _isLoadingPinnedSubjects
                      ? const Center(child: CircularProgressIndicator(color: _primaryColor))
                      : _pinnedSubjects.isEmpty
                          ? Center(child: Text('No pinned subjects', style: _patrickHand(fontSize: 14, color: Colors.grey)))
                          : ListView.builder(
                              itemCount: _pinnedSubjects.length,
                              itemBuilder: (context, index) {
                                final subject = _pinnedSubjects[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                  child: GestureDetector(
                                    onTap: () {
                                      // Special handling for dashboard home navigation with subject
                                      context.go('/dashboard?subjectId=${subject.id}&subjectName=${Uri.encodeComponent(subject.name)}');
                                    },
                                    child: WiredCard(
                                      borderColor: _primaryColor.withValues(alpha: 0.3),
                                      backgroundColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      child: Text(
                                        subject.name,
                                        style: _patrickHand(fontSize: 16, color: _primaryColor),
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
                      _buildWiredNavButton(Icons.trending_up, 'My Progress', () => context.go('/progress')),
                      const SizedBox(height: 8),
                      _buildWiredNavButton(Icons.bookmark, 'Bookmarks', () => context.go('/bookmarks')),
                      const SizedBox(height: 8),
                      _buildWiredNavButton(Icons.search, 'Search', () => context.go('/search')),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Footer / Premium / User
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      if (!ref.watch(isPremiumProvider))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: WiredButton(
                            onPressed: () => context.go('/premium'),
                            filled: true,
                            backgroundColor: _primaryColor,
                            borderColor: _primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                const Icon(Icons.workspace_premium, color: Colors.white, size: 18),
                                const SizedBox(width: 10),
                                Expanded(child: Text('Upgrade to Premium', style: _patrickHand(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))),
                                const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 12),
                              ],
                            ),
                          ),
                        ),
                      WiredDivider(color: _primaryColor, thickness: 1.5),
                      const SizedBox(height: 16),
                      
                      // User Profile Row
                      Builder(builder: (context) {
                        final user = Supabase.instance.client.auth.currentUser;
                        final name = user?.userMetadata?['full_name'] as String? ?? 'Student';
                        final email = user?.email ?? '';
                        
                        return Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: _primaryColor,
                              child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'S', style: _patrickHand(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    name, 
                                    style: _patrickHand(fontSize: 14, fontWeight: FontWeight.bold), 
                                    overflow: TextOverflow.ellipsis
                                  ),
                                  if (email.isNotEmpty)
                                    Text(
                                      email, 
                                      style: _patrickHand(fontSize: 12, color: _primaryColor.withValues(alpha: 0.6)), 
                                      overflow: TextOverflow.ellipsis
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.logout, size: 18),
                              onPressed: () async {
                                await AuthService().signOut();
                                if (context.mounted) context.go('/');
                              },
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Main Content
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  Widget _buildWiredNavButton(IconData icon, String label, VoidCallback onTap) {
    return WiredButton(
      onPressed: onTap,
      filled: false,
      borderColor: _primaryColor.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: _primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: _patrickHand(fontSize: 16, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
