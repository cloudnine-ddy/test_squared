import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import 'data/past_paper_repository.dart';
import 'models/question_model.dart';
import 'package:url_launcher/url_launcher.dart';

/// Admin Debug Screen - Web-compatible version
class PaperDebugScreen extends StatefulWidget {
  final String paperId;

  const PaperDebugScreen({
    super.key,
    required this.paperId,
  });

  @override
  State<PaperDebugScreen> createState() => _PaperDebugScreenState();
}

class _PaperDebugScreenState extends State<PaperDebugScreen> {
  final _repository = PastPaperRepository();
  
  List<QuestionModel> _questions = [];
  String? _pdfUrl;
  
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final questions = await _repository.getQuestionsByPaper(widget.paperId);
      final paper = await _repository.getPaperById(widget.paperId);
      
      if (paper == null) {
        setState(() {
          _error = 'Paper not found';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _questions = questions;
        _pdfUrl = paper['pdf_url'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  Map<int, List<QuestionModel>> _groupQuestionsByPage() {
    final Map<int, List<QuestionModel>> grouped = {};
    
    for (final question in _questions) {
      final boundingBox = question.boundingBoxMap;
      if (boundingBox != null && boundingBox['page'] != null) {
        final page = boundingBox['page'] as int;
        grouped.putIfAbsent(page, () => []).add(question);
      }
    }
    
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.sidebar,
          title: const Text('Debug: Loading...', style: TextStyle(color: AppColors.textPrimary)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.sidebar,
          title: const Text('Debug: Error', style: TextStyle(color: AppColors.textPrimary)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      );
    }

    final questionsByPage = _groupQuestionsByPage();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.sidebar,
        title: Text(
          'Debug: ${_questions.firstOrNull?.paperLabel ?? "Paper"}',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          if (_pdfUrl != null)
            TextButton.icon(
              onPressed: () => _openPdfInNewTab(_pdfUrl!),
              icon: const Icon(Icons.open_in_new, color: AppColors.textSecondary),
              label: const Text('Open PDF', style: TextStyle(color: AppColors.textSecondary)),
            ),
          Chip(
            label: Text('${_questions.length} Questions'),
            backgroundColor: AppColors.primary.withOpacity(0.2),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: questionsByPage.isEmpty
          ? const Center(
              child: Text(
                'No questions with bounding boxes found',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: questionsByPage.length,
              itemBuilder: (context, index) {
                final pageNum = questionsByPage.keys.toList()..sort();
                final page = pageNum[index];
                final questions = questionsByPage[page]!;
                return _buildPageInfoCard(page, questions);
              },
            ),
    );
  }

  Future<void> _openPdfInNewTab(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildPageInfoCard(int pageNum, List<QuestionModel> questions) {
    return Card(
      color: AppColors.sidebar,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.3),
                        AppColors.primary.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Page $pageNum',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${questions.length} question(s) with bounding boxes',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),
            
            // Question Details
            ...questions.map((question) {
              final box = question.boundingBoxMap;
              if (box == null) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.red.withOpacity(0.15),
                      Colors.red.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3), width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Q${question.questionNumber}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.crop_free, color: Colors.red, size: 20),
                        const SizedBox(width: 6),
                        const Text(
                          'Bounding Box',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Coordinates Grid
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          _buildCoordRow('Position', 'x: ${_formatCoord(box['x'])}, y: ${_formatCoord(box['y'])}'),
                          const SizedBox(height: 8),
                          _buildCoordRow('Size', 'width: ${_formatCoord(box['width'])}, height: ${_formatCoord(box['height'])}'),
                          const SizedBox(height: 8),
                          _buildCoordRow('Page Size', '${box['page_width']} × ${box['page_height']} pts'),
                        ],
                      ),
                    ),
                    
                    // Question Preview
                    if (question.content.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Content Preview:',
                        style: TextStyle(
                          color: AppColors.textPrimary.withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        question.content.length > 100 
                            ? '${question.content.substring(0, 100)}...'
                            : question.content,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCoordRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textPrimary.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  String _formatCoord(dynamic value) {
    if (value == null) return 'null';
    if (value is num) {
      return value.toStringAsFixed(2);
    }
    // Try to parse as number
    final numValue = num.tryParse(value.toString());
    if (numValue != null) {
      return numValue.toStringAsFixed(2);
    }
    return value.toString();
  }
}
