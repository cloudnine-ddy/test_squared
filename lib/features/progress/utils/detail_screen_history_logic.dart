// Example: Enhanced Question Detail Screen with History Loading

// Add these to your existing _QuestionDetailScreenState class:

  Map<String, dynamic>? _previousAttempt;
  bool _isViewingPreviousAnswer = false;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _questionStartTime = DateTime.now();
    _loadQuestion();
    _loadBookmarkAndNoteStatus();
    _loadPreviousAttempt(); // NEW: Load previous attempt if exists
  }

  /// NEW METHOD: Load previous attempt
  Future<void> _loadPreviousAttempt() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null || _question == null) return;

      final attempt = await _progressRepo.getLastAttempt(userId, widget.questionId);

      if (attempt != null && mounted) {
        setState(() {
          _previousAttempt = attempt.toMap();
          _isViewingPreviousAnswer = true;

          // Pre-fill the answer
          if (attempt.answerText != null) {
            _studentAnswerController.text = attempt.answerText!;
          }
          if (attempt.selectedOption != null) {
            _selectedMcqAnswer = attempt.selectedOption;
          }

          // Show the feedback automatically
          _aiFeedback = {
            'score': attempt.score,
            'is_correct': attempt.isCorrect,
            'feedback': 'Previously submitted answer',
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

  /// NEW METHOD: Retry/Clear form
  void _retryQuestion() {
    setState(() {
      _isViewingPreviousAnswer = false;
      _isRetrying = true;
      _studentAnswerController.clear();
      _selectedMcqAnswer = null;
      _aiFeedback = null;
      _answerSubmitted = false;
      _questionStartTime = DateTime.now(); // Reset timer
    });
  }

  // UPDATE _checkAnswer to handle retry mode
  Future<void> _checkAnswer() async {
    // ... existing code ...

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
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
          'userId': userId,
          'timeSpent': timeSpent,
          'hintsUsed': 0,
          'selectedOption': _selectedMcqAnswer,
        },
      );

      if (response.status == 200 && response.data != null) {
        setState(() {
          _aiFeedback = response.data as Map<String, dynamic>;
          _answerSubmitted = true;
          _isCheckingAnswer = false;
          _isViewingPreviousAnswer = false; // This is now a NEW attempt
          _isRetrying = false;
        });

        print('✅ Progress saved by Edge Function');
      } else {
        throw Exception(response.data?['error'] ?? 'Unknown error');
      }
    } catch (e) {
      // ... existing error handling ...
    }
  }
