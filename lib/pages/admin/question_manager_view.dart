import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/toast_service.dart';
import '../../features/past_papers/question_detail_screen.dart';
import 'question_editor.dart';
import 'pdf_preview_dialog.dart';

/// Question Manager - Organized hierarchical view of all questions
/// Navigation: Exam Type → Subject → Year → Paper → Questions
///
/// Enhanced UX Features:
/// - Keyboard shortcuts (Ctrl+S save, ↑/↓ navigate, Ctrl+G jump to question)
/// - Progress tracking with color-coded status
/// - Quick jump to question number
/// - Wider sidebar for better readability
class QuestionManagerView extends StatefulWidget {
  const QuestionManagerView({super.key});

  @override
  State<QuestionManagerView> createState() => _QuestionManagerViewState();
}

class _QuestionManagerViewState extends State<QuestionManagerView> {
  final _supabase = Supabase.instance.client;
  final _jumpController = TextEditingController();
  final _focusNode = FocusNode();

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

  // Editor callback for save
  GlobalKey<dynamic>? _editorKey;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _jumpController.dispose();
    _focusNode.dispose();
    super.dispose();
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
          .select('id, paper_id, question_number, content, image_url, ai_answer, type')
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

      if (mounted) {
        ToastService.showInfo('Deleting paper... this may take a moment.');
      }

      // Call Edge Function to handle cascading delete (Storage + DB)
      final response = await _supabase.functions.invoke(
        'delete-paper',
        body: {'paperId': paperId},
      );

      print('Edge function response: ${response.data}');

      if (!mounted) return;

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
      // 1. First fetch the question to get image_url
      final questionData = await _supabase
          .from('questions')
          .select('image_url')
          .eq('id', questionId)
          .single();

      final imageUrl = questionData['image_url'] as String?;

      // 2. Delete image from Storage if exists
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          // Extract path from URL: .../storage/v1/object/public/exam-papers/PATH
          final uri = Uri.parse(imageUrl);
          final pathSegments = uri.path.split('/exam-papers/');
          if (pathSegments.length > 1) {
            final storagePath = Uri.decodeComponent(pathSegments[1]);
            print('[Delete] Removing image from storage: $storagePath');
            await _supabase.storage.from('exam-papers').remove([storagePath]);
          }
        } catch (e) {
          print('[Delete] Warning: Could not delete image from storage: $e');
          // Continue with DB deletion anyway
        }
      }

      // 3. Delete from database
      await _supabase.from('questions').delete().eq('id', questionId);
      ToastService.showSuccess('Question deleted!');
      if (mounted && _selectedQuestionId == questionId) {
        setState(() => _selectedQuestionId = null);
      }
      _loadData();
    } catch (e) {
      ToastService.showError('Delete failed: $e');
    }
  }

  Future<void> _createNewQuestion(String paperId) async {
    setState(() => _isLoading = true);
    try {
      // 1. Find the next question number
      final existingQuestions = _questionsByPaper[paperId] ?? [];
      int maxNum = 0;
      for (final q in existingQuestions) {
        final num = q['question_number'] as int? ?? 0;
        if (num > maxNum) maxNum = num;
      }
      final nextNum = maxNum + 1;

      // 2. Insert new placeholder question
      // We insert minimal required fields. The DB will handle ID generation.
      final res = await _supabase.from('questions').insert({
        'paper_id': paperId,
        'question_number': nextNum,
        'content': 'New Question $nextNum', // Placeholder content
        'type': 'mcq', // Default to MCQ
        'marks': 1,
        'topic_ids': [], // Required array field
        'official_answer': '', // Required text field
        'options': [], // Required for MCQ constraint
        'ai_answer': {'has_figure': false}, // Basic JSON to prevent null errors
      }).select().single();

      final newQuestionId = res['id'] as String;

      // 3. Refresh and Navigate
      await _loadData(); // Reloads all questions including the new one

      if (mounted) {
        _navigateToQuestion(newQuestionId); // Open editor for the new question
        ToastService.showSuccess('Created Question $nextNum');
      }

    } catch (e) {
      ToastService.showError('Failed to create question: $e');
      setState(() => _isLoading = false); // Ensure loading is cleared on error
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

  void _jumpToQuestionNumber(int qNum) {
    if (_selectedPaperId == null) {
      ToastService.showError('Please select a paper first');
      return;
    }

    final questions = _questionsByPaper[_selectedPaperId] ?? [];
    final target = questions.firstWhere(
      (q) => q['question_number'] == qNum,
      orElse: () => {},
    );

    if (target.isNotEmpty) {
      _navigateToQuestion(target['id']);
      _jumpController.clear();
    } else {
      ToastService.showError('Question $qNum not found');
    }
  }

  // Get progress stats for current paper
  Map<String, int> _getProgressStats() {
    if (_selectedPaperId == null) return {'total': 0, 'withImage': 0, 'edited': 0};

    final questions = _questionsByPaper[_selectedPaperId] ?? [];
    int withImage = 0;
    int edited = 0;

    for (final q in questions) {
      if (q['image_url'] != null) withImage++;
      final content = q['content']?.toString() ?? '';
      if (content.isNotEmpty) edited++;
    }

    return {
      'total': questions.length,
      'withImage': withImage,
      'edited': edited,
    };
  }

  // Keyboard shortcut handler
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isCtrl = HardwareKeyboard.instance.isControlPressed;

    // Ctrl+S - Save (handled by editor)
    // We just show a toast here as a fallback
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyS) {
      // The editor handles its own save
      return KeyEventResult.handled;
    }

    // Arrow Up/Down - Navigate questions
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _navigateRelative(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _navigateRelative(1);
      return KeyEventResult.handled;
    }

    // Ctrl+G - Focus jump input
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyG) {
      // Focus the jump input
      FocusScope.of(context).requestFocus(FocusNode());
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final stats = _getProgressStats();

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            // LEFT SIDEBAR (Navigation) - Wider for better UX
            Container(
              width: 360, // Increased from 320
              decoration: BoxDecoration(
                color: AppColors.sidebar,
                border: Border(right: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                children: [
                  // Sidebar Header (Subject Filter + Progress)
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
                            const Text('Question Manager', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            // Refresh button
                            IconButton(
                              onPressed: _loadData,
                              icon: const Icon(Icons.refresh, size: 20, color: AppColors.textSecondary),
                              tooltip: 'Refresh',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
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

                        // Quick Jump (progress tracking removed per user request)
                        if (_selectedPaperId != null) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _jumpController,
                                  decoration: InputDecoration(
                                    hintText: 'Jump to Q#...',
                                    hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 13),
                                    filled: true,
                                    fillColor: AppColors.surface,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                                  ),
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                                  keyboardType: TextInputType.number,
                                  onSubmitted: (v) {
                                    final num = int.tryParse(v);
                                    if (num != null) _jumpToQuestionNumber(num);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () {
                                  final num = int.tryParse(_jumpController.text);
                                  if (num != null) _jumpToQuestionNumber(num);
                                },
                                icon: const Icon(Icons.arrow_forward, size: 20),
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                                tooltip: 'Jump',
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Paper List
                  Expanded(
                    child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildPaperList(),
                  ),

                  // Keyboard shortcuts hint
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.5),
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildShortcutHint('↑↓', 'Navigate'),
                        const SizedBox(width: 16),
                        _buildShortcutHint('Ctrl+S', 'Save'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // RIGHT MAIN CONTENT (Editor)
            Expanded(
              child: _selectedQuestionId != null && _selectedPaperId != null
                  ? Column(
                      children: [
                        // Fast Navigation Bar with current question info
                        Container(
                          height: 64,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            border: Border(bottom: BorderSide(color: AppColors.border)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Current question number - prominent display
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _getCurrentQuestionNumber(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _getPaperLabel(_selectedPaperId!),
                                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    _getQuestionPosition(),
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              // Preview button
                              IconButton(
                                onPressed: () => _showStudentPreview(_selectedQuestionId!),
                                icon: const Icon(Icons.visibility, color: Colors.cyan),
                                tooltip: 'Preview as Student',
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.cyan.withValues(alpha: 0.1),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Navigation buttons
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      onPressed: () => _navigateRelative(-1),
                                      icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
                                      tooltip: 'Previous (↑)',
                                    ),
                                    Container(width: 1, height: 24, color: AppColors.border),
                                    IconButton(
                                      onPressed: () => _navigateRelative(1),
                                      icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
                                      tooltip: 'Next (↓)',
                                    ),
                                  ],
                                ),
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
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.touch_app, size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
                                const SizedBox(height: 16),
                                Text(
                                  'Select a question from the sidebar',
                                  style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.7), fontSize: 18),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Use ↑↓ keys to navigate between questions',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 10)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _buildShortcutHint(String shortcut, String action) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(shortcut, style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
        ),
        const SizedBox(width: 4),
        Text(action, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }

  String _getCurrentQuestionNumber() {
    if (_selectedQuestionId == null || _selectedPaperId == null) return '?';
    final questions = _questionsByPaper[_selectedPaperId] ?? [];
    final q = questions.firstWhere((q) => q['id'] == _selectedQuestionId, orElse: () => {});
    return q['question_number']?.toString() ?? '?';
  }

  String _getQuestionPosition() {
    if (_selectedQuestionId == null || _selectedPaperId == null) return '';
    final questions = _questionsByPaper[_selectedPaperId] ?? [];
    questions.sort((a, b) => (a['question_number'] as int).compareTo(b['question_number'] as int));
    final idx = questions.indexWhere((q) => q['id'] == _selectedQuestionId);
    if (idx == -1) return '';
    return 'Question ${idx + 1} of ${questions.length}';
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            const Text('No papers found', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text('Select a subject above', style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7), fontSize: 12)),
          ],
        ),
      );
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
        final questionsWithImage = questions.where((q) => q['image_url'] != null).length;

        return ExpansionTile(
          initiallyExpanded: isActive,
          maintainState: true,
          collapsedIconColor: AppColors.textSecondary,
          iconColor: AppColors.primary,
          backgroundColor: AppColors.background.withValues(alpha: 0.5),
          onExpansionChanged: (expanded) {
            if (expanded) {
              setState(() => _selectedPaperId = paperId);
            }
          },
          title: Text(
            '${paper['year']} ${paper['season']} V${paper['variant']}',
            style: TextStyle(
              color: isActive ? AppColors.primary : AppColors.textPrimary,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          subtitle: Row(
            children: [
              Text(
                '${questions.length} Questions',
                style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7), fontSize: 12),
              ),
              if (questionsWithImage > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '✓ $questionsWithImage',
                    style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add Question Button
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20, color: AppColors.primary),
                onPressed: () => _createNewQuestion(paperId),
                tooltip: 'Add Question',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                onPressed: () => _deletePaper(paperId, '${paper['year']} ${paper['season']} V${paper['variant']}'),
                tooltip: 'Delete Paper',
              ),
              const Icon(Icons.expand_more, color: AppColors.textSecondary),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: questions.map((q) {
                  final isSelected = _selectedQuestionId == q['id'];
                  final hasImage = q['image_url'] != null;
                  final isStructured = q['type'] == 'structured';

                  return Tooltip(
                    message: _getQuestionTooltip(q),
                    child: InkWell(
                      onTap: () => _navigateToQuestion(q['id']),
                      borderRadius: BorderRadius.circular(6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : (isStructured 
                                  ? Colors.purple.withValues(alpha: 0.15) 
                                  : (hasImage ? Colors.green.withValues(alpha: 0.15) : AppColors.surface)),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : (isStructured 
                                    ? Colors.purple 
                                    : (hasImage ? Colors.green : AppColors.border)),
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ] : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${q['question_number']}',
                          style: TextStyle(
                            color: isSelected 
                                ? Colors.white 
                                : (isStructured 
                                    ? Colors.purple.shade700 
                                    : (hasImage ? Colors.green.shade700 : AppColors.textPrimary)),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
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

  String _getQuestionTooltip(Map<String, dynamic> q) {
    final hasImage = q['image_url'] != null;
    final content = q['content']?.toString() ?? '';
    final preview = content.length > 50 ? '${content.substring(0, 50)}...' : content;

    return 'Q${q['question_number']}\n${hasImage ? '✓ Has image' : '○ No image'}\n${preview.isEmpty ? 'No content' : preview}';
  }

  /// Show question preview as student would see it
  void _showStudentPreview(String questionId) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: const Color(0xFFFDFBF7), // Match student view background
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header with close button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Colors.cyan.withValues(alpha: 0.2)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.visibility, color: Colors.cyan, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Student Preview',
                      style: TextStyle(
                        color: Colors.cyan.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.cyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Preview Mode',
                        style: TextStyle(
                          color: Colors.cyan.shade600,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.grey),
                      tooltip: 'Close Preview',
                    ),
                  ],
                ),
              ),
              // Question content
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  child: QuestionDetailScreen(
                    questionId: questionId,
                    previewMode: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
