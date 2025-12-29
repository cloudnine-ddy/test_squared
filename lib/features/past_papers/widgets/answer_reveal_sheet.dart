import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Bottom sheet content for revealing answers (Official & AI).
class AnswerRevealSheet extends StatefulWidget {
  final String officialAnswer;
  final String aiSolution;
  final bool hasOfficialAnswer;
  final bool hasAiSolution;

  const AnswerRevealSheet({
    super.key,
    required this.officialAnswer,
    required this.aiSolution,
    required this.hasOfficialAnswer,
    required this.hasAiSolution,
  });

  @override
  State<AnswerRevealSheet> createState() => _AnswerRevealSheetState();
}

class _AnswerRevealSheetState extends State<AnswerRevealSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = [];

  @override
  void initState() {
    super.initState();
    if (widget.hasOfficialAnswer) _tabs.add('Official Answer');
    if (widget.hasAiSolution) _tabs.add('AI Solution');

    // Default Tab
    _tabController = TabController(length: _tabs.isNotEmpty ? _tabs.length : 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tabs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        color: const Color(0xFF151A23),
        child: const Text('No answer available.', style: TextStyle(color: Colors.white54)),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF151A23), // Lighter card color
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Tab Bar
          if (_tabs.length > 1)
            TabBar(
              controller: _tabController,
              labelColor: Colors.blueAccent,
              unselectedLabelColor: Colors.white54,
              indicatorColor: Colors.blueAccent,
              dividerColor: Colors.white10,
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
            ),

          // Content
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
              minHeight: 200,
            ),
            child: _tabs.length > 1
                ? TabBarView(
                    controller: _tabController,
                    children: [
                      if (widget.hasOfficialAnswer) _buildContent(widget.officialAnswer),
                      if (widget.hasAiSolution) _buildContent(widget.aiSolution),
                    ],
                  )
                : _buildContent(widget.hasOfficialAnswer ? widget.officialAnswer : widget.aiSolution),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(String content) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: SelectableText(
        content,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          height: 1.6,
          fontFamily: 'Roboto', // Or preferred reading font
        ),
      ),
    );
  }
}
