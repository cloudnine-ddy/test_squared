import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../past_papers/data/past_paper_repository.dart';
import '../past_papers/models/subject_model.dart';
import '../../shared/wired/wired_widgets.dart';
import 'dashboard_shell.dart';
import 'subject_detail_view.dart';
import 'widgets/dashboard_empty_state.dart';
import 'widgets/explore_subjects_sheet.dart';

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
    try {
      final subjects = await PastPaperRepository().getPinnedSubjects(
        curriculum: DashboardShell.currentCurriculum,
      );
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16, right: 8),
        child: UnconstrainedBox(
          child: WiredButton(
            onPressed: _openFeedbackForm,
            backgroundColor: const Color(0xFFFFF8E7),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.feedback_outlined, color: _primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Feedback',
                  style: _patrickHand(fontSize: 16, color: _primaryColor),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Future<void> _openFeedbackForm() async {
    final Uri feedbackUrl = Uri.parse('https://forms.gle/pfpDBqyR2fKqd5qz6');
    if (await canLaunchUrl(feedbackUrl)) {
      await launchUrl(feedbackUrl, mode: LaunchMode.externalApplication);
    }
  }

  void _showSubjectSelector(BuildContext context) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const ExploreSubjectsSheet(curriculum: 'IGCSE'),
    );

    if (result != null && context.mounted) {
      setState(() {
        _selectedSubjectId = result['id'];
        _selectedSubjectName = result['name'];
      });
    }
  }
}
