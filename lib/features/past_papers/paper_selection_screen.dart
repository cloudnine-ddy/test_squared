import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'data/past_paper_repository.dart';
import 'models/paper_model.dart';
import '../../core/theme/app_theme.dart';

/// Screen for selecting a specific paper for a given year
class PaperSelectionScreen extends StatefulWidget {
  final int year;
  final String subjectId;

  const PaperSelectionScreen({
    super.key,
    required this.year,
    required this.subjectId,
  });

  @override
  State<PaperSelectionScreen> createState() => _PaperSelectionScreenState();
}

class _PaperSelectionScreenState extends State<PaperSelectionScreen> {
  List<PaperModel> _papers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPapers();
  }

  Future<void> _loadPapers() async {
    final papers = await PastPaperRepository().getPapersByYear(
      widget.year,
      widget.subjectId,
    );
    if (mounted) {
      setState(() {
        _papers = papers;
        _isLoading = false;
      });
    }
  }

  Map<String, List<PaperModel>> _groupBySeason() {
    final grouped = <String, List<PaperModel>>{};
    for (var paper in _papers) {
      grouped.putIfAbsent(paper.season, () => []);
      grouped[paper.season]!.add(paper);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDeepest,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.year} Papers',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : _papers.isEmpty
              ? _buildEmptyState()
              : _buildPapersList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, color: Colors.white24, size: 64),
          const SizedBox(height: 16),
          Text(
            'No papers found for ${widget.year}',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildPapersList() {
    final seasonGroups = _groupBySeason();
    final seasons = seasonGroups.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: seasons.length,
      itemBuilder: (context, index) {
        final season = seasons[index];
        final papers = seasonGroups[season]!;

        return _buildSeasonSection(season, papers);
      },
    );
  }

  Widget _buildSeasonSection(String season, List<PaperModel> papers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            season,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...papers.map((paper) => _buildPaperTile(paper)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPaperTile(PaperModel paper) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        onTap: () {
          context.push('/paper/${paper.id}');
        },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            paper.paperType == 'objective' ? Icons.quiz : Icons.edit_document,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          paper.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          paper.paperType == 'objective' ? 'Objective' : 'Subjective',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
      ),
    );
  }
}
