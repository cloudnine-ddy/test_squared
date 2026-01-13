import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../data/past_paper_repository.dart'; // Added import
import '../../../shared/wired/wired_widgets.dart'; // Sketchy widgets
import 'chat_message.dart';
import 'generated_question_card.dart';

/// AI Chat Panel for the right side of split screen
class AIChatPanel extends StatefulWidget {
  final String questionId;
  final bool isPremium;
  final VoidCallback? onClose; // Added callback

  const AIChatPanel({
    super.key,
    required this.questionId,
    required this.isPremium,
    this.onClose,
  });

  @override
  State<AIChatPanel> createState() => _AIChatPanelState();
}

class _AIChatPanelState extends State<AIChatPanel> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  // User's attempt context
  String? _userAnswer;
  int? _userScore;
  int _generatedQuestionCount = 0;
  String? _pdfUrl;

  // Sketchy Theme Constants
  static const _primaryColor = Color(0xFF2D3E50);
  static const _backgroundColor = Color(0xFFFDFBF7);

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
    _loadUserAttempt();
    _loadQuestionDetails(); // Load PDF URL
    // Welcome message
    _messages.add({
      'message': 'Hi! I\'m your AI study assistant. I can help explain this question, give hints, or check your understanding. How can I help you today?',
      'isAI': true,
      'timestamp': DateTime.now(),
    });
  }

  Future<void> _loadQuestionDetails() async {
    try {
      final question = await PastPaperRepository().getQuestionById(widget.questionId);
      if (question?.pdfUrl != null && mounted) {
        setState(() {
          _pdfUrl = question!.pdfUrl;
        });
      }
    } catch (e) {
      print('Error loading question details: $e');
    }
  }

  Future<void> _loadUserAttempt() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
        .from('user_question_attempts')
        .select('answer_text, selected_option, score')
        .eq('user_id', userId)
        .eq('question_id', widget.questionId)
        .order('attempted_at', ascending: false)
        .limit(1)
        .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _userAnswer = response['answer_text'] ?? response['selected_option'];
          _userScore = response['score'];
        });
        print('📝 Loaded user attempt: score=$_userScore');
      }
    } catch (e) {
      print('Error loading user attempt: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage({String? intent}) async {
    if (_messageController.text.trim().isEmpty) return;
    if (!widget.isPremium) return;

    final userMessage = _messageController.text.trim();

    setState(() {
      _messages.add({
        'message': userMessage,
        'isAI': false,
        'timestamp': DateTime.now(),
      });
      _isTyping = true;
    });

    _messageController.clear();
    _scrollToBottom();

    // Call AI Chat Edge Function
    try {
      // Prepare conversation history without DateTime objects
      final conversationForAPI = _messages
          .where((m) => m['isAI'] == true || m['message'] != userMessage) // Filter out current message to avoid dupe if logic requires
          .take(_messages.length - 1) // Logic check: we just added the user message.
          .map((msg) => {
                'message': msg['message'],
                'isAI': msg['isAI'],
              })
          .toList();

      final response = await Supabase.instance.client.functions.invoke(
        'ai-chat',
        body: {
          'questionId': widget.questionId,
          'userMessage': userMessage,
          'conversationHistory': conversationForAPI,
          'userAnswer': _userAnswer,
          'userScore': _userScore,
          'intent': intent,
        },
      );

      if (mounted) {
        final data = response.data;
        setState(() {
          _isTyping = false;
            if (data != null && data['error'] == null) {
              int? qIndex;
              if (data['generated_question'] != null) {
                _generatedQuestionCount++;
                qIndex = _generatedQuestionCount;
              }

              _messages.add({
                'message': data['message'],
                'isAI': true,
                'timestamp': DateTime.now(),
                'generated_question': data['generated_question'],
                'questionIndex': qIndex,
              });
          } else {
            _messages.add({
              'message': data?['error'] ?? 'Something went wrong. Please try again.',
              'isAI': true,
              'timestamp': DateTime.now(),
            });
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({
            'message': 'Error: Unable to connect to AI assistant.',
            'isAI': true,
            'timestamp': DateTime.now(),
          });
        });
        _scrollToBottom();
      }
      print('AI Chat Error: $e');
    }
  }

  void _sendQuickPrompt(String prompt) {
    _messageController.text = prompt;
    String? intent;
    if (prompt == 'Generate similar question') {
      intent = 'generate_question';
    }
    _sendMessage(intent: intent);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container( // Main panel container
      decoration: BoxDecoration(
        color: _backgroundColor,
        border: Border(
           left: BorderSide(color: _primaryColor.withValues(alpha: 0.2), width: 1.5),
        ),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),

          // Messages
          Expanded(
            child: widget.isPremium
                ? _buildChatArea()
                : _buildPremiumLock(),
          ),

          // Quick prompts
          if (widget.isPremium) _buildQuickPrompts(),

          // Prominent Generate Button
          if (widget.isPremium) _buildGenerateButton(),

          // Input
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: _primaryColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.psychology,
              color: _primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Study Assistant',
                  style: _patrickHand(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Online',
                      style: _patrickHand(
                        fontSize: 12, 
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!widget.isPremium)
            WiredCard(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              backgroundColor: const Color(0xFFFFD700).withValues(alpha: 0.2),
              borderColor: const Color(0xFFFFD700),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.workspace_premium,
                    color: Color(0xFFD4AF37),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Premium',
                    style: _patrickHand(
                      color: const Color(0xFFD4AF37),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          if (widget.onClose != null) ...[
            const SizedBox(width: 12),
            WiredButton(
              onPressed: widget.onClose,
              backgroundColor: Colors.transparent,
              borderColor: AppColors.textSecondary.withValues(alpha: 0.4),
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 20, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return const TypingIndicator();
        }

        final msg = _messages[index];
        return ChatMessage(
          message: msg['message'],
          isAI: msg['isAI'],
          timestamp: msg['timestamp'],
          contentWidget: (msg['isAI'] && msg['generated_question'] != null)
              ? GeneratedQuestionCard(
                  questionData: msg['generated_question'],
                  questionIndex: msg['questionIndex'] ?? 1,
                  pdfUrl: _pdfUrl,
                )
              : null,
        );
      },
    );
  }

  Future<void> _saveGeneratedQuestion(Map<String, dynamic> data) async {
    // Placeholder logic for saving generated question
    // In a real app, this would insert the question into the DB and create a bookmark
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Question added to your session! (Simulated)'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildPremiumLock() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            WiredCard(
              padding: const EdgeInsets.all(24),
               backgroundColor: const Color(0xFFFFD700).withValues(alpha: 0.1),
               borderColor: const Color(0xFFFFD700),
               child: Icon(
                Icons.workspace_premium,
                color: const Color(0xFFD4AF37),
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unlock AI Assistant',
              style: _patrickHand(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Get instant help, hints, and explanations\nfor any question with Premium',
              textAlign: TextAlign.center,
              style: _patrickHand(
                color: AppColors.textSecondary,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            WiredButton(
              onPressed: () {
                context.push('/premium');
              },
              backgroundColor: const Color(0xFFD4AF37),
              filled: true,
              borderColor: const Color(0xFFB8860B),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 20, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Upgrade to Premium',
                    style: _patrickHand(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPrompts() {
    final prompts = [
      ('💡', 'Explain this question'),
      ('🎯', 'Give me a hint'),
      ('✅', 'Check my understanding'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: _backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Prompts',
            style: _patrickHand(
              color: Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: prompts.map((prompt) {
              return InkWell(
                onTap: () => _sendQuickPrompt(prompt.$2),
                child: WiredCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    borderColor: _primaryColor.withValues(alpha: 0.3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(prompt.$1, style: const TextStyle(fontSize: 14)), // Emoji can be standard font
                        const SizedBox(width: 6),
                        Text(
                          prompt.$2,
                          style: _patrickHand(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _backgroundColor,
        border: Border(
          top: BorderSide(
            color: _primaryColor.withValues(alpha: 0.1),
            width: 1
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: WiredCard(
              padding: EdgeInsets.zero,
              child: TextField(
                controller: _messageController,
                enabled: widget.isPremium,
                decoration: InputDecoration(
                  hintText: widget.isPremium
                      ? 'Ask anything about this question...'
                      : 'Upgrade to Premium to chat',
                  hintStyle: _patrickHand(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: InputBorder.none,
                ),
                style: _patrickHand(fontSize: 16),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          WiredButton(
            onPressed: widget.isPremium ? () => _sendMessage() : () {},
            backgroundColor: widget.isPremium ? _primaryColor : Colors.grey,
            filled: true,
            child: const Icon(Icons.send, size: 20, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
     return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      color: _backgroundColor, // Match background
      child: WiredButton(
        onPressed: () => _sendQuickPrompt('Generate similar question'),
        backgroundColor: Colors.amber[50],
        filled: true,
        borderColor: Colors.amber[600]!,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, color: Colors.orange[600], size: 20),
            const SizedBox(width: 8),
            Text(
              'Generate Similar Question',
              style: _patrickHand(
                color: Colors.orange[700],
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
