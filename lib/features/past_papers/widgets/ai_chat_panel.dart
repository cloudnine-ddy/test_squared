import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'chat_message.dart';

/// AI Chat Panel for the right side of split screen
class AIChatPanel extends StatefulWidget {
  final String questionId;
  final bool isPremium;

  const AIChatPanel({
    super.key,
    required this.questionId,
    required this.isPremium,
  });

  @override
  State<AIChatPanel> createState() => _AIChatPanelState();
}

class _AIChatPanelState extends State<AIChatPanel> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    // Welcome message
    _messages.add({
      'message': 'Hi! I\'m your AI study assistant. I can help explain this question, give hints, or check your understanding. How can I help you today?',
      'isAI': true,
      'timestamp': DateTime.now(),
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
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

    // Simulate AI response (replace with actual API call)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _messages.add({
            'message': 'I understand your question. Let me help you with that...\n\nThis is a placeholder response. In the full implementation, this will connect to your AI backend to provide helpful explanations and guidance.',
            'isAI': true,
            'timestamp': DateTime.now(),
          });
          _isTyping = false;
        });
        _scrollToBottom();
      }
    });
  }

  void _sendQuickPrompt(String prompt) {
    _messageController.text = prompt;
    _sendMessage();
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          left: BorderSide(color: AppColors.border, width: 1),
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
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.psychology,
              color: AppColors.primary,
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
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!widget.isPremium)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD700), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.workspace_premium,
                    color: const Color(0xFFD4AF37),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Premium',
                    style: TextStyle(
                      color: const Color(0xFFD4AF37),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
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
        );
      },
    );
  }

  Widget _buildPremiumLock() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(
                Icons.workspace_premium,
                color: const Color(0xFFD4AF37),
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unlock AI Assistant',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Get instant help, hints, and explanations\nfor any question with Premium',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // TODO: Navigate to premium upgrade
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Upgrade to Premium',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
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
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Prompts',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: prompts.map((prompt) {
              return InkWell(
                onTap: () => _sendQuickPrompt(prompt.$2),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(prompt.$1, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        prompt.$2,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
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
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: widget.isPremium,
              decoration: InputDecoration(
                hintText: widget.isPremium 
                    ? 'Ask anything about this question...'
                    : 'Upgrade to Premium to chat',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.border, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.border, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: widget.isPremium ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(24),
            ),
            child: IconButton(
              onPressed: widget.isPremium ? _sendMessage : null,
              icon: const Icon(Icons.send, size: 20),
              color: Colors.white,
              padding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }
}
