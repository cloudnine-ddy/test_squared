import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../features/past_papers/question_detail_screen.dart';
import '../../features/past_papers/models/topic_model.dart';

/// Admin Question Preview View
/// Allows admins to browse and preview questions as students would see them
class AdminQuestionPreviewView extends StatefulWidget {
  const AdminQuestionPreviewView({super.key});

  @override
  State<AdminQuestionPreviewView> createState() => _AdminQuestionPreviewViewState();
}

class _AdminQuestionPreviewViewState extends State<AdminQuestionPreviewView> {
  final _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _subjects = [];
  String? _selectedSubjectId;
  List<TopicModel> _topics = [];
  String? _selectedTopicId;
  List<Map<String, dynamic>> _questions = [];
  String? _selectedQuestionId;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    try {
      final res = await _supabase
          .from('subjects')
          .select('id, name')
          .order('name');
      
      if (mounted) {
        setState(() {
          _subjects = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading subjects: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTopics(String subjectId) async {
    setState(() {
      _selectedSubjectId = subjectId;
      _selectedTopicId = null;
      _selectedQuestionId = null;
      _topics = [];
      _questions = [];
    });

    try {
      final res = await _supabase
          .from('topics')
          .select('id, name, subject_id')
          .eq('subject_id', subjectId)
          .order('name');
      
      if (mounted) {
        setState(() {
          _topics = (res as List).map((t) => TopicModel.fromMap(t)).toList();
        });
      }
    } catch (e) {
      print('Error loading topics: $e');
    }
  }

  Future<void> _loadQuestions(String topicId) async {
    setState(() {
      _selectedTopicId = topicId;
      _selectedQuestionId = null;
      _questions = [];
    });

    try {
      final res = await _supabase
          .from('questions')
          .select('id, question_number, content, type, marks, topic_id')
          .eq('topic_id', topicId)
          .order('question_number');
      
      if (mounted) {
        setState(() {
          _questions = List<Map<String, dynamic>>.from(res);
        });
      }
    } catch (e) {
      print('Error loading questions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left sidebar - Navigation
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: AppColors.sidebar,
            border: Border(right: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.visibility, color: Colors.cyan, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Student Preview',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Browse questions as students see them',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Subject Dropdown
              Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<String>(
                  value: _selectedSubjectId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Select Subject',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  dropdownColor: AppColors.surface,
                  items: _subjects.map((s) => DropdownMenuItem(
                    value: s['id']?.toString(),
                    child: Text(
                      s['name'] ?? 'Unknown',
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  )).toList(),
                  onChanged: (v) {
                    if (v != null) _loadTopics(v);
                  },
                ),
              ),
              
              // Topics and Questions List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _selectedSubjectId == null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.school_outlined, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.3)),
                                const SizedBox(height: 12),
                                Text('Select a subject to start', style: TextStyle(color: AppColors.textSecondary)),
                              ],
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            children: [
                              // Topics Section
                              if (_topics.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'TOPICS',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                ..._topics.map((topic) => _buildTopicTile(topic)),
                              ],
                              
                              // Questions Section (when topic selected)
                              if (_selectedTopicId != null && _questions.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'QUESTIONS',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _questions.map((q) => _buildQuestionChip(q)).toList(),
                                ),
                              ],
                            ],
                          ),
              ),
              
              // Info Footer
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.1),
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.cyan),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Preview mode - no progress recorded',
                        style: TextStyle(color: Colors.cyan, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Right side - Question Preview
        Expanded(
          child: _selectedQuestionId != null
              ? QuestionDetailScreen(
                  key: ValueKey(_selectedQuestionId),
                  questionId: _selectedQuestionId!,
                  topicId: _selectedTopicId,
                  previewMode: true, // Enable preview mode!
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.preview_rounded,
                              size: 64,
                              color: Colors.cyan.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Select a question to preview',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Browse like a student would',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildTopicTile(TopicModel topic) {
    final isSelected = _selectedTopicId == topic.id;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _loadQuestions(topic.id),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? Colors.cyan.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected ? Border.all(color: Colors.cyan.withValues(alpha: 0.3)) : null,
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.folder_open : Icons.folder_outlined,
                  color: isSelected ? Colors.cyan : AppColors.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    topic.name,
                    style: TextStyle(
                      color: isSelected ? Colors.cyan : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionChip(Map<String, dynamic> q) {
    final isSelected = _selectedQuestionId == q['id'];
    final type = q['type']?.toString().toLowerCase() ?? 'structured';
    final isMcq = type == 'mcq';
    
    return Tooltip(
      message: 'Q${q['question_number']} • ${isMcq ? 'MCQ' : 'Structured'} • ${q['marks'] ?? '?'} marks',
      child: InkWell(
        onTap: () => setState(() => _selectedQuestionId = q['id']),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isSelected ? Colors.cyan : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.cyan : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected ? [
              BoxShadow(
                color: Colors.cyan.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '${q['question_number']}',
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
