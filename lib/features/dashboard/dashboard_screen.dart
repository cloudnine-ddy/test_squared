import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../past_papers/data/past_paper_repository.dart';
import '../past_papers/models/subject_model.dart';
import 'subject_detail_view.dart';
import 'widgets/dashboard_empty_state.dart';
import 'widgets/explore_subjects_sheet.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final bool previewMode;
  final String? initialSubjectId;
  final String? initialSubjectName;
  final String curriculum;

  const DashboardScreen({
    super.key,
    this.previewMode = false,
    this.initialSubjectId,
    this.initialSubjectName,
    this.curriculum = 'IGCSE',
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _selectedSubjectName;
  String? _selectedSubjectId;
  List<SubjectModel> _pinnedSubjects = [];

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
    // If curriculum changed, clear the subject selection
    if (widget.curriculum != oldWidget.curriculum) {
      setState(() {
        _selectedSubjectId = widget.initialSubjectId;
        _selectedSubjectName = widget.initialSubjectName;
      });
      _loadPinnedSubjects();
    } else if (widget.initialSubjectId != oldWidget.initialSubjectId) {
      setState(() {
        _selectedSubjectId = widget.initialSubjectId;
        _selectedSubjectName = widget.initialSubjectName;
      });
    }
  }

  Future<void> _loadPinnedSubjects() async {
    try {
      final subjects = await PastPaperRepository().getPinnedSubjects();
      if (context.mounted) {
        setState(() {
          _pinnedSubjects = subjects;
        });
      }
    } catch (e) {
      // ignore
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
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => ExploreSubjectsSheet(curriculum: widget.curriculum),
    );

    if (result != null && context.mounted) {
      setState(() {
        _selectedSubjectId = result['id'];
        _selectedSubjectName = result['name'];
      });
    }
  }
}
