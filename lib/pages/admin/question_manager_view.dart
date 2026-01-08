import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/toast_service.dart';
import 'question_editor.dart';
import 'pdf_preview_dialog.dart';

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
        backgroundColor: AppColors.sidebar,
        title: const Text('Delete Paper', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Delete "$paperLabel" and all its questions?\nThis cannot be undone.',
          style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.7)),
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
        backgroundColor: AppColors.sidebar,
        title: const Text('Delete Question', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Delete this question? This cannot be undone.',
          style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.7)),
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

  void _navigateToQuestion(String questionId) {
    setState(() {
      _selectedQuestionId = questionId;
      // Also update selected paper if needed
      for (final paperId in _questionsByPaper.keys) {
        if (_questionsByPaper[paperId]?.any((q) => q['id'] == questionId) == true) {
          _selectedPaperId = paperId;
          break;
        }
      }
    });
  }

  void _navigateRelative(int offset) {
    if (_selectedPaperId == null || _selectedQuestionId == null) return;
    
    final questions = _questionsByPaper[_selectedPaperId] ?? [];
    // Sort by question number
    questions.sort((a, b) => (a['question_number'] as int).compareTo(b['question_number'] as int));
    
    final currentIndex = questions.indexWhere((q) => q['id'] == _selectedQuestionId);
    if (currentIndex == -1) return;
    
    final newIndex = currentIndex + offset;
    if (newIndex >= 0 && newIndex < questions.length) {
      _navigateToQuestion(questions[newIndex]['id']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // LEFT SIDEBAR (Navigation)
          Container(
            width: 320,
            decoration: BoxDecoration(
              color: AppColors.sidebar,
              border: Border(right: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                // Sidebar Header (Subject Filter)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Question Manager', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedSubjectId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Subject',
                          labelStyle: const TextStyle(color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        ),
                        items: _subjects.map((s) => DropdownMenuItem(value: s['id']?.toString(), child: Text(s['name'] ?? 'Unknown', overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary)))).toList(),
                        onChanged: (v) {
                          setState(() {
                            _selectedSubjectId = v;
                            _selectedPaperId = null; 
                          });
                        },
                      ),
                    ],
                  ),
                ),
                
                // Paper List
                Expanded(
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : _buildPaperList(),
                ),
              ],
            ),
          ),
          
          // RIGHT MAIN CONTENT (Editor)
          Expanded(
            child: _selectedQuestionId != null && _selectedPaperId != null
                ? Column(
                    children: [
                      // Fast Navigation Bar
                      Container(
                        height: 60,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border(bottom: BorderSide(color: AppColors.border)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _getPaperLabel(_selectedPaperId!),
                              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => _navigateRelative(-1),
                              icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
                              tooltip: 'Previous Question',
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () => _navigateRelative(1),
                              icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
                              tooltip: 'Next Question',
                            ),
                          ],
                        ),
                      ),
                      // Editor
                      Expanded(
                        child: QuestionEditor(
                          key: ValueKey(_selectedQuestionId),
                          questionId: _selectedQuestionId!,
                          paperId: _selectedPaperId!,
                          onClose: () => setState(() => _selectedQuestionId = null),
                          onDelete: () => _deleteQuestion(_selectedQuestionId!),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_back, size: 48, color: AppColors.textPrimary.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        Text('Select a question from the sidebar', style: TextStyle(color: AppColors.textPrimary.withOpacity(0.5), fontSize: 18)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredPapers() {
    if (_selectedSubjectId == null) return [];
    return _papersBySubject[_selectedSubjectId] ?? [];
  }

  String _getPaperLabel(String paperId) {
    // Helper to find paper name
    if (_selectedSubjectId == null) return 'Unknown Paper';
    final papers = _papersBySubject[_selectedSubjectId] ?? [];
    final paper = papers.firstWhere((p) => p['id'] == paperId, orElse: () => {});
    if (paper.isEmpty) return 'Unknown Paper';
    return '${paper['year']} ${paper['season']} V${paper['variant']}';
  }

  Widget _buildPaperList() {
    final papers = _getFilteredPapers();
    if (papers.isEmpty) {
      return const Center(child: Text('No papers found', style: TextStyle(color: AppColors.textSecondary)));
    }

    return ListView.builder(
      itemCount: papers.length,
      itemBuilder: (context, index) {
        final paper = papers[index];
        final paperId = paper['id'] as String;
        final questions = _questionsByPaper[paperId] ?? [];
        // Sort questions
        questions.sort((a, b) => (a['question_number'] as int).compareTo(b['question_number'] as int));

        final isActive = _selectedPaperId == paperId;

        return ExpansionTile(
          initiallyExpanded: isActive,
          maintainState: true,
          collapsedIconColor: AppColors.textSecondary,
          iconColor: AppColors.primary,
          backgroundColor: AppColors.background.withValues(alpha: 0.5),
          title: Text(
            '${paper['year']} ${paper['season']} V${paper['variant']}',
            style: TextStyle(
              color: isActive ? Colors.blueAccent : AppColors.textPrimary,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            '${questions.length} Questions',
            style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7), fontSize: 12),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: questions.map((q) {
                  final isSelected = _selectedQuestionId == q['id'];
                  final hasImage = q['image_url'] != null;
                  
                  return InkWell(
                    onTap: () => _navigateToQuestion(q['id']),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : (hasImage ? Colors.green.withValues(alpha: 0.2) : AppColors.surface),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : (hasImage ? Colors.green : AppColors.border),
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${q['question_number']}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}
