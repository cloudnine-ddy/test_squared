import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/toast_service.dart';
import '../../shared/wired/wired_widgets.dart';
import '../past_papers/data/past_paper_repository.dart';
import '../past_papers/models/subject_model.dart';
import 'subject_detail_view.dart';
import 'widgets/dashboard_empty_state.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final bool previewMode;
  final String? initialSubjectId;
  final String? initialSubjectName;
  
  const DashboardScreen({
    super.key, 
    this.previewMode = false,
    this.initialSubjectId,
    this.initialSubjectName,
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _selectedSubjectName; 
  String? _selectedSubjectId; 
  List<SubjectModel> _pinnedSubjects = [];
  bool _isLoadingPinnedSubjects = false;

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
    _selectedSubjectId = widget.initialSubjectId;
    _selectedSubjectName = widget.initialSubjectName;
    _loadPinnedSubjects();
  }

  @override
  void didUpdateWidget(DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSubjectId != oldWidget.initialSubjectId) {
      setState(() {
        _selectedSubjectId = widget.initialSubjectId;
        _selectedSubjectName = widget.initialSubjectName;
      });
    }
  }

  Future<void> _loadPinnedSubjects() async {
    setState(() => _isLoadingPinnedSubjects = true);
    try {
      final subjects = await PastPaperRepository().getPinnedSubjects();
      if (context.mounted) {
        setState(() {
          _pinnedSubjects = subjects;
          _isLoadingPinnedSubjects = false;
        });
      }
    } catch (e) {
      if (context.mounted) {
        setState(() => _isLoadingPinnedSubjects = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: _selectedSubjectId == null
          ? DashboardEmptyState(
              onExploreSubjects: () => _showSubjectSelector(context),
            )
          : SubjectDetailView(
              subjectId: _selectedSubjectId!,
              subjectName: _selectedSubjectName ?? 'Subject',
              isPinned: _pinnedSubjects.any((s) => s.id == _selectedSubjectId),
              onPinChanged: _loadPinnedSubjects,
            ),
    );
  }

  void _showSubjectSelector(BuildContext context) async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ExploreSubjectsSheet(),
    );

    if (result != null && context.mounted) {
      setState(() {
        _selectedSubjectId = result['id'];
        _selectedSubjectName = result['name'];
      });
    }
  }
}

class _ExploreSubjectsSheet extends StatefulWidget {
  const _ExploreSubjectsSheet();

  @override
  State<_ExploreSubjectsSheet> createState() => _ExploreSubjectsSheetState();
}

class _ExploreSubjectsSheetState extends State<_ExploreSubjectsSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final String _selectedCurriculum = 'IGCSE';

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
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: _primaryColor, width: 3),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Explore Subjects',
                  style: _patrickHand(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: _primaryColor),
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: WiredCard(
              backgroundColor: Colors.white,
              borderColor: _primaryColor,
              borderWidth: 2,
              padding: EdgeInsets.zero,
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search for Biology, History...',
                  hintStyle: _patrickHand(color: _primaryColor.withValues(alpha: 0.5)),
                  prefixIcon: const Icon(Icons.search, color: _primaryColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                style: _patrickHand(fontSize: 18),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: FutureBuilder<List<SubjectModel>>(
              future: PastPaperRepository().getSubjects(curriculum: _selectedCurriculum),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _primaryColor));
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading subjects', style: _patrickHand()));
                }

                final subjects = snapshot.data ?? [];
                final filtered = subjects.where((s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

                if (filtered.isEmpty) {
                  return Center(child: Text('No subjects found', style: _patrickHand()));
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final subject = filtered[index];
                    return GestureDetector(
                      onTap: () => Navigator.pop(context, {'id': subject.id, 'name': subject.name}),
                      child: WiredCard(
                        backgroundColor: Colors.white,
                        borderColor: _primaryColor.withValues(alpha: 0.4),
                        borderWidth: 1.5,
                        padding: const EdgeInsets.all(12),
                        child: Center(
                          child: Text(
                            subject.name,
                            textAlign: TextAlign.center,
                            style: _patrickHand(fontSize: 18, fontWeight: FontWeight.bold),
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
    );
  }
}
