import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'data/past_paper_repository.dart';
import 'models/paper_model.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/wired/wired_widgets.dart';

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

  // Sketchy Theme Colors
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
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.year} Papers',
          style: _patrickHand(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    'Loading papers...',
                    style: _patrickHand(
                      fontSize: 16,
                      color: _primaryColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            )
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
          Icon(
            Icons.description_outlined,
            color: _primaryColor.withValues(alpha: 0.3),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No papers found for ${widget.year}',
            style: _patrickHand(
              fontSize: 18,
              color: _primaryColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPapersList() {
    final seasonGroups = _groupBySeason();
    final seasons = seasonGroups.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(24),
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
        // Season header with sketchy style
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
          child: Row(
            children: [
              WiredCard(
                backgroundColor: Colors.white,
                borderColor: _primaryColor.withValues(alpha: 0.4),
                borderWidth: 2,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  season,
                  style: _patrickHand(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: WiredDivider(
                  color: _primaryColor.withValues(alpha: 0.2),
                  thickness: 1.5,
                ),
              ),
            ],
          ),
        ),
        ...papers.map((paper) => _buildPaperTile(paper)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPaperTile(PaperModel paper) {
    final isObjective = paper.paperType == 'objective';
    final iconColor = isObjective ? Colors.blue : Colors.purple;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.push('/paper/${paper.id}');
        },
        borderRadius: BorderRadius.circular(8),
        child: WiredCard(
          backgroundColor: Colors.white,
          borderColor: _primaryColor.withValues(alpha: 0.25),
          borderWidth: 2,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon badge
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  isObjective ? Icons.quiz_outlined : Icons.edit_document,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Paper info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paper.displayName,
                      style: _patrickHand(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isObjective ? 'Objective' : 'Subjective',
                            style: _patrickHand(
                              fontSize: 12,
                              color: iconColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Arrow
              Icon(
                Icons.chevron_right,
                color: _primaryColor.withValues(alpha: 0.4),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
