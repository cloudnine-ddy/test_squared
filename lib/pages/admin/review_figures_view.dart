import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/toast_service.dart';
import 'figure_crop_editor.dart';

/// View for reviewing and adjusting figure crops for questions
class ReviewFiguresView extends StatefulWidget {
  const ReviewFiguresView({super.key});

  @override
  State<ReviewFiguresView> createState() => _ReviewFiguresViewState();
}

class _ReviewFiguresViewState extends State<ReviewFiguresView> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _questionsWithFigures = [];
  bool _isLoading = true;
  String? _selectedQuestionId;

  @override
  void initState() {
    super.initState();
    _fetchQuestionsWithFigures();
  }

  Future<void> _fetchQuestionsWithFigures() async {
    setState(() => _isLoading = true);
    
    try {
      // Fetch questions that have figure info in ai_answer field
      final response = await _supabase
          .from('questions')
          .select('''
            id,
            question_number,
            content,
            image_url,
            ai_answer,
            paper:papers!inner(
              id,
              year,
              season,
              variant,
              pdf_url
            )
          ''')
          .not('ai_answer', 'is', null)
          .order('question_number', ascending: true);
      
      final questions = List<Map<String, dynamic>>.from(response);
      
      // Filter to only questions with figure info
      final withFigures = questions.where((q) {
        final aiAnswer = q['ai_answer'];
        return aiAnswer != null && 
               aiAnswer is Map && 
               aiAnswer['has_figure'] == true;
      }).toList();
      
      if (mounted) {
        setState(() {
          _questionsWithFigures = withFigures;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ToastService.showError('Failed to load questions: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _openCropEditor(Map<String, dynamic> question) {
    setState(() => _selectedQuestionId = question['id']);
  }

  void _closeCropEditor() {
    setState(() => _selectedQuestionId = null);
    _fetchQuestionsWithFigures(); // Refresh after editing
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedQuestionId != null) {
      final question = _questionsWithFigures.firstWhere(
        (q) => q['id'] == _selectedQuestionId,
      );
      return FigureCropEditor(
        question: question,
        onClose: _closeCropEditor,
      );
    }

    return Container(
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Icon(
                  Icons.crop_original,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Review Figure Crops',
                  style: TextStyle(
                    color: AppColors.textPrimary.withValues(alpha: 0.9),
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // Refresh button
                IconButton(
                  onPressed: _fetchQuestionsWithFigures,
                  icon: Icon(
                    Icons.refresh,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          
          // Stats bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildStatChip(
                  'Total Figures',
                  _questionsWithFigures.length.toString(),
                  Colors.blue,
                ),
                const SizedBox(width: 12),
                _buildStatChip(
                  'With Images',
                  _questionsWithFigures.where((q) => q['image_url'] != null).length.toString(),
                  Colors.green,
                ),
                const SizedBox(width: 12),
                _buildStatChip(
                  'Pending',
                  _questionsWithFigures.where((q) => q['image_url'] == null).length.toString(),
                  Colors.orange,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _questionsWithFigures.isEmpty
                    ? _buildEmptyState()
                    : _buildQuestionsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textPrimary.withValues(alpha: 0.7),
              fontSize: 13,
            ),
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
            Icons.image_not_supported_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No figures to review',
            style: TextStyle(
              color: AppColors.textPrimary.withValues(alpha: 0.5),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload a PDF with figures to get started',
            style: TextStyle(
              color: AppColors.textPrimary.withValues(alpha: 0.3),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _questionsWithFigures.length,
      itemBuilder: (context, index) {
        final question = _questionsWithFigures[index];
        return _buildQuestionCard(question);
      },
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question) {
    final paper = question['paper'] as Map<String, dynamic>?;
    final aiAnswer = question['ai_answer'] as Map<String, dynamic>?;
    final figureLocation = aiAnswer?['figure_location'] as Map<String, dynamic>?;
    final hasImage = question['image_url'] != null;
    
    final paperInfo = paper != null
        ? '${paper['year']} ${paper['season']} V${paper['variant']}'
        : 'Unknown Paper';
    
    return Card(
      color: AppColors.sidebar,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasImage 
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        onTap: () => _openCropEditor(question),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Thumbnail or placeholder
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: hasImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          question['image_url'],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.broken_image,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      )
                    : Icon(
                        Icons.crop,
                        color: Colors.white.withValues(alpha: 0.3),
                        size: 32,
                      ),
              ),
              const SizedBox(width: 16),
              
              // Question info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Q${question['question_number']}',
                            style: const TextStyle(
                              color: Color(0xFF818CF8),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          paperInfo,
                          style: TextStyle(
                            color: AppColors.textPrimary.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: hasImage
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            hasImage ? 'Cropped' : 'Pending',
                            style: TextStyle(
                              color: hasImage ? Colors.green : Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      question['content']?.toString().substring(
                            0,
                            (question['content']?.toString().length ?? 0) > 100
                                ? 100
                                : question['content']?.toString().length ?? 0,
                          ) ?? 'No content',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                    if (figureLocation != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Page ${figureLocation['page']} • Position: ${figureLocation['x_percent']?.toStringAsFixed(0)}%, ${figureLocation['y_percent']?.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: AppColors.textPrimary.withValues(alpha: 0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Edit button
              Icon(
                Icons.edit,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
