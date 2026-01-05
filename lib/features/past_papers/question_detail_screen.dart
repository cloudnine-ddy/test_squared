import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'data/past_paper_repository.dart';
import 'models/question_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/question_image_header.dart';
import 'widgets/question_action_bar.dart';
import 'widgets/answer_reveal_sheet.dart';
import 'widgets/formatted_question_text.dart';
import '../bookmarks/widgets/bookmark_button.dart';
import '../bookmarks/screens/note_editor_dialog.dart';
import '../bookmarks/data/bookmark_repository.dart';
import '../bookmarks/data/notes_repository.dart';
import '../progress/data/progress_repository.dart';
import '../progress/models/question_attempt_model.dart';
import '../auth/providers/auth_provider.dart';
import '../../core/services/access_control_service.dart';

/// Full-page question detail view with figure and answer reveals
class QuestionDetailScreen extends ConsumerStatefulWidget {
  final String questionId;

  const QuestionDetailScreen({
    super.key,
    required this.questionId,
  });

  @override
  ConsumerState<QuestionDetailScreen> createState() => _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends ConsumerState<QuestionDetailScreen> 
    with SingleTickerProviderStateMixin {
  QuestionModel? _question;
  bool _isLoading = true;
  bool _showAiSolution = false;
  final TextEditingController _studentAnswerController = TextEditingController();
  bool _answerSubmitted = false;
  bool _isCheckingAnswer = false;
  late TabController _tabController;
  String? _selectedMcqAnswer; // For MCQ questions: 'A', 'B', 'C', or 'D'
  
  // AI Feedback
  Map<String, dynamic>? _aiFeedback;
  
  // Progress tracking
  DateTime? _questionStartTime;
  
  // Bookmark and notes
  bool _isBookmarked = false;
  bool _hasNote = false;
  final _bookmarkRepo = BookmarkRepository();
  final _notesRepo = NotesRepository();
  final _progressRepo = ProgressRepository();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _questionStartTime = DateTime.now(); // Start tracking time
    _loadQuestion();
    _loadBookmarkAndNoteStatus();
  }

  void _onTabChanged() {
    // When user taps on Official Answer tab (index 2), check if logged in
    if (_tabController.index == 2) {
      final isAuthenticated = ref.read(isAuthenticatedProvider);
      if (!isAuthenticated) {
        // Switch back to previous tab
        setState(() {
          _tabController.index = _tabController.previousIndex;
        });
        // Show login dialog
        AccessControlService.checkLogin(context, ref);
      }
    }
  }

  @override
  void dispose() {
    _studentAnswerController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestion() async {
    final question = await PastPaperRepository().getQuestionById(widget.questionId);
    if (mounted) {
      setState(() {
        _question = question;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBookmarkAndNoteStatus() async {
    try {
      final isBookmarked = await _bookmarkRepo.isBookmarked(widget.questionId);
      final hasNote = await _notesRepo.hasNote(widget.questionId);
      
      if (mounted) {
        setState(() {
          _isBookmarked = isBookmarked;
          _hasNote = hasNote;
        });
      }
    } catch (e) {
      // Silently fail - not critical
      print('Error loading bookmark/note status: $e');
    }
  }

  Future<void> _showNoteEditor() async {
    // Load existing note if any
    final existingNote = await _notesRepo.getNote(widget.questionId);
    
    if (!mounted) return;
    
    final noteText = await showDialog<String>(
      context: context,
      builder: (context) => NoteEditorDialog(
        questionId: widget.questionId,
        initialNote: existingNote?.noteText,
      ),
    );

    if (noteText != null && noteText.isNotEmpty) {
      try {
        await _notesRepo.saveNote(widget.questionId, noteText);
        _loadBookmarkAndNoteStatus(); // Refresh status
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Note saved!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save note: $e')),
          );
        }
      }
    }
  }

  Future<void> _recordAttempt() async {
    if (_question == null || _aiFeedback == null || _questionStartTime == null) return;

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final timeSpent = DateTime.now().difference(_questionStartTime!).inSeconds;
      
      final attempt = QuestionAttemptModel(
        id: '', // Will be generated by database
        userId: userId,
        questionId: _question!.id,
        answerText: _question!.isMCQ ? null : _studentAnswerController.text,
        selectedOption: _question!.isMCQ ? _selectedMcqAnswer : null,
        score: _aiFeedback!['score'],
        isCorrect: _aiFeedback!['is_correct'],
        timeSpentSeconds: timeSpent,
        hintsUsed: 0, // TODO: Track hints when AI hint feature is implemented
        attemptedAt: DateTime.now(),
      );

      await _progressRepo.recordAttempt(attempt);
      print('Progress recorded successfully');
    } catch (e) {
      print('Error recording attempt: $e');
      // Don't show error to user - this is background tracking
    }
  }

  Future<void> _checkAnswer() async {
    if (_question == null || _studentAnswerController.text.trim().isEmpty) return;
    
    // Check premium access for AI answer checking
    if (!AccessControlService.checkPremium(
      context,
      ref,
      featureName: 'AI Answer Checking',
      highlights: [
        'Instant AI-powered feedback',
        'Detailed scoring and analysis',
        'Personalized improvement hints',
        'Track your progress over time',
      ],
    )) {
      return;
    }
    
    setState(() {
      _isCheckingAnswer = true;
    });
    
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'check-answer',
        body: {
          'questionId': _question!.id,
          'questionContent': _question!.content,
          'officialAnswer': _question!.officialAnswer,
          'studentAnswer': _studentAnswerController.text.trim(),
          'marks': _question!.marks,
        },
      );
      
      if (response.status == 200 && response.data != null) {
        setState(() {
          _aiFeedback = response.data as Map<String, dynamic>;
          _answerSubmitted = true;
          _isCheckingAnswer = false;
        });
        
        // Record the attempt for progress tracking
        _recordAttempt();
      } else {
        throw Exception(response.data?['error'] ?? 'Unknown error');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingAnswer = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking answer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAnswerSheet() {
    if (_question == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AnswerRevealSheet(
        officialAnswer: _question!.officialAnswer,
        aiSolution: _question!.aiSolution,
        hasOfficialAnswer: _question!.hasOfficialAnswer,
        hasAiSolution: _question!.hasAiSolution,
      ),
    );
  }

  Future<void> _showAiExplainDialog() async {
    // Check premium access
    if (!AccessControlService.checkPremium(
      context,
      ref,
      featureName: 'AI Explanation',
      highlights: [
        'Get step-by-step explanations',
        'Understand key concepts deeply',
        'Learn from AI-powered insights',
        'Improve faster with guided learning',
      ],
    )) {
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.psychology, color: Colors.cyan),
            const SizedBox(width: 12),
            const Text('AI Explanation', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This feature will use AI to provide additional explanation for the question context and concepts.',
                style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.cyan.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.cyan, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This specific feature is coming soon!',
                        style: TextStyle(color: Colors.cyan.shade200, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _toggleAiSolution() {
    setState(() {
      _showAiSolution = !_showAiSolution;
    });
  }

  void _showFullFigure() {
    if (_question?.imageUrl == null) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            // Image with zoom
            Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    _question!.imageUrl!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const CircularProgressIndicator(
                  color: Colors.blue,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Loading question...',
                style: TextStyle(
                  color: AppColors.textPrimary.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_question == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red.withValues(alpha: 0.5), size: 48),
              const SizedBox(height: 16),
              const Text('Question not found', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background gradient
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.blue.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.purple.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          // Main content
          CustomScrollView(
            slivers: [
              // Simple App Bar (no figure)
              SliverAppBar(
                backgroundColor: AppColors.background,
                floating: false,
                pinned: true,
                elevation: 0,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: GestureDetector(
                    onTap: () {
                      if (GoRouter.of(context).canPop()) {
                        GoRouter.of(context).pop();
                      } else {
                        GoRouter.of(context).go('/dashboard');
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, color: AppColors.textSecondary, size: 18),
                    ),
                  ),
                ),
                actions: [
                  // Note button with indicator
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: _hasNote
                              ? const LinearGradient(
                                  colors: [Color(0xFF2979FF), Color(0xFF2962FF)], // Brighter Blue
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : LinearGradient(
                                  colors: [
                                    const Color(0xFF384050), // Much Lighter Grey
                                    const Color(0xFF2B3240)
                                  ], 
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _hasNote
                                ? Colors.white.withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                          boxShadow: [
                            if (_hasNote)
                              BoxShadow(
                                color: Colors.blueAccent.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            _hasNote ? Icons.note_alt_rounded : Icons.note_add_outlined,
                            color: _hasNote ? Colors.white : Colors.white,
                            size: 22,
                          ),
                          onPressed: _showNoteEditor,
                          tooltip: 'Add note',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                      if (_hasNote)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Color(0xFF1E232F), // Match bg to create cutout effect
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.amber, // Keep amber dot for attention
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Bookmark button
                  BookmarkButton(
                    questionId: widget.questionId,
                    initialIsBookmarked: _isBookmarked,
                    onChanged: _loadBookmarkAndNoteStatus,
                  ),
                  const SizedBox(width: 8),
                  if (_question?.marks != null)
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFB300), // Amber 600
                            Color(0xFFFFCA28), // Amber 400
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                           BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFF232832), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '${_question!.marks} marks',
                            style: const TextStyle(
                              color: Color(0xFF232832), // Dark text on bright background
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              // Question Header Card (MOVED BEFORE FIGURE)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Question number badge
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Question ${_question!.questionNumber}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (_question!.hasPaperInfo)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _question!.paperLabel,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Question content
                        FormattedQuestionText(
                          content: _question!.content,
                          fontSize: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Figure Card (MOVED AFTER QUESTION TEXT, with zoom)
              if (_question!.hasFigure)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: GestureDetector(
                      onTap: () => _showFullFigure(),
                      child: Container(
                        constraints: BoxConstraints(
                          maxHeight: 300, // Limit height
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Figure label
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.image_outlined, color: Colors.blue.withValues(alpha: 0.7), size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Figure',
                                    style: TextStyle(
                                      color: AppColors.textPrimary.withValues(alpha: 0.7),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(Icons.zoom_in, color: Colors.white.withValues(alpha: 0.7), size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Tap to zoom',
                                    style: TextStyle(
                                      color: AppColors.textPrimary.withValues(alpha: 0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Figure image (tap for fullscreen zoom)
                            Flexible(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                                child: Image.network(
                                  _question!.imageUrl!,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Tabbed Answer Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildTabbedCard(),
                ),
              ),

              // Extra space at bottom
              const SliverToBoxAdapter(
                child: SizedBox(height: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabbedCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tab Bar
          Container(
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
              dividerColor: Colors.transparent,
              tabs: [
                Tab(
                  icon: Icon(
                    _answerSubmitted ? Icons.check_circle : Icons.edit_note,
                    size: 20,
                    color: _answerSubmitted ? Colors.green : null,
                  ),
                  text: 'Your Answer',
                ),
                const Tab(
                  icon: Icon(Icons.verified_outlined, size: 20),
                  text: 'Official',
                ),
                const Tab(
                  icon: Icon(Icons.auto_awesome, size: 20),
                  text: 'AI Explanation',
                ),
              ],
            ),
          ),
          
          // Tab Content
          SizedBox(
            height: 450, // Increased height to show retry button
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAnswerTab(),
                _buildOfficialAnswerTab(),
                _buildAiSolutionTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score badge if submitted
          if (_aiFeedback != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: (_aiFeedback!['isCorrect'] ?? false)
                      ? [Colors.green.withValues(alpha: 0.2), Colors.green.withValues(alpha: 0.1)]
                      : [Colors.orange.withValues(alpha: 0.2), Colors.orange.withValues(alpha: 0.1)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    (_aiFeedback!['isCorrect'] ?? false) ? Icons.check_circle : Icons.info_outline,
                    color: (_aiFeedback!['isCorrect'] ?? false) ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Score: ${_aiFeedback!['score']}%',
                      style: TextStyle(
                        color: (_aiFeedback!['isCorrect'] ?? false) ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (_answerSubmitted)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _answerSubmitted = false;
                          _aiFeedback = null;
                        });
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // MCQ Options or Text Input
          if (_question!.isMCQ && _question!.hasOptions) ...[
            // MCQ Answer Options
            ...(_question!.options!.map((option) {
              final isSelected = _selectedMcqAnswer == option['label'];
              final isCorrect = _answerSubmitted && option['label'] == _question!.effectiveCorrectAnswer;
              final isWrong = _answerSubmitted && isSelected && !isCorrect;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: _answerSubmitted ? null : () {
                    setState(() {
                      _selectedMcqAnswer = option['label'];
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isCorrect
                          ? Colors.green.withValues(alpha: 0.2)
                          : isWrong
                              ? Colors.red.withValues(alpha: 0.2)
                              : isSelected
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isCorrect
                            ? Colors.green
                            : isWrong
                                ? Colors.red
                                : isSelected
                                    ? Colors.blue
                                    : Colors.white.withValues(alpha: 0.1),
                        width: isSelected || isCorrect || isWrong ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isCorrect
                                ? Colors.green
                                : isWrong
                                    ? Colors.red
                                    : isSelected
                                        ? Colors.blue
                                        : Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Center(
                            child: isCorrect
                                ? const Icon(Icons.check, color: Colors.white, size: 20)
                                : isWrong
                                    ? const Icon(Icons.close, color: Colors.white, size: 20)
                                    : Text(
                                        option['label'] ?? '',
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : AppColors.textSecondary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            option['text'] ?? '',
                            style: TextStyle(
                              color: AppColors.textPrimary.withValues(alpha: 0.9),
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            })),
            const SizedBox(height: 8),
            // Check MCQ button + Retry
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_answerSubmitted || _selectedMcqAnswer == null)
                        ? null
                        : () {
                            setState(() {
                              _answerSubmitted = true;
                            });
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      disabledBackgroundColor: _answerSubmitted 
                          ? Colors.green.withValues(alpha: 0.5) 
                          : Colors.blue.withValues(alpha: 0.6),
                    ),
                    child: Text(
                      _answerSubmitted ? 'Submitted ✓' : 'Submit Answer',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                ),
                if (_answerSubmitted) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _answerSubmitted = false;
                        _selectedMcqAnswer = null;
                      });
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ],
            ),
          ] else ...[
            // Text input for written questions
            TextField(
              controller: _studentAnswerController,
              maxLines: 5,
              enabled: !_answerSubmitted && !_isCheckingAnswer,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Type your answer here...',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Check button for written
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_answerSubmitted || _isCheckingAnswer)
                    ? null
                    : () {
                        if (_studentAnswerController.text.trim().isNotEmpty) {
                          _checkAnswer();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  disabledBackgroundColor: Colors.blue.withValues(alpha: 0.6),
                ),
                child: _isCheckingAnswer
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _answerSubmitted ? 'Answer Checked ✓' : 'Check My Answer',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
              ),
            ),
          ],
          
          // Feedback
          if (_aiFeedback != null) ...[
            const SizedBox(height: 20),
            Text(
              _aiFeedback!['feedback'] ?? '',
              style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.85), height: 1.5),
            ),
            if ((_aiFeedback!['hints'] as List?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              _buildFeedbackList('Hints', (_aiFeedback!['hints'] as List).cast<String>(), Colors.amber, Icons.lightbulb_outline),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAiSolutionTab() {
    final isPremium = ref.watch(isPremiumProvider);
    
    // Always show the tab - display message if no content
    final hasContent = _question!.aiAnswer != null && _question!.aiAnswer!.isNotEmpty;
    
    if (!hasContent) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_outlined, color: Colors.white24, size: 48),
            const SizedBox(height: 12),
            Text('AI explanation not available', style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }
    
    // If not premium, show blurred content with upgrade prompt
    if (!isPremium) {
      return Stack(
        children: [
          // Blurred content
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Colors.purple, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'AI Explanation',
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 16),
                  Text(
                    _question!.aiAnswer ?? 'AI explanation not available for this question yet.',
                    style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.85), fontSize: 15, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
          
          // Premium upgrade overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.surface.withValues(alpha: 0.7),
                    AppColors.surface.withValues(alpha: 0.9),
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.surface,
                        const Color(0xFF1A1D28),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.6),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.2),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.withValues(alpha: 0.6),
                              Colors.orange.withValues(alpha: 0.2),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.7),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.6),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          size: 32,
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Premium Feature',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Upgrade to access AI step-by-step solutions',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFB800), Color(0xFFFF8800)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withValues(alpha: 0.6),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              // Show full premium dialog
                              AccessControlService.checkPremium(
                                context,
                                ref,
                                featureName: 'AI Solution',
                                highlights: [
                                  'Step-by-step AI explanations',
                                  'Understand complex problems',
                                  'Learn optimal solving methods',
                                  'Improve faster with guidance',
                                ],
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.workspace_premium, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Upgrade to Premium',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    
    // Premium users see the normal content
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.purple, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'AI Step-by-Step Solution',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 16),
          Text(
            _question!.aiSolution,
            style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.85), fontSize: 15, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialAnswerTab() {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    
    if (!_question!.hasOfficialAnswer) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined, color: Colors.white24, size: 48),
            const SizedBox(height: 12),
            Text('Official answer not available', style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }
    
    // If not authenticated, show blurred content with login prompt
    if (!isAuthenticated) {
      return Stack(
        children: [
          // Blurred content
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.verified, color: Colors.green, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Official Mark Scheme',
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 16),
                  Text(
                    _question!.officialAnswer,
                    style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.85), fontSize: 15, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
          
          // Login prompt overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.surface.withValues(alpha: 0.7),
                    AppColors.surface.withValues(alpha: 0.9),
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.6),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.withValues(alpha: 0.6),
                              Colors.cyan.withValues(alpha: 0.2),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.7),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.lock_outline,
                          size: 32,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Login to View Answer',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Create a free account to access official answers',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => context.go('/login'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Login / Sign Up',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    
    // Authenticated users see the normal content
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.verified, color: Colors.green, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Official Mark Scheme',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 16),
          Text(
            _question!.officialAnswer,
            style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.85), fontSize: 15, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomDrawer() {
    return DraggableScrollableSheet(
      initialChildSize: 0.12,
      minChildSize: 0.12,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.12, 0.45, 0.85],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1C2030), Color(0xFF151820)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Quick action buttons (visible when collapsed)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionButton(
                          icon: Icons.edit_note,
                          label: 'Answer',
                          color: Colors.blue,
                          isActive: !_answerSubmitted,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _toggleAiSolution,
                          child: _buildQuickActionButton(
                            icon: Icons.auto_awesome,
                            label: 'AI Solution',
                            color: Colors.purple,
                            isActive: _showAiSolution,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _showAnswerSheet,
                          child: _buildQuickActionButton(
                            icon: Icons.check_circle_outline,
                            label: 'Official',
                            color: Colors.green,
                            isActive: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Divider(color: Colors.white12, height: 24),
                
                // Answer input section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _answerSubmitted ? Icons.check_circle : Icons.edit,
                            color: _answerSubmitted ? Colors.green : Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _answerSubmitted ? 'Your Answer (Submitted)' : 'Write Your Answer',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          if (_aiFeedback != null) ...[
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: (_aiFeedback!['isCorrect'] ?? false)
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : Colors.orange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_aiFeedback!['score']}%',
                                style: TextStyle(
                                  color: (_aiFeedback!['isCorrect'] ?? false) ? Colors.green : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Text input
                      TextField(
                        controller: _studentAnswerController,
                        maxLines: 5,
                        enabled: !_answerSubmitted && !_isCheckingAnswer,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Type your answer here...',
                          hintStyle: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.6)),
                          filled: true,
                          fillColor: const Color(0xFF0D1117),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.blue.withValues(alpha: 0.5)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: (_answerSubmitted || _isCheckingAnswer)
                                  ? null
                                  : () {
                                      if (_studentAnswerController.text.trim().isNotEmpty) {
                                        _checkAnswer();
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                disabledBackgroundColor: Colors.blue.withValues(alpha: 0.6),
                              ),
                              child: _isCheckingAnswer
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _answerSubmitted ? 'Checked ✓' : 'Check Answer',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                            ),
                          ),
                          if (_answerSubmitted) ...[
                            const SizedBox(width: 12),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _answerSubmitted = false;
                                  _aiFeedback = null;
                                });
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withValues(alpha: 0.1),
                                padding: const EdgeInsets.all(14),
                              ),
                              icon: const Icon(Icons.refresh, color: Colors.white),
                            ),
                          ],
                        ],
                      ),
                      
                      // AI Feedback
                      if (_aiFeedback != null) ...[
                        const SizedBox(height: 24),
                        _buildFeedbackCard(),
                      ],
                      
                      // AI Solution
                      if (_showAiSolution && _question!.hasAiSolution) ...[
                        const SizedBox(height: 24),
                        _buildAiSolutionCard(),
                      ],
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? color.withValues(alpha: 0.5) : Colors.transparent,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isActive ? color : Colors.white54, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? color : Colors.white54,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard() {
    final isCorrect = _aiFeedback?['isCorrect'] ?? false;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCorrect 
            ? Colors.green.withValues(alpha: 0.1) 
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCorrect 
              ? Colors.green.withValues(alpha: 0.6) 
              : Colors.orange.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _aiFeedback!['feedback'] ?? '',
            style: TextStyle(
              color: AppColors.textPrimary.withValues(alpha: 0.9),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          if ((_aiFeedback!['strengths'] as List?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            _buildFeedbackList(
              'Strengths',
              (_aiFeedback!['strengths'] as List).cast<String>(),
              Colors.green,
              Icons.thumb_up,
            ),
          ],
          if ((_aiFeedback!['hints'] as List?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            _buildFeedbackList(
              'Hints',
              (_aiFeedback!['hints'] as List).cast<String>(),
              Colors.amber,
              Icons.lightbulb_outline,
            ),
          ],
          if ((_aiFeedback!['improvements'] as List?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            _buildFeedbackList(
              'Improvements',
              (_aiFeedback!['improvements'] as List).cast<String>(),
              Colors.cyan,
              Icons.trending_up,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentAnswerSection() {
    final isCorrect = _aiFeedback?['isCorrect'] ?? false;
    final score = _aiFeedback?['score'] ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            const Color(0xFF151820),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _answerSubmitted 
              ? (isCorrect ? Colors.green.withValues(alpha: 0.7) : Colors.orange.withValues(alpha: 0.7))
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with score if submitted
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _answerSubmitted 
                      ? (isCorrect ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2))
                      : Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _answerSubmitted 
                      ? (isCorrect ? Icons.check_circle : Icons.info_outline)
                      : Icons.edit_note,
                  color: _answerSubmitted 
                      ? (isCorrect ? Colors.green : Colors.orange)
                      : Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _answerSubmitted ? 'Your Answer' : 'Your Answer',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (_answerSubmitted && _aiFeedback != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCorrect ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$score%',
                    style: TextStyle(
                      color: isCorrect ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Text Input
          TextField(
            controller: _studentAnswerController,
            maxLines: 6,
            enabled: !_answerSubmitted && !_isCheckingAnswer,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Type your answer here...',
              hintStyle: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.6)),
              filled: true,
              fillColor: const Color(0xFF0B0E14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blue),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Check Answer Button
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_answerSubmitted || _isCheckingAnswer)
                      ? null 
                      : () {
                          if (_studentAnswerController.text.trim().isNotEmpty) {
                            _checkAnswer();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter an answer first'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        },
                  icon: _isCheckingAnswer 
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(_answerSubmitted ? Icons.check : Icons.send),
                  label: Text(_isCheckingAnswer 
                      ? 'Checking...' 
                      : (_answerSubmitted ? 'Checked' : 'Check Answer')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _answerSubmitted 
                        ? (isCorrect ? Colors.green.withValues(alpha: 0.6) : Colors.orange.withValues(alpha: 0.6))
                        : Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (_answerSubmitted) ...[
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _answerSubmitted = false;
                      _aiFeedback = null;
                    });
                  },
                  icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
                  tooltip: 'Try Again',
                ),
              ],
            ],
          ),
          
          // AI Feedback Section
          if (_answerSubmitted && _aiFeedback != null) ...[
            const SizedBox(height: 20),
            const Divider(color: Colors.white24),
            const SizedBox(height: 16),
            
            // Feedback text
            Text(
              _aiFeedback!['feedback'] ?? '',
              style: TextStyle(
                color: AppColors.textPrimary.withValues(alpha: 0.9),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            
            // Strengths
            if ((_aiFeedback!['strengths'] as List?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 16),
              _buildFeedbackList(
                'What you did well:',
                (_aiFeedback!['strengths'] as List).cast<String>(),
                Colors.green,
                Icons.thumb_up,
              ),
            ],
            
            // Hints (if not fully correct)
            if ((_aiFeedback!['hints'] as List?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              _buildFeedbackList(
                'Hints:',
                (_aiFeedback!['hints'] as List).cast<String>(),
                Colors.amber,
                Icons.lightbulb_outline,
              ),
            ],
            
            // Improvements
            if ((_aiFeedback!['improvements'] as List?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              _buildFeedbackList(
                'To improve:',
                (_aiFeedback!['improvements'] as List).cast<String>(),
                Colors.cyan,
                Icons.trending_up,
              ),
            ],
          ],
        ],
      ),
    );
  }
  
  Widget _buildFeedbackList(String title, List<String> items, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(left: 22, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• ', style: TextStyle(color: color)),
              Expanded(
                child: Text(
                  item,
                  style: TextStyle(
                    color: AppColors.textPrimary.withValues(alpha: 0.8),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
  Widget _buildAiSolutionCard() {
    if (_question == null || !_question!.hasAiSolution) return const SizedBox.shrink();

    // Split text by double newline to form paragraphs
    final parts = _question!.aiSolution.split(RegExp(r'\n\n+'));

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E), // Subtle purple/blue tint
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.indigoAccent.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Header
            Row(
              children: [
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.indigoAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.indigoAccent, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                    'AI Step-by-Step',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                    ),
                ),
            ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),

            // Step content
            ...parts.map((part) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SelectableText(
                    part.trim(),
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                        height: 1.6,
                        fontFamily: 'Roboto',
                    ),
                ),
            )),
        ],
      ),
    );
  }
}

