import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/toast_service.dart';
import 'question_editor.dart';

/// Question Manager - Organized hierarchical view of all questions
/// Navigation: Exam Type → Subject → Year → Paper → Questions
class QuestionManagerView extends StatefulWidget {
  const QuestionManagerView({super.key});

  @override
  State<QuestionManagerView> createState() => _QuestionManagerViewState();
}

class _QuestionManagerViewState extends State<QuestionManagerView> {
  final _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  
  // Data
  List<Map<String, dynamic>> _subjects = [];
  Map<String, List<Map<String, dynamic>>> _papersBySubject = {};
  Map<String, List<Map<String, dynamic>>> _questionsByPaper = {};
  
  // Selection state
  String? _selectedSubjectId;
  String? _selectedPaperId;
  String? _selectedQuestionId;
  
  // Expansion state
  Set<String> _expandedSubjects = {};
  Set<String> _expandedPapers = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load subjects
      final subjectsRes = await _supabase
          .from('subjects')
          .select('id, name, icon_url')
          .order('name');
      
      _subjects = List<Map<String, dynamic>>.from(subjectsRes);
      
      // Load all papers with their questions count
      final papersRes = await _supabase
          .from('papers')
          .select('id, subject_id, year, season, variant, pdf_url')
          .order('year', ascending: false);
      
      _papersBySubject = {};
      for (final paper in papersRes) {
        final subjectId = paper['subject_id']?.toString() ?? '';
        _papersBySubject[subjectId] ??= [];
        _papersBySubject[subjectId]!.add(paper);
      }
      
      // Load all questions
      final questionsRes = await _supabase
          .from('questions')
          .select('id, paper_id, question_number, content, image_url, ai_answer')
          .order('question_number');
      
      _questionsByPaper = {};
      for (final q in questionsRes) {
        final paperId = q['paper_id']?.toString() ?? '';
        _questionsByPaper[paperId] ??= [];
        _questionsByPaper[paperId]!.add(q);
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ToastService.showError('Failed to load data: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _selectQuestion(String questionId, String paperId) {
    setState(() {
      _selectedQuestionId = questionId;
      _selectedPaperId = paperId;
    });
  }

  void _closeEditor() {
    setState(() => _selectedQuestionId = null);
    _loadData(); // Refresh after editing
  }

  Future<void> _deletePaper(String paperId, String paperLabel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Delete Paper', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete "$paperLabel" and all its questions?\nThis cannot be undone.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      print('Deleting paper: $paperId');
      
      // Delete questions first
      final questionsResult = await _supabase
          .from('questions')
          .delete()
          .eq('paper_id', paperId)
          .select();
      print('Deleted questions: ${questionsResult.length}');
      
      // Then delete paper
      final paperResult = await _supabase
          .from('papers')
          .delete()
          .eq('id', paperId)
          .select();
      print('Deleted papers: ${paperResult.length}');
      
      // Clear from local state
      setState(() {
        _papersBySubject.forEach((_, papers) {
          papers.removeWhere((p) => p['id'] == paperId);
        });
        _questionsByPaper.remove(paperId);
        _expandedPapers.remove(paperId);
        if (_selectedPaperId == paperId) {
          _selectedQuestionId = null;
          _selectedPaperId = null;
        }
      });
      
      ToastService.showSuccess('Paper deleted!');
    } catch (e) {
      print('Delete error: $e');
      ToastService.showError('Delete failed: $e');
    }
  }

  Future<void> _deleteQuestion(String questionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Delete Question', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete this question? This cannot be undone.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      await _supabase.from('questions').delete().eq('id', questionId);
      ToastService.showSuccess('Question deleted!');
      if (_selectedQuestionId == questionId) {
        setState(() => _selectedQuestionId = null);
      }
      _loadData();
    } catch (e) {
      ToastService.showError('Delete failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.backgroundDeepest,
      child: Row(
        children: [
          // Left panel - Tree navigation
          Container(
            width: 350,
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              border: Border(
                right: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Column(
              children: [
                _buildTreeHeader(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildTree(),
                ),
              ],
            ),
          ),
          
          // Right panel - Question editor or placeholder
          Expanded(
            child: _selectedQuestionId != null
                ? QuestionEditor(
                    key: ValueKey(_selectedQuestionId), // Force rebuild when switching
                    questionId: _selectedQuestionId!,
                    paperId: _selectedPaperId!,
                    onClose: _closeEditor,
                    onDelete: () => _deleteQuestion(_selectedQuestionId!),
                  )
                : _buildPlaceholder(),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_tree_outlined,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 12),
          Text(
            'Question Manager',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _loadData,
            icon: Icon(
              Icons.refresh,
              color: Colors.white.withValues(alpha: 0.5),
              size: 20,
            ),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildTree() {
    if (_subjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 48,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              'No subjects found',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _subjects.length,
      itemBuilder: (context, index) {
        final subject = _subjects[index];
        return _buildSubjectNode(subject);
      },
    );
  }

  Widget _buildSubjectNode(Map<String, dynamic> subject) {
    final subjectId = subject['id'] as String;
    final isExpanded = _expandedSubjects.contains(subjectId);
    final papers = _papersBySubject[subjectId] ?? [];
    final totalQuestions = papers.fold<int>(
      0, 
      (sum, p) => sum + (_questionsByPaper[p['id']]?.length ?? 0),
    );
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subject row
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedSubjects.remove(subjectId);
              } else {
                _expandedSubjects.add(subjectId);
              }
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_more : Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.science_outlined,
                  color: const Color(0xFF6366F1),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    subject['name'] ?? 'Unknown',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${papers.length}P / ${totalQuestions}Q',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Papers (if expanded)
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Column(
              children: papers.map((paper) => _buildPaperNode(paper)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildPaperNode(Map<String, dynamic> paper) {
    final paperId = paper['id'] as String;
    final isExpanded = _expandedPapers.contains(paperId);
    final questions = _questionsByPaper[paperId] ?? [];
    
    final year = paper['year'] ?? '?';
    final season = paper['season'] ?? '';
    final variant = paper['variant'] ?? '';
    final paperLabel = '$year $season V$variant';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Paper row
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedPapers.remove(paperId);
              } else {
                _expandedPapers.add(paperId);
              }
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_more : Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.description_outlined,
                  color: Colors.orange.withValues(alpha: 0.7),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    paperLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ),
                Text(
                  '${questions.length}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _deletePaper(paperId, paperLabel),
                  icon: Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: Colors.red.withValues(alpha: 0.5),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  tooltip: 'Delete paper',
                ),
              ],
            ),
          ),
        ),
        
        // Questions (if expanded)
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Column(
              children: questions.map((q) => _buildQuestionNode(q, paperId)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildQuestionNode(Map<String, dynamic> question, String paperId) {
    final questionId = question['id'] as String;
    final isSelected = _selectedQuestionId == questionId;
    final hasImage = question['image_url'] != null;
    final hasFigure = question['ai_answer']?['has_figure'] == true;
    
    // Status icon
    IconData statusIcon;
    Color statusColor;
    
    if (hasImage) {
      statusIcon = Icons.check_circle;
      statusColor = Colors.green;
    } else if (hasFigure) {
      statusIcon = Icons.warning;
      statusColor = Colors.orange;
    } else {
      statusIcon = Icons.circle_outlined;
      statusColor = Colors.grey;
    }
    
    return InkWell(
      onTap: () => _selectQuestion(questionId, paperId),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF6366F1).withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          children: [
            Icon(statusIcon, size: 14, color: statusColor),
            const SizedBox(width: 8),
            Text(
              'Q${question['question_number']}',
              style: TextStyle(
                color: isSelected 
                    ? Colors.white 
                    : Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (hasImage)
              Icon(
                Icons.image,
                size: 14,
                color: Colors.white.withValues(alpha: 0.3),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'Select a question to edit',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use the tree on the left to navigate',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
