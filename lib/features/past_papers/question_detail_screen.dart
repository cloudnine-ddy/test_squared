import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:ui';
import 'data/past_paper_repository.dart';
import 'models/question_model.dart';
import 'models/question_blocks.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/question_image_header.dart';
import 'widgets/question_action_bar.dart';
import 'widgets/pdf_crop_viewer.dart';
import 'widgets/answer_reveal_sheet.dart';
import 'widgets/formatted_question_text.dart';
import 'widgets/smart_question_renderer.dart';
import '../bookmarks/widgets/bookmark_button.dart';
import '../bookmarks/screens/note_editor_dialog.dart';
import '../bookmarks/data/bookmark_repository.dart';
import '../bookmarks/data/notes_repository.dart';
import '../bookmarks/widgets/draggable_note_widget.dart'; // New draggable widget
import '../progress/data/progress_repository.dart';
import '../progress/models/question_attempt_model.dart';
import '../auth/providers/auth_provider.dart';
import '../../core/services/access_control_service.dart';
import '../../shared/wired/wired_widgets.dart';

/// Full-page question detail view with figure and answer reveals
class QuestionDetailScreen extends ConsumerStatefulWidget {
  final String questionId;
  final String? topicId; // Context for navigation
  final bool previewMode; // Admin preview mode - disables progress tracking and submission

  const QuestionDetailScreen({
    super.key,
    required this.questionId,
    this.topicId,
    this.previewMode = false,
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

  // Navigation
  String? _prevQuestionId;
  String? _nextQuestionId;

  // Draggable Note State
  bool _isNoteOpen = false;
  Offset _notePosition = const Offset(20, 100); // Default position
  String? _loadedNoteText;
  List<String>? _loadedNoteImages;

  // AI Feedback
  Map<String, dynamic>? _aiFeedback;

  // Progress tracking
  DateTime? _questionStartTime;
  Map<String, dynamic>? _previousAttempt;
  bool _isViewingPreviousAnswer = false;

  // Structured question answers
  Map<String, dynamic> _structuredAnswers = {};
  Set<int> _expandedPartIndices = {0}; // For accordion UI: which parts are currently expanded (default first one)

  // Bookmark and notes
  bool _isBookmarked = false;
  bool _hasNote = false;
  final _bookmarkRepo = BookmarkRepository();
  final _notesRepo = NotesRepository();
  final _progressRepo = ProgressRepository();

  // Sketchy Theme Constants
  static const _primaryColor = Color(0xFF2D3E50);
  static const _backgroundColor = Color(0xFFFDFBF7);

  TextStyle _patrickHand({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: 'PatrickHand',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? _primaryColor,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _questionStartTime = DateTime.now(); // Start tracking time
    _loadQuestion();
    // Skip user-specific features in preview mode
    if (!widget.previewMode) {
      _loadBookmarkAndNoteStatus();
      _loadPreviousAttempt(); // Load previous attempt if exists
    }
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

    // Fetch adjacent questions with context priority
    String? prevId;
    String? nextId;

    if (question != null) {
      if (widget.topicId != null) {
        // Topic Context - Respect Question Type
        final adjacent = await PastPaperRepository().getAdjacentIdsForTopic(
          widget.topicId!,
          widget.questionId,
          type: question.type, // Maintain type consistency (mcq vs structured)
        );
        prevId = adjacent['prev'];
        nextId = adjacent['next'];
      } else if (question.paperId != null) {
        // Paper Context (Default)
        final adjacent = await PastPaperRepository().getAdjacentQuestionIds(
          question.paperId!,
          question.questionNumber
        );
        prevId = adjacent['prev'];
        nextId = adjacent['next'];
      }
    }

    if (mounted) {
      setState(() {
        _question = question;
        _prevQuestionId = prevId;
        _nextQuestionId = nextId;
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

  Future<void> _toggleBookmark() async {
    try {
      if (_isBookmarked) {
        await _bookmarkRepo.removeBookmark(widget.questionId);
        setState(() {
          _isBookmarked = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bookmark removed')),
        );
      } else {
        // Show folder selection dialog before adding bookmark
        final folder = await _showFolderSelectionDialog();
        if (folder == null) {
          return; // User cancelled
        }

        await _bookmarkRepo.addBookmark(widget.questionId, folder: folder);
        setState(() {
          _isBookmarked = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bookmarked to $folder!')),
        );
      }
    } catch (e) {
      print('Error toggling bookmark: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error updating bookmark')),
      );
    }
  }

  Future<String?> _showFolderSelectionDialog() async {
    final folders = await _bookmarkRepo.getFolders();
    final TextEditingController newFolderController = TextEditingController();

    return showDialog<String>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: WiredCard(
          backgroundColor: const Color(0xFFFDFBF7), // Cream background
          borderColor: _primaryColor,
          borderWidth: 2,
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    WiredCard(
                      padding: const EdgeInsets.all(10),
                      backgroundColor: _primaryColor.withValues(alpha: 0.1),
                      borderColor: _primaryColor,
                      child: Icon(Icons.bookmark, color: _primaryColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Bookmark Question',
                      style: _patrickHand(
                        color: _primaryColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Folder Selection
                if (folders.isNotEmpty) ...[
                  Text(
                    'SELECT FOLDER',
                    style: _patrickHand(
                      color: _primaryColor.withValues(alpha: 0.6),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: SingleChildScrollView(
                      child: Column(
                        children: folders.map((folder) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(folder),
                            child: WiredCard(
                              backgroundColor: Colors.white,
                              borderColor: _primaryColor.withValues(alpha: 0.3),
                              borderWidth: 1.5,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Icon(Icons.folder, color: _primaryColor, size: 22),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      folder,
                                      style: _patrickHand(
                                        color: _primaryColor,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, color: _primaryColor.withValues(alpha: 0.5), size: 22),
                                ],
                              ),
                            ),
                          ),
                        )).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // New Folder Input
                Text(
                  'CREATE NEW FOLDER',
                  style: _patrickHand(
                    color: _primaryColor.withValues(alpha: 0.6),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                CustomPaint(
                  painter: WiredBorderPainter(
                    color: _primaryColor.withValues(alpha: 0.4),
                    strokeWidth: 1.5,
                  ),
                  child: Container(
                    color: Colors.white,
                    child: TextField(
                      controller: newFolderController,
                      style: _patrickHand(color: _primaryColor, fontSize: 18),
                      decoration: InputDecoration(
                        hintText: 'Enter folder name...',
                        hintStyle: _patrickHand(color: _primaryColor.withValues(alpha: 0.4), fontSize: 18),
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        prefixIcon: Icon(Icons.create_new_folder_outlined, color: _primaryColor.withValues(alpha: 0.6), size: 24),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    WiredButton(
                      onPressed: () => Navigator.of(context).pop(),
                      backgroundColor: Colors.transparent,
                      borderColor: _primaryColor.withValues(alpha: 0.3),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Text(
                        'Cancel',
                        style: _patrickHand(
                          color: _primaryColor.withValues(alpha: 0.7),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    WiredButton(
                      onPressed: () {
                        final newFolder = newFolderController.text.trim();
                        if (newFolder.isNotEmpty) {
                          Navigator.of(context).pop(newFolder);
                        } else if (folders.isNotEmpty) {
                          Navigator.of(context).pop(folders.first);
                        } else {
                          Navigator.of(context).pop('My Bookmarks');
                        }
                      },
                      backgroundColor: const Color(0xFFFFB300), // Amber/Yellow
                      filled: true,
                      borderColor: const Color(0xFFFFB300),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bookmark_add, color: Color(0xFF2D3E50), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Save Bookmark',
                            style: _patrickHand(
                              color: const Color(0xFF2D3E50),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Load previous attempt if exists
  Future<void> _loadPreviousAttempt() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final attempt = await _progressRepo.getLastAttempt(userId, widget.questionId);

      if (attempt != null && mounted) {
        // For structured questions: load answers but don't show feedback/lock form
        // (allows user to see their previous answers but still retry freely)
        final isStructured = _question?.isStructured == true;
        
        setState(() {
          _previousAttempt = attempt.toMap();
          
          // Pre-fill the answer for all question types
          if (attempt.answerText != null) {
            // Check if it's structured answer (JSON format)
            try {
              final parsed = jsonDecode(attempt.answerText!);
              if (parsed is List) {
                // Structured answer format: [{"(a)(i)": "answer1"}, {"(a)(ii)": "answer2"}]
                _structuredAnswers = {};
                for (var item in parsed) {
                  if (item is Map) {
                    item.forEach((key, value) {
                      _structuredAnswers[key.toString()] = value.toString();
                    });
                  }
                }
                print('📥 Loaded structured answers: ${_structuredAnswers.keys}');
              } else {
                // Regular text answer
                _studentAnswerController.text = attempt.answerText!;
              }
            } catch (e) {
              // Not JSON, treat as regular text
              _studentAnswerController.text = attempt.answerText!;
            }
          }
          if (attempt.selectedOption != null) {
            _selectedMcqAnswer = attempt.selectedOption;
          }

          // For structured questions: only load answers, don't show feedback or lock form
          if (isStructured) {
            // Don't set feedback or answerSubmitted - user can freely retry
            _isViewingPreviousAnswer = false;
            return;
          }
          
          // For MCQ/regular questions: show feedback and lock form
          _isViewingPreviousAnswer = true;
          
          // Show the feedback automatically based on previous attempt result
          _aiFeedback = {
            'score': attempt.score,
            'isCorrect': attempt.isCorrect,  // For UI display (green/red)
            'is_correct': attempt.isCorrect, // For repository compatibility
            'feedback': attempt.isCorrect == true
                ? 'Previously answered correctly'
                : 'Previously submitted answer',
            'strengths': [],
            'improvements': [],
            'hints': [],
          };
          _answerSubmitted = true;
        });
      }
    } catch (e) {
      print('Error loading previous attempt: $e');
    }
  }

  /// Retry/Clear form for new attempt
  void _retryQuestion() {
    setState(() {
      _isViewingPreviousAnswer = false;
      _studentAnswerController.clear();
      _selectedMcqAnswer = null;
      _aiFeedback = null;
      _answerSubmitted = false;
      _questionStartTime = DateTime.now(); // Reset timer
    });
  }

  Future<void> _showNoteEditor() async {
    if (_isNoteOpen) {
      setState(() => _isNoteOpen = false);
      return;
    }

    // Load existing note if any
    final existingNote = await _notesRepo.getNote(widget.questionId);

    if (!mounted) return;

    setState(() {
      _loadedNoteText = existingNote?.noteText;
      _loadedNoteImages = existingNote?.imageUrls;
      _isNoteOpen = true;
    });
  }

  Future<void> _saveNote(String noteText, List<String> imageUrls) async {
    if (noteText.isNotEmpty || imageUrls.isNotEmpty) {
      try {
        await _notesRepo.saveNote(widget.questionId, noteText, imageUrls: imageUrls);
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
    // Skip recording in preview mode
    if (widget.previewMode) return;
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

    // Check if user can use check answer (premium or has free checks remaining)
    final canUseCheckAnswer = ref.read(canUseCheckAnswerProvider);
    final isPremium = ref.read(isPremiumProvider);
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (!canUseCheckAnswer) {
      // Show upgrade dialog when free checks exhausted
      AccessControlService.checkPremium(
        context,
        ref,
        featureName: 'AI Answer Checking',
        highlights: [
          'You have used all 5 free answer checks',
          'Upgrade to Premium for unlimited checks',
          'Get instant AI-powered feedback',
          'Track your progress over time',
        ],
      );
      return;
    }

    // Decrement free checks for non-premium users
    if (!isPremium && userId != null) {
      await decrementFreeChecks(userId);
      // Invalidate the provider to refresh the count
      ref.invalidate(currentUserProvider);
    }

    setState(() {
      _isCheckingAnswer = true;
    });

    try {
      final timeSpent = _questionStartTime != null
          ? DateTime.now().difference(_questionStartTime!).inSeconds
          : 0;

      final response = await Supabase.instance.client.functions.invoke(
        'check-answer',
        body: {
          'questionId': _question!.id,
          'questionContent': _question!.content,
          'officialAnswer': _question!.officialAnswer,
          'studentAnswer': _studentAnswerController.text.trim(),
          'marks': _question!.marks,
          'userId': userId,  // Pass userId for automatic progress saving
          'timeSpent': timeSpent,  // Pass time tracking
          'hintsUsed': 0,  // TODO: Track when hints feature added
          'selectedOption': _selectedMcqAnswer,  // For MCQ questions
        },
      );

      if (response.status == 200 && response.data != null) {
        setState(() {
          _aiFeedback = response.data as Map<String, dynamic>;
          _answerSubmitted = true;
          _isCheckingAnswer = false;
        });

        // Note: No need to call _recordAttempt() anymore - Edge Function handles it!
        // The Edge Function now saves the attempt automatically and returns attemptId
        print('Progress automatically saved by Edge Function');
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

  Future<void> _checkMcqAnswer() async {
    if (_question == null || _selectedMcqAnswer == null) return;

    final isCorrect = _selectedMcqAnswer == _question!.effectiveCorrectAnswer;

    setState(() {
      _aiFeedback = {
        'isCorrect': isCorrect,
        'is_correct': isCorrect, // For repository compatibility
        'score': isCorrect ? 100 : 0,
        'feedback': isCorrect
            ? 'Correct! Well done.'
            : 'Incorrect. Try again!',  // Don't reveal the answer - allow retry
        'strengths': isCorrect ? ['Selected the correct option'] : [],
        'hints': [],
        'improvements': [],
      };
      // Lock options after submission (user must click Try Again to retry)
      _answerSubmitted = true;
    });

    await _recordAttempt();

    // Refresh topic screen when returning
    // (Optional: trigger any listeners if needed)
  }

  Future<void> _checkStructuredAnswer() async {
    if (_question == null || _structuredAnswers.isEmpty) return;

    // Check premium access
    final canUseCheckAnswer = ref.read(canUseCheckAnswerProvider);
    final isPremium = ref.read(isPremiumProvider);
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (!canUseCheckAnswer) {
      AccessControlService.checkPremium(
        context,
        ref,
        featureName: 'AI Answer Checking',
        highlights: [
          'You have used all 5 free answer checks',
          'Upgrade to Premium for unlimited checks',
          'Get instant AI-powered feedback',
          'Track your progress over time',
        ],
      );
      return;
    }

    // Decrement free checks for non-premium users
    if (!isPremium && userId != null) {
      await decrementFreeChecks(userId);
      ref.invalidate(currentUserProvider);
    }

    setState(() {
      _isCheckingAnswer = true;
    });

    try {
      final timeSpent = _questionStartTime != null
          ? DateTime.now().difference(_questionStartTime!).inSeconds
          : 0;

      // Build structured answers array from blocks
      final structuredAnswersArray = <Map<String, dynamic>>[];

      if (_question!.structureData != null) {
        for (final block in _question!.structureData!) {
          if (block is QuestionPartBlock) {
            final questionPart = block as QuestionPartBlock;
            final answer = _structuredAnswers[questionPart.label];
            if (answer != null && answer.toString().trim().isNotEmpty) {
              structuredAnswersArray.add({
                'label': questionPart.label,
                'studentAnswer': answer.toString(),
                'officialAnswer': questionPart.officialAnswer,
                'marks': questionPart.marks,
              });
            }
          }
        }
      }

      if (structuredAnswersArray.isEmpty) {
        throw Exception('Please answer at least one part');
      }

      print('📝 Submitting ${structuredAnswersArray.length} answers:');
      for (final ans in structuredAnswersArray) {
        final preview = ans['studentAnswer']?.toString() ?? '';
        final previewText = preview.length > 20 ? preview.substring(0, 20) : preview;
        print('  - Part ${ans['label']}: "$previewText..."');
      }

      final response = await Supabase.instance.client.functions.invoke(
        'check-answer',
        body: {
          'questionId': _question!.id,
          'isStructured': true,
          'structuredAnswers': structuredAnswersArray,
          'userId': userId,
          'timeSpent': timeSpent,
          'hintsUsed': 0,
        },
      );

      if (response.status == 200 && response.data != null) {
        print('✅ Structured answer response: ${response.data}');
        setState(() {
          _aiFeedback = response.data as Map<String, dynamic>;
          _answerSubmitted = true;
          _isCheckingAnswer = false;
        });
        print('📊 Per-part results: ${_aiFeedback!['perPartResults']}');
        print('Structured question progress saved');
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
        officialAnswer: _question!.formattedOfficialAnswer,
        aiSolution: _question!.aiSolution,
        hasOfficialAnswer: _question!.hasOfficialAnswer,
        hasAiSolution: _question!.hasAiSolution,
      ),
    );
  }

  Future<void> _showAiExplainDialog() async {
    // AI Explanation is now free for all users!

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
    final hasImageUrl = _question!.imageUrl != null && _question!.imageUrl!.isNotEmpty;
    final pdfUrl = _question!.pdfUrl;
    final loc = _question!.aiAnswerRaw?['figure_location'];
    final hasPdfInfo = pdfUrl != null && loc != null;

    if (!hasImageUrl && !hasPdfInfo) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8), // Darker backdrop for focus
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Sketchy Card Container
            WiredCard(
              backgroundColor: Colors.white,
              borderColor: _primaryColor,
              borderWidth: 2,
              padding: const EdgeInsets.all(12), // Frame thickness
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5.0,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.75,
                      minHeight: 200,
                    ),
                    child: hasImageUrl
                        ? Image.network(
                            _question!.imageUrl!,
                            fit: BoxFit.contain,
                          )
                        : PdfCropViewer(
                            pdfUrl: pdfUrl!,
                            pageNumber: loc['page'] ?? 1,
                            x: (loc['x_percent'] ?? 0).toDouble(),
                            y: (loc['y_percent'] ?? 0).toDouble(),
                            width: (loc['width_percent'] ?? 100).toDouble(),
                            height: (loc['height_percent'] ?? 100).toDouble(),
                          ),
                  ),
                ),
              ),
            ),
            
            // Sketchy Close Button (Top Right)
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(2, 2)),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  ),
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
        backgroundColor: _backgroundColor,
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
                style: _patrickHand(
                  color: AppColors.textPrimary.withValues(alpha: 0.5),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_question == null) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red.withValues(alpha: 0.5), size: 48),
              const SizedBox(height: 16),
              Text('Question not found', style: _patrickHand(color: AppColors.textSecondary, fontSize: 18)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Reduced from 12
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: _primaryColor.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            )
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               // 1. Status Info (if applicable)
               if (_isViewingPreviousAnswer || _answerSubmitted) ...[
                  Builder(
                    builder: (context) {
                       final attemptedAt = _previousAttempt != null
                            ? DateTime.parse(_previousAttempt!['attempted_at'])
                            : DateTime.now();
                       final timeAgo = _previousAttempt != null
                            ? _formatTimeAgo(attemptedAt)
                            : 'Just now';
                       final score = _previousAttempt != null
                            ? _previousAttempt!['score'] as int?
                            : (_aiFeedback?['score'] as int?);

                       return const SizedBox.shrink(); 
                     }
                  ),
               ],

              // 2. Navigation Buttons
              Row(
                children: [
                  // Previous Button (Compact)
                  WiredButton(
                    onPressed: _prevQuestionId == null ? () {} : () {
                       final uri = Uri(
                         path: '/question/$_prevQuestionId',
                         queryParameters: widget.topicId != null ? {'topicId': widget.topicId} : null,
                       );
                       context.pushReplacement(uri.toString());
                    },
                    backgroundColor: _prevQuestionId == null ? Colors.grey.shade100 : Colors.white,
                    filled: true,
                    borderColor: _prevQuestionId == null ? Colors.grey.shade300 : _primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Reduced from 12
                    child: Icon(Icons.arrow_back_rounded, size: 20, color: _prevQuestionId == null ? Colors.grey : _primaryColor),
                  ),
                  const SizedBox(width: 12),

                  // Middle Action Button (Submit/Retry/Check)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        bool enabled = true;
                        String label = 'Submit';
                        Color color = Colors.blue;
                        VoidCallback? onPressed;

                        if (_answerSubmitted) {
                           // MCQ incorrect: show 'Try Again'; MCQ correct or others: show 'Retry'
                           if (_question!.isMCQ && _aiFeedback != null && !(_aiFeedback!['isCorrect'] ?? false)) {
                             label = 'Try Again';
                           } else {
                             label = 'Retry';
                           }
                           color = Colors.orange;
                           onPressed = _retryQuestion;
                        } else if (_isCheckingAnswer) {
                           label = 'Checking...';
                           color = Colors.blue;
                           enabled = false;
                           onPressed = null;
                        } else {
                           if (_question!.isMCQ) {
                             enabled = _selectedMcqAnswer != null;
                             onPressed = enabled ? _checkMcqAnswer : null;
                           } else if (_question!.isStructured) {
                             onPressed = _checkStructuredAnswer;
                           } else {
                             enabled = _studentAnswerController.text.trim().isNotEmpty;
                             onPressed = enabled ? _checkAnswer : null;
                           }
                        }


                        // Only show on 'Your Answer' tab (index 0)
                        if (_tabController.index != 0) {
                          // Maybe show "Back to Question"? Or just disabled?
                          // Let's show "View Question" to jump back to tab 0
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 250),
                              child: WiredButton(
                                onPressed: () => _tabController.animateTo(0),
                                backgroundColor: Colors.white,
                                filled: true,
                                borderColor: _primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 8), // Reduced from 12
                                 child: Center(
                                    child: Text(
                                      'Answer Question',
                                      style: _patrickHand(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                 ),
                              ),
                            ),
                          );
                        }

                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 300),
                            child: WiredButton(
                              onPressed: onPressed,
                              backgroundColor: enabled ? color : Colors.grey.shade200,
                              filled: true,
                              borderColor: enabled ? color : Colors.grey.shade300,
                              padding: const EdgeInsets.symmetric(vertical: 8), // Reduced from 12
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_isCheckingAnswer)
                                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  else
                                    Text(
                                      label,
                                      style: _patrickHand(
                                        color: enabled ? Colors.white : Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Next Button (Compact)
                  WiredButton(
                    onPressed: _nextQuestionId == null
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('You have reached the end of this topic.'),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        : () {
                            final uri = Uri(
                              path: '/question/$_nextQuestionId',
                              queryParameters: widget.topicId != null ? {'topicId': widget.topicId} : null,
                            );
                            context.pushReplacement(uri.toString());
                        },
                    backgroundColor: _nextQuestionId == null ? Colors.white : Colors.white,
                    filled: true,
                    borderColor: _nextQuestionId == null ? _primaryColor : _primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Reduced from 12
                    child: Icon(
                      _nextQuestionId == null ? Icons.check : Icons.arrow_forward_rounded,
                      size: 20,
                      color: _primaryColor
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
              // Sketchy App Bar
              SliverAppBar(
                backgroundColor: _backgroundColor,
                floating: false,
                pinned: true,
                elevation: 0,
                toolbarHeight: 48, // Condensed height
                leadingWidth: 52, // Slightly narrower to fit new height
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
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: WiredCard(
                        padding: EdgeInsets.zero,
                        borderColor: _primaryColor.withValues(alpha: 0.3),
                        child: Center(
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            color: _primaryColor,
                            size: 16
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                title: _question != null ? Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _primaryColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Q${_question!.questionNumber}',
                        style: _patrickHand(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 19),
                      ),
                    ),
                    if (_question!.hasPaperInfo) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 4, height: 4,
                        decoration: BoxDecoration(color: _primaryColor.withValues(alpha: 0.4), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _question!.paperLabel,
                          style: _patrickHand(color: _primaryColor.withValues(alpha: 0.6), fontSize: 17),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]
                  ],
                ) : null,
                centerTitle: false,
                actions: [
                  // Note button
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                       Container(
                         width: 38,
                         height: 38,
                         child: WiredButton(
                           onPressed: _showNoteEditor,
                           backgroundColor: _hasNote ? Colors.blue : Colors.white,
                           filled: true,
                           borderColor: _primaryColor,
                           padding: EdgeInsets.zero, // Minimal padding for icon
                           child: Icon(
                              _hasNote ? Icons.note_alt_rounded : Icons.note_add_outlined,
                              color: _hasNote ? Colors.white : _primaryColor,
                              size: 20,
                           ),
                         ),
                       ),
                       if (_hasNote)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Bookmark button
                  Container(
                    width: 38,
                    height: 38,
                    child: WiredButton(
                      onPressed: _toggleBookmark,
                      padding: EdgeInsets.zero,
                      backgroundColor: _isBookmarked ? _primaryColor : Colors.white,
                      filled: true,
                      borderColor: _primaryColor,
                       child: Icon(
                        _isBookmarked ? Icons.bookmark_added_rounded : Icons.bookmark_outline_rounded,
                        color: _isBookmarked ? Colors.white : _primaryColor,
                        size: 20
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_question != null)
                    Container(
                      margin: const EdgeInsets.only(right: 16),
                      child: WiredCard(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // Reduced from 6
                        backgroundColor: const Color(0xFFFFB300).withValues(alpha: 0.2), // Light Amber
                        borderColor: const Color(0xFFFFB300),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: Color(0xFF232832), size: 16), // Slightly smaller icon
                            const SizedBox(width: 4),
                            Builder(
                              builder: (context) {
                                return Text(
                                  '${_question!.totalMarks} marks',
                                  style: _patrickHand(
                                    color: const Color(0xFF232832),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                );
                              }
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              // Tabbed Answer Card - Maximizing space usage
              SliverFillRemaining(
                hasScrollBody: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4), 
                  child: _buildTabbedCard(),
                ),
              ),

            ],
          ),

          if (_isNoteOpen)
            Positioned(
              left: _notePosition.dx,
              top: _notePosition.dy,
              child: DraggableNoteWidget(
                questionId: widget.questionId,
                initialNote: _loadedNoteText,
                initialImageUrls: _loadedNoteImages,
                onClose: () => setState(() => _isNoteOpen = false),
                onSave: _saveNote,
                onDrag: (delta) {
                  setState(() {
                    _notePosition += delta;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabbedCard() {
    // 1. Unified Figure Detection (Structured or MCQ)
    List<FigureBlock> figures = [];
    if (_question!.isStructured) {
      figures = _question!.structureData!.whereType<FigureBlock>().toList();
    } else {
      // Check for standalone image or PDF figure in MCQ/Unstructured
      final hasImageUrl = _question!.imageUrl != null && _question!.imageUrl!.isNotEmpty;
      final pdfUrl = _question!.pdfUrl;
      final loc = _question!.aiAnswerRaw?['figure_location'];
      
      if (hasImageUrl) {
        figures.add(FigureBlock(
          url: _question!.imageUrl,
          figureLabel: 'Figure',
          description: '',
        ));
      } else if (pdfUrl != null && loc != null) {
        figures.add(FigureBlock(
          figureLabel: 'Figure',
          description: '',
          meta: {
            'pdf_url': pdfUrl,
            'figure_location': loc,
          },
        ));
      }
    }

    return WiredCard(
      height: null, // Let parent Expanded handle height
      padding: const EdgeInsets.all(3), // Breathing room for sketchy borders on all sides
      child: Column(
        children: [
          // 1. Figures Panel (Integrated inside the hand-drawn frame)
          if (figures.isNotEmpty) ...[
            CollapsibleFiguresPanel(
              figures: figures,
              onFigureTap: _showFullFigure,
            ),
            const WiredDivider(),
          ],

          // 2. Tab Headers
          Container(
            height: 48, 
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: _primaryColor.withValues(alpha: 0.1), width: 1.5),
              ),
            ),
            child: Row(
              children: [
                _buildTabItem(0, 'Your Answer', _answerSubmitted ? Icons.check_circle : Icons.edit_note,
                    activeColor: _answerSubmitted ? Colors.green : null),
                Container(width: 1.5, color: _primaryColor.withValues(alpha: 0.2)),
                _buildTabItem(1, 'Official', Icons.verified_outlined),
                Container(width: 1.5, color: _primaryColor.withValues(alpha: 0.2)),
                _buildTabItem(2, 'AI Explanation', Icons.auto_awesome),
                Container(width: 1.5, color: _primaryColor.withValues(alpha: 0.2)), 
              ],
            ),
          ),

          // 3. Tab Content
          Expanded(
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

  Widget _buildTabItem(int index, String label, IconData icon, {Color? activeColor}) {
    return Expanded(
      child: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          final isSelected = _tabController.index == index;
          return Material(
            color: isSelected ? _primaryColor.withValues(alpha: 0.05) : Colors.transparent,
            child: InkWell(
              onTap: () => _tabController.animateTo(index),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: isSelected ? (activeColor ?? _primaryColor) : _primaryColor.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: _patrickHand(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? (activeColor ?? _primaryColor) : _primaryColor.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Builds an expandable card for a structured question part (accordion style)
  Widget _buildExpandablePartCard({
    required int index,
    required QuestionPartBlock part,
    required bool isExpanded,
    required String tabType, // 'answer', 'official', or 'ai'
  }) {
    final hasAnswer = _structuredAnswers[part.label] != null &&
                     (_structuredAnswers[part.label] as String?)?.isNotEmpty == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8), 
      child: WiredCard(
        backgroundColor: isExpanded ? Colors.white : const Color(0xFFFDFBF7),
        borderColor: isExpanded ? _primaryColor : _primaryColor.withValues(alpha: 0.3),
        borderWidth: isExpanded ? 2.2 : 1.5, // Slightly thicker when active
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (always visible) - tap anywhere to toggle
            GestureDetector(
              behavior: HitTestBehavior.opaque, 
              onTap: () => setState(() {
                if (_expandedPartIndices.contains(index)) {
                  _expandedPartIndices.remove(index);
                } else {
                  _expandedPartIndices.add(index);
                }
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // Expand/collapse icon - Rounded variants for hand-drawn feel
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                      color: _primaryColor,
                      size: 26,
                    ),
                    const SizedBox(width: 4),
                    
                    // Part label badge - Custom handwritten look
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isExpanded ? _primaryColor.withValues(alpha: 0.05) : Colors.transparent,
                        border: Border.all(
                          color: isExpanded ? _primaryColor : _primaryColor.withValues(alpha: 0.2),
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Part ${part.label}'.toUpperCase(),
                        style: _patrickHand(
                          color: _primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Part content preview (only when collapsed)
                    if (!isExpanded)
                      Expanded(
                        child: Text(
                          part.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _patrickHand(
                            color: _primaryColor.withValues(alpha: 0.5),
                            fontSize: 17,
                          ),
                        ),
                      ),
                    
                    if (isExpanded) const Spacer(),
                    
                    // Marks badge - Sketchy yellow bubble
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                        border: Border.all(
                          color: const Color(0xFFFFB300).withValues(alpha: 0.3),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${part.marks} marks'.toUpperCase(),
                        style: _patrickHand(
                          color: const Color(0xFF232832),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 6),
                    
                    // Status indicator (completed/pending)
                    if (tabType == 'answer' && hasAnswer)
                      const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 18),
                  ],
                ),
              ),
            ),

            // Expandable content
            if (isExpanded) ...[
              const WiredDivider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _buildPartContent(part, tabType),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds the content for an expanded part based on tab type
  Widget _buildPartContent(QuestionPartBlock part, String tabType) {
    switch (tabType) {
      case 'answer':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question text
            Text(
              part.content,
              style: _patrickHand(fontSize: 19, height: 1.5),
            ),
            const SizedBox(height: 16),
            // Answer input
            TextField(
              controller: TextEditingController(text: _structuredAnswers[part.label] ?? ''),
              onChanged: (value) => _structuredAnswers[part.label] = value,
              maxLines: 4,
              enabled: !_answerSubmitted,
              style: _patrickHand(color: _primaryColor, fontSize: 17),
              decoration: InputDecoration(
                hintText: 'Type your answer for part ${part.label}...',
                hintStyle: _patrickHand(color: _primaryColor.withValues(alpha: 0.4), fontSize: 17),
                filled: true,
                fillColor: const Color(0xFFF5F3EE),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _primaryColor.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _primaryColor.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _primaryColor, width: 2),
                ),
              ),
            ),
          ],
        );

      case 'official':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question text (for context)
            Text(
              part.content,
              style: _patrickHand(fontSize: 17, color: _primaryColor.withValues(alpha: 0.7), height: 1.4),
            ),
            const SizedBox(height: 16),
            // Official answer box
            WiredCard(
              backgroundColor: Colors.green.withValues(alpha: 0.05),
              borderColor: Colors.green.withValues(alpha: 0.3),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ANSWER',
                    style: _patrickHand(
                      color: Colors.green,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (part.officialAnswer != null && part.officialAnswer!.isNotEmpty)
                    Html(
                      data: part.officialAnswer!,
                      style: {
                        "body": Style(
                          color: const Color(0xFF2D3E50),
                          fontFamily: 'PatrickHand',
                          fontSize: FontSize(18),
                          lineHeight: LineHeight(1.5),
                          margin: Margins.zero,
                        ),
                      },
                    )
                  else
                    Text(
                      'No official answer available',
                      style: TextStyle(
                        fontFamily: 'PatrickHand',
                        color: _primaryColor.withValues(alpha: 0.5),
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );

      case 'ai':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question text (for context)
            Text(
              part.content,
              style: _patrickHand(fontSize: 17, color: _primaryColor.withValues(alpha: 0.7), height: 1.4),
            ),
            const SizedBox(height: 16),
            // AI explanation box
            WiredCard(
              backgroundColor: Colors.purple.withValues(alpha: 0.05),
              borderColor: Colors.purple.withValues(alpha: 0.3),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.purple, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'AI EXPLANATION',
                        style: _patrickHand(
                          color: Colors.purple,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (part.aiAnswer != null && part.aiAnswer!.isNotEmpty)
                    MarkdownBody(
                      data: part.aiAnswer!,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          fontFamily: 'PatrickHand',
                          color: const Color(0xFF2D3E50),
                          fontSize: 17,
                          height: 1.5,
                        ),
                      ),
                    )
                  else
                    Text(
                      'AI explanation not available for this part',
                      style: TextStyle(
                        fontFamily: 'PatrickHand',
                        color: _primaryColor.withValues(alpha: 0.5),
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAnswerTab() {
    final isPremium = ref.watch(isPremiumProvider);

    // For structured questions, we use the SmartQuestionRenderer with Sticky Headers
    if (_question!.isStructured && _question!.structureData != null) {
      return Column(
        children: [
          // Score badge (if feedback available)
          if (_aiFeedback != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0), // Reduced from 20
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120), // Prevent unbounded expansion
                child: WiredCard(
                  backgroundColor: (_aiFeedback!['isCorrect'] ?? false)
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderColor: (_aiFeedback!['isCorrect'] ?? false) ? Colors.green : Colors.orange,
                  child: Row(
                    mainAxisSize: MainAxisSize.min, // Ensure it tries to be minimal
                    children: [
                      Icon(
                        (_aiFeedback!['isCorrect'] ?? false) ? Icons.check_circle : Icons.info_outline,
                        color: (_aiFeedback!['isCorrect'] ?? false) ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Score: ${_aiFeedback!['score']}%',
                          style: _patrickHand(
                            color: (_aiFeedback!['isCorrect'] ?? false) ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // The Sticky Renderer takes up the remaining space
          Expanded(
            child: SmartQuestionRenderer(
              blocks: _question!.structureData!,
              onAnswersChanged: (answers) {
                 _structuredAnswers = answers;
              },
              isSubmitted: _answerSubmitted,
              savedAnswers: _structuredAnswers,
              perPartFeedback: _aiFeedback?['perPartResults'],
              showSolutions: _answerSubmitted, // Changed from false
              onFigureTap: _showFullFigure, // Added this line
              isPremium: isPremium,
              onUpgrade: () => context.push('/premium'),
            ),
          ),

        ],
      );
    }

    // Default view for MCQ and Unstructured
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Reduced from all(20)
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score badge only for non-MCQ (MCQ uses the bottom feedback card only)
          if (_aiFeedback != null && !_question!.isMCQ) ...[
            // Non-MCQ score display (keeps original behavior)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: WiredCard(
                backgroundColor: (_aiFeedback!['isCorrect'] ?? false)
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                borderColor: (_aiFeedback!['isCorrect'] ?? false) ? Colors.green : Colors.orange,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      (_aiFeedback!['isCorrect'] ?? false) ? Icons.check_circle : Icons.info_outline,
                      color: (_aiFeedback!['isCorrect'] ?? false) ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Score: ${_aiFeedback!['score']}%',
                        style: _patrickHand(
                          color: (_aiFeedback!['isCorrect'] ?? false) ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Question Content (Restoring missing text)
          if (_question!.content.isNotEmpty) ...[
             Text(
               _question!.content,
               style: _patrickHand(fontSize: 20, height: 1.5, color: AppColors.textPrimary),
             ),
             const SizedBox(height: 24),
          ],

          // MCQ Feedback (shown above options for MCQ)
          if (_aiFeedback != null && _question!.isMCQ) ...[
            WiredCard(
              padding: const EdgeInsets.all(16),
              backgroundColor: (_aiFeedback!['isCorrect'] ?? false)
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              borderColor: (_aiFeedback!['isCorrect'] ?? false) ? Colors.green : Colors.red,
              child: Row(
                children: [
                  Icon(
                    (_aiFeedback!['isCorrect'] ?? false) ? Icons.check_circle_outline : Icons.cancel_outlined,
                    color: (_aiFeedback!['isCorrect'] ?? false) ? Colors.green : Colors.red,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _aiFeedback!['feedback'] ?? '',
                      style: _patrickHand(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: (_aiFeedback!['isCorrect'] ?? false) ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
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
              final isCorrectTarget = option['label'] == _question!.effectiveCorrectAnswer;

              // Only mark as correct if selected AND correct. Don't spoil others.
              final isCorrect = _answerSubmitted && isSelected && isCorrectTarget;
              final isWrong = _answerSubmitted && isSelected && !isCorrectTarget;

              Color borderColor = _primaryColor.withValues(alpha: 0.2);
              if (isSelected) borderColor = Colors.blue;
              if (isCorrect) borderColor = Colors.green;
              if (isWrong) borderColor = Colors.red;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: _answerSubmitted ? null : () {
                     setState(() {
                       _selectedMcqAnswer = option['label'];
                     });
                  },
                  child: WiredCard(
                    borderColor: isSelected ? borderColor : _primaryColor.withValues(alpha: 0.3),
                    backgroundColor: isSelected ? Colors.blue.withValues(alpha: 0.05) : Colors.white,
                    borderWidth: isSelected ? 2.5 : 1.5,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Option Label (A, B, C...)
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isSelected ? borderColor.withValues(alpha: 0.1) : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? borderColor : _primaryColor.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: isCorrect
                                ? const Icon(Icons.check, color: Colors.green, size: 22)
                                : isWrong
                                    ? const Icon(Icons.close, color: Colors.red, size: 22)
                                    : Text(
                                        option['label'] ?? '',
                                        style: _patrickHand(
                                          color: isSelected ? Colors.blue : _primaryColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                        ),
                                      ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            option['text'] ?? '',
                            style: _patrickHand(
                              color: _primaryColor,
                              fontSize: 16,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            })),
            const SizedBox(height: 16),
            // MCQ Action Buttons REMOVED (Moved to BottomNavBar)
          ] else ...[
            // Text input for written questions
            WiredCard(
              padding: EdgeInsets.zero,
              child: TextField(
                controller: _studentAnswerController,
                maxLines: 5,
                enabled: !_answerSubmitted && !_isCheckingAnswer,
                style: _patrickHand(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Type your answer here...',
                  hintStyle: _patrickHand(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Check button for written
            // Written Check Button REMOVED (Moved to BottomNavBar)
          ],

          // Feedback (for non-MCQ only - MCQ feedback is shown above options)
          if (_aiFeedback != null && !_question!.isMCQ) ...[
            const SizedBox(height: 16),
            WiredCard(
              padding: const EdgeInsets.all(16),
              backgroundColor: (_aiFeedback!['isCorrect'] ?? false)
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              borderColor: (_aiFeedback!['isCorrect'] ?? false) ? Colors.green : Colors.red,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              (_aiFeedback!['isCorrect'] ?? false) ? Icons.check_circle_outline : Icons.cancel_outlined,
                              color: (_aiFeedback!['isCorrect'] ?? false) ? Colors.green : Colors.red,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                // Show earned/total marks if available, otherwise show feedback
                                _aiFeedback!.containsKey('earnedMarks') && _aiFeedback!.containsKey('totalMarks')
                                    ? 'You scored ${_aiFeedback!['earnedMarks']}/${_aiFeedback!['totalMarks']} marks (${_aiFeedback!['score']}%)'
                                    : (_aiFeedback!['feedback'] ?? ''),
                                style: _patrickHand(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: (_aiFeedback!['isCorrect'] ?? false) ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Show hints for all users (blurred for free users)
            if ((_aiFeedback!['hints'] as List?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              if (isPremium) 
                _buildFeedbackList('Hints', (_aiFeedback!['hints'] as List).cast<String>(), Colors.amber, Icons.lightbulb_outline)
              else
                _buildBlurredHintsWithUpgrade((_aiFeedback!['hints'] as List).cast<String>()),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAiSolutionTab() {
    // AI Explanation is FREE for all users

    // Always show the tab - display message if no content
    final hasContent = _question!.hasAiSolution;

    if (!hasContent) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            WiredCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   const Icon(Icons.auto_awesome_outlined, color: Colors.grey, size: 48),
                   const SizedBox(height: 12),
                   Text(
                    'AI explanation not available',
                    style: _patrickHand(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // AI Explanation is FREE for all users - show content directly
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Reduced from all(20)
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              WiredCard(
                padding: const EdgeInsets.all(8),
                backgroundColor: Colors.purple.withValues(alpha: 0.1),
                borderColor: Colors.purple,
                child: const Icon(Icons.auto_awesome, color: Colors.purple, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'AI Explanation',
                style: _patrickHand(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Structured Question Logic - Accordion style
          if (_question!.isStructured && _question!.structureData != null) ...[
            ...(_question!.structureData!.whereType<QuestionPartBlock>().toList().asMap().entries.map((entry) {
              final index = entry.key;
              final part = entry.value;
              final isExpanded = _expandedPartIndices.contains(index);

              return _buildExpandablePartCard(
                index: index,
                part: part,
                isExpanded: isExpanded,
                tabType: 'ai',
              );
            })),
          ] else ...[
            // Regular question - show single AI answer
            WiredCard(
              backgroundColor: const Color(0xFFFDFBF7),
              borderColor: Colors.purple.withValues(alpha: 0.5),
              borderWidth: 2,
              padding: const EdgeInsets.all(12), // Reduced from 20
              child: MarkdownBody(
                data: _question!.aiAnswer ?? 'No AI explanation available.',
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    fontFamily: 'PatrickHand',
                    color: const Color(0xFF2D3E50),
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOfficialAnswerTab() {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    if (!_question!.hasOfficialAnswer) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined, color: Colors.white24, size: 48),
            SizedBox(height: 12),
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
                      WiredCard(
                        padding: const EdgeInsets.all(8),
                        backgroundColor: Colors.green.withValues(alpha: 0.1),
                        borderColor: Colors.green,
                        child: const Icon(Icons.verified, color: Colors.green, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Official Mark Scheme',
                        style: _patrickHand(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 16),
                  Text(
                    _question!.officialAnswer,
                    style: _patrickHand(color: AppColors.textPrimary.withValues(alpha: 0.85), fontSize: 16, height: 1.5),
                  ),
                ],
              ),
            ),
          ),

          // Login prompt overlay
          Positioned.fill(
            child: Stack(
              children: [
                // Transparent blocking layer
                Container(color: Colors.transparent),

                // Centered floating card
                Center(
                  child: WiredCard(
                   width: 320,
                   backgroundColor: AppColors.background,
                   borderColor: Colors.blue,
                   borderWidth: 2,
                   padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                   child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.blue, width: 2),
                        ),
                        child: const Icon(
                          Icons.lock_outline,
                          size: 24,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Login to View Answer',
                        textAlign: TextAlign.center,
                        style: _patrickHand(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Create a free account to access official answers',
                          textAlign: TextAlign.center,
                          style: _patrickHand(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      WiredButton(
                        onPressed: () => context.go('/login'),
                        backgroundColor: Colors.blue,
                        filled: true,
                        borderColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                        child: Text(
                          'Login / Register',
                          style: _patrickHand(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                   ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Authenticated users see the normal content
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Reduced from all(20)
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              WiredCard(
                padding: const EdgeInsets.all(8),
                backgroundColor: Colors.green.withValues(alpha: 0.1),
                borderColor: Colors.green,
                child: const Icon(Icons.verified, color: Colors.green, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Official Mark Scheme',
                style: _patrickHand(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Check if structured question - Accordion style
          if (_question!.isStructured && _question!.structureData != null) ...[
            // Display all parts' official answers using accordion
            ...(_question!.structureData!.whereType<QuestionPartBlock>().toList().asMap().entries.map((entry) {
              final index = entry.key;
              final part = entry.value;
              final isExpanded = _expandedPartIndices.contains(index);

              return _buildExpandablePartCard(
                index: index,
                part: part,
                isExpanded: isExpanded,
                tabType: 'official',
              );
            })),
          ] else ...[
            // Regular question - show single official answer card
            WiredCard(
              backgroundColor: const Color(0xFFFDFBF7),
              borderColor: Colors.green.withValues(alpha: 0.5),
              borderWidth: 2,
              padding: const EdgeInsets.all(20),
              child: Html(
                data: _question!.officialAnswer,
                style: {
                  "body": Style(
                    color: const Color(0xFF2D3E50),
                    fontFamily: 'PatrickHand',
                    fontSize: FontSize(18),
                    lineHeight: LineHeight(1.6),
                    margin: Margins.zero,
                  ),
                },
              ),
            ),
          ],
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
                                      if (_question!.isStructured) {
                                        _checkStructuredAnswer();
                                      } else if (_studentAnswerController.text.trim().isNotEmpty) {
                                        _checkAnswer();
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                 padding: const EdgeInsets.symmetric(vertical: 8), // Reduced from 12
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

  /// Builds a blurred hints section with a premium upgrade overlay for free users
  Widget _buildBlurredHintsWithUpgrade(List<String> hints) {
    return Stack(
      children: [
        // Blurred hints content
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.amber, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Hints',
                        style: TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...hints.take(3).map((item) => Padding(
                    padding: const EdgeInsets.only(left: 22, bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: Colors.amber)),
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
              ),
            ),
          ),
        ),

        // Premium unlock overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.transparent,
            ),
            child: Center(
              child: WiredCard(
                backgroundColor: AppColors.background,
                borderColor: Colors.amber,
                borderWidth: 2,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber, width: 2),
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        size: 20,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Premium Feature',
                      style: _patrickHand(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Upgrade to unlock AI hints',
                      style: _patrickHand(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    WiredButton(
                      onPressed: () => context.push('/premium'),
                      backgroundColor: Colors.amber,
                      filled: true,
                      borderColor: Colors.amber.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Upgrade',
                            style: _patrickHand(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
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

  /// Build attempt status badge
  /// Build attempt status badge
  /// Build attempt status badge
  Widget _buildAttemptStatusBadge() {
    final attemptedAt = _previousAttempt != null
        ? DateTime.parse(_previousAttempt!['attempted_at'])
        : DateTime.now();
    final timeAgo = _previousAttempt != null
        ? _formatTimeAgo(attemptedAt)
        : 'Just now';
    final score = _previousAttempt != null
        ? _previousAttempt!['score'] as int?
        : (_aiFeedback?['score'] as int?);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20), // Fix overlap with margin
      child: WiredCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: _isViewingPreviousAnswer
              ? Colors.blue.withValues(alpha: 0.1)
              : Colors.green.withValues(alpha: 0.1),
      borderColor: _isViewingPreviousAnswer
              ? Colors.blue.shade300
              : Colors.green.shade300,
      child: Row(
        children: [
          Icon(
            _isViewingPreviousAnswer ? Icons.history : Icons.cloud_done,
            color: _isViewingPreviousAnswer
                ? Colors.blue.shade700
                : Colors.green.shade700,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isViewingPreviousAnswer
                      ? 'Viewing Previous Answer'
                      : 'Answer Saved',
                  style: _patrickHand( // Using Patrick Hand
                    color: _isViewingPreviousAnswer
                        ? Colors.blue.shade900
                        : Colors.green.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 16, // Slightly larger for handwritten style
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Attempted $timeAgo${score != null ? " • Score: $score%" : ""}',
                  style: _patrickHand( // Using Patrick Hand
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          if (_isViewingPreviousAnswer || _answerSubmitted)
            ElevatedButton.icon(
              onPressed: _retryQuestion,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month(s) ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day(s) ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour(s) ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute(s) ago';
    } else {
      return 'Just now';
    }
  }
}

