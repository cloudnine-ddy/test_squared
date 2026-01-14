import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import 'pdf_crop_viewer.dart';
import '../../../shared/wired/wired_widgets.dart'; // Add wired widgets

class GeneratedQuestionCard extends StatefulWidget {
  final Map<String, dynamic> questionData;
  final int questionIndex;
  final String? pdfUrl;

  const GeneratedQuestionCard({
    super.key,
    required this.questionData,
    this.questionIndex = 1,
    this.pdfUrl,
  });

  @override
  State<GeneratedQuestionCard> createState() => _GeneratedQuestionCardState();
}

class _GeneratedQuestionCardState extends State<GeneratedQuestionCard> {
  bool _showAnswer = false;
  bool _isSaving = false;
  bool _isSaved = false;
  bool? _isRecommended; // null = no vote, true = up, false = down

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

  Future<List<String>> _fetchFolders() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return [];

      final res = await Supabase.instance.client
          .from('user_bookmarks')
          .select('folder_name')
          .eq('user_id', userId);

      final folders = (res as List)
          .map((e) => e['folder_name'] as String)
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();

      // Default folders if empty
      if (folders.isEmpty) {
        return []; // Let user create their own folder
      }

      folders.sort();
      return folders;
    } catch (e) {
      return []; // Return empty on error, let user create folder
    }
  }

  Future<void> _handleSaveQuestion() async {
    if (_isSaved) return;

    // Show dialog
    final folder = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _SaveDialog(fetchFolders: _fetchFolders);
      },
    );

    if (folder == null || folder.trim().isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final qData = widget.questionData;

      // Prepare insert data based on question type
      final Map<String, dynamic> insertData = {
        'content': qData['content'] ?? '',
        'type': qData['type'] ?? 'ai_generated', // Use AI's type (mcq/structured)
        'marks': qData['marks'] ?? 0,
        'official_answer': qData['official_answer'] ?? '',
        'explanation': {'markdown': qData['explanation'] ?? ''},
        'topic_ids': [],
        'created_by': userId,
      };

      // Add MCQ-specific fields
      if (qData['type'] == 'mcq' && qData['options'] != null) {
        insertData['options'] = qData['options'];
        insertData['correct_answer'] = qData['correct_answer'];
      }

      // Add structured question fields
      if (qData['type'] == 'structured' && qData['structure_data'] != null) {
        insertData['structure_data'] = qData['structure_data'];
      }

      // 1. Insert into questions table
      final questionRes = await Supabase.instance.client
          .from('questions')
          .insert(insertData)
          .select('id')
          .single();

      final newQuestionId = questionRes['id'];

      // 2. Insert into user_bookmarks
      await Supabase.instance.client.from('user_bookmarks').insert({
        'user_id': userId,
        'question_id': newQuestionId,
        'folder_name': folder,
      });

      if (mounted) {
        setState(() {
          _isSaving = false;
          _isSaved = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to "$folder"!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleExpandPreview() {
    final heroTag = 'ai-card-${widget.questionIndex}';
    final content = widget.questionData['content'] ?? '';
    final marks = widget.questionData['total_marks'] ?? 
                  widget.questionData['marks'] ?? 0;
    final explanation = widget.questionData['ai_answer']?['explanation'] ?? 
                        widget.questionData['explanation'];

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        pageBuilder: (context, _, __) => Center(
          child: Hero(
            tag: heroTag,
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
                child: WiredCard(
                  backgroundColor: _backgroundColor,
                  borderColor: _primaryColor,
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row
                        Row(
                          children: [
                            WiredCard(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
                              borderColor: const Color(0xFF6366F1),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF6366F1)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'AI Q${widget.questionIndex}',
                                    style: _patrickHand(color: const Color(0xFF6366F1), fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Preview',
                                style: _patrickHand(color: Colors.orange, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Spacer(),
                            if (marks > 0)
                              Text(
                                '$marks marks',
                                style: _patrickHand(fontSize: 15, fontWeight: FontWeight.bold, color: _primaryColor.withValues(alpha: 0.6)),
                              ),
                            const SizedBox(width: 12),
                            InkWell(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: _primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(Icons.close, color: _primaryColor, size: 20),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Question Content
                        MarkdownBody(
                          data: content,
                          styleSheet: MarkdownStyleSheet(
                            p: _patrickHand(fontSize: 17, height: 1.5),
                            strong: _patrickHand(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // MCQ Options
                        if (widget.questionData['type'] == 'mcq' && widget.questionData['options'] != null) ...[
                          ...((widget.questionData['options'] as List).map((option) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: WiredCard(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                borderColor: _primaryColor.withValues(alpha: 0.15),
                                backgroundColor: Colors.white.withValues(alpha: 0.5),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(color: _primaryColor.withValues(alpha: 0.2)),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Center(
                                        child: Text(
                                          option['label'] ?? '',
                                          style: _patrickHand(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        option['text'] ?? '',
                                        style: _patrickHand(fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          })),
                          const SizedBox(height: 12),
                        ],

                        // Structured Question Parts
                        if (widget.questionData['type'] == 'structured' && widget.questionData['structure_data'] != null) ...[
                          ...((widget.questionData['structure_data'] as List).where((block) => block['type'] == 'question_part').map((part) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: WiredCard(
                                padding: const EdgeInsets.all(14),
                                borderColor: _primaryColor.withValues(alpha: 0.15),
                                backgroundColor: Colors.white.withValues(alpha: 0.5),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '(${part['label']})',
                                          style: _patrickHand(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF6366F1)),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${part['marks']} mk',
                                          style: _patrickHand(color: Colors.grey, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      part['content'] ?? '',
                                      style: _patrickHand(fontSize: 16, height: 1.4),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          })),
                          const SizedBox(height: 12),
                        ],

                        // AI Explanation Section
                        if (explanation != null) ...[
                          WiredCard(
                            padding: const EdgeInsets.all(14),
                            backgroundColor: const Color(0xFFF0F4F8),
                            borderColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.lightbulb, size: 18, color: Color(0xFF6366F1)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'AI Explanation',
                                      style: _patrickHand(fontWeight: FontWeight.bold, fontSize: 17, color: const Color(0xFF6366F1)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                MarkdownBody(
                                  data: explanation,
                                  styleSheet: MarkdownStyleSheet(
                                    p: _patrickHand(fontSize: 16, height: 1.4),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'AI generated — check with teacher for verification',
                                  style: _patrickHand(fontSize: 13, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          child: WiredButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _handleSaveQuestion();
                            },
                            backgroundColor: _primaryColor,
                            filled: true,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.bookmark_add, size: 20, color: Colors.white),
                                const SizedBox(width: 10),
                                Text(
                                  'Save to Collection',
                                  style: _patrickHand(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {

          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.questionData['content'] ?? 'No text provided';
    final marks = widget.questionData['marks'] ?? 0;
    final officialAnswer = widget.questionData['official_answer'];
    final explanation = widget.questionData['explanation'];

    final heroTag = 'ai-card-${widget.questionIndex}';

    return Hero(
      tag: heroTag,
      child: Material(
        type: MaterialType.transparency,
        child: WiredCard(
          backgroundColor: _backgroundColor,
          borderColor: _primaryColor.withValues(alpha: 0.2),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row - Sketchy Style
              Row(
                children: [
                  // AI Badge
                  WiredCard(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderColor: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, size: 12, color: Color(0xFF6366F1)),
                        const SizedBox(width: 4),
                        Text(
                          'AI Q${widget.questionIndex}',
                          style: _patrickHand(
                            color: const Color(0xFF6366F1),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Preview Badge
                  if (!_isSaved)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Preview',
                        style: _patrickHand(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),

                  if (!_isSaved) ...[ 
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: _handleExpandPreview,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.open_in_full, color: Colors.grey, size: 16),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (marks > 0)
                    Text(
                      '$marks marks',
                      style: _patrickHand(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // Question Content
              MarkdownBody(
                data: content,
                styleSheet: MarkdownStyleSheet(
                  p: _patrickHand(fontSize: 16, height: 1.5),
                  strong: _patrickHand(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),

              // MCQ Options - Sketchy Style
              if (widget.questionData['type'] == 'mcq' && widget.questionData['options'] != null) ...[
                ...((widget.questionData['options'] as List).map((option) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: WiredCard(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      borderColor: _primaryColor.withValues(alpha: 0.15),
                      backgroundColor: Colors.white.withValues(alpha: 0.5),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: _primaryColor.withValues(alpha: 0.2)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Center(
                              child: Text(
                                option['label'] ?? '',
                                style: _patrickHand(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option['text'] ?? '',
                              style: _patrickHand(fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                })),
                const SizedBox(height: 12),
              ],

              // Structured Question Parts - Sketchy Style
              if (widget.questionData['type'] == 'structured' && widget.questionData['structure_data'] != null) ...[
                ...((widget.questionData['structure_data'] as List).where((block) => block['type'] == 'question_part').map((part) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: WiredCard(
                      padding: const EdgeInsets.all(12),
                      borderColor: _primaryColor.withValues(alpha: 0.15),
                      backgroundColor: Colors.white.withValues(alpha: 0.5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '(${part['label']})',
                                style: _patrickHand(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: const Color(0xFF6366F1),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${part['marks']} mk',
                                style: _patrickHand(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            part['content'] ?? '',
                            style: _patrickHand(fontSize: 15, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  );
                })),
                const SizedBox(height: 12),
              ],

              // Dynamic Figure Rendering
              if (widget.pdfUrl != null &&
                  widget.questionData['ai_answer'] != null &&
                  widget.questionData['ai_answer']['figure_location'] != null) ...[
                 Builder(
                   builder: (context) {
                     final loc = widget.questionData['ai_answer']['figure_location'];
                     return Padding(
                       padding: const EdgeInsets.only(bottom: 16.0),
                       child: PdfCropViewer(
                         pdfUrl: widget.pdfUrl!,
                         pageNumber: loc['page'] ?? 1,
                         x: (loc['x_percent'] ?? 0).toDouble(),
                         y: (loc['y_percent'] ?? 0).toDouble(),
                         width: (loc['width_percent'] ?? 100).toDouble(),
                         height: (loc['height_percent'] ?? 100).toDouble(),
                       ),
                     );
                   }
                 ),
              ],

              // Answer Section
              if (_showAnswer) ...[
                WiredCard(
                  padding: const EdgeInsets.all(12),
                  backgroundColor: const Color(0xFFF0F4F8),
                  borderColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lightbulb, size: 16, color: Color(0xFF6366F1)),
                          const SizedBox(width: 8),
                          Text(
                            'AI Explanation',
                            style: _patrickHand(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF6366F1)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      MarkdownBody(
                        data: explanation ?? 'No explanation available.',
                        styleSheet: MarkdownStyleSheet(
                          p: _patrickHand(fontSize: 15, height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'AI generated — check with teacher for verification',
                        style: _patrickHand(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Footer Actions
              Row(
                children: [
                  Expanded(
                    child: WiredButton(
                      onPressed: () => setState(() => _showAnswer = !_showAnswer),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _showAnswer ? Icons.visibility_off_outlined : Icons.visibility_outlined, 
                            size: 18,
                            color: _primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _showAnswer ? 'Hide Answer' : 'Show Answer',
                            style: _patrickHand(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: WiredDivider(),
              ),

              // Recommendation UI
              if (_isSaved && _showAnswer) ...[
                 Row(
                   children: [
                     Expanded(
                       child: Text(
                         'Recommend this question?', 
                         style: _patrickHand(fontSize: 14, color: Colors.grey),
                       ),
                     ),
                     IconButton(
                       icon: Icon(
                         _isRecommended == true ? Icons.thumb_up : Icons.thumb_up_outlined, 
                         size: 20,
                       ),
                       color: _isRecommended == true ? const Color(0xFF10B981) : _primaryColor,
                       onPressed: () => setState(() => _isRecommended = true),
                     ),
                     IconButton(
                       icon: Icon(
                         _isRecommended == false ? Icons.thumb_down : Icons.thumb_down_outlined, 
                         size: 20,
                       ),
                       color: _isRecommended == false ? const Color(0xFFEF4444) : _primaryColor,
                       onPressed: () => setState(() => _isRecommended = false),
                     ),
                   ],
                 ),
                 const SizedBox(height: 8),
              ],

              // Save Button
              SizedBox(
                width: double.infinity,
                child: WiredButton(
                  onPressed: _isSaved || _isSaving ? null : _handleSaveQuestion,
                  backgroundColor: _isSaved ? const Color(0xFF10B981) : _primaryColor,
                  filled: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_isSaved ? Icons.check : Icons.bookmark_add, size: 18, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              _isSaved ? 'Saved to Library' : 'Save to Collection',
                              style: _patrickHand(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isSavings => _isSaving;
}

/// Separate widget for dialog to manage state (Selection vs New Input)
class _SaveDialog extends StatefulWidget {
  final Future<List<String>> Function() fetchFolders;

  const _SaveDialog({required this.fetchFolders});

  @override
  State<_SaveDialog> createState() => _SaveDialogState();
}

class _SaveDialogState extends State<_SaveDialog> {
  String? _selectedFolder;
  final TextEditingController _newFolderController = TextEditingController();
  List<String> _existingFolders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final folders = await widget.fetchFolders();
    if (mounted) {
      setState(() {
        _existingFolders = folders;
        if (folders.isNotEmpty) _selectedFolder = folders.first;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent, // Use WiredCard background
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: WiredCard(
          backgroundColor: const Color(0xFFFDFBF7),
          borderColor: const Color(0xFF2D3E50),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  WiredCard(
                    padding: const EdgeInsets.all(8),
                    backgroundColor: Colors.amber.withValues(alpha: 0.1),
                    borderColor: Colors.amber,
                    child: const Icon(Icons.bookmark, color: Colors.amber, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Bookmark Question',
                    style: TextStyle(
                      fontFamily: 'PatrickHand',
                      color: const Color(0xFF2D3E50),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_isLoading)
                 const Center(child: CircularProgressIndicator())
              else ...[
                // Folder Selection (only if folders exist)
                if (_existingFolders.isNotEmpty) ...[
                  Text(
                    'SELECT EXISTING FOLDER',
                    style: TextStyle(
                      fontFamily: 'PatrickHand',
                      color: Colors.grey[600],
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: WiredCard(
                      padding: EdgeInsets.zero,
                      borderColor: const Color(0xFF2D3E50).withValues(alpha: 0.2),
                      backgroundColor: Colors.white.withValues(alpha: 0.5),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _existingFolders.length,
                        separatorBuilder: (_, __) => const WiredDivider(),
                        itemBuilder: (context, index) {
                          final folder = _existingFolders[index];
                          final isSelected = _selectedFolder == folder && _newFolderController.text.isEmpty;
                          return ListTile(
                            dense: true,
                            onTap: () {
                              setState(() {
                                _selectedFolder = folder;
                                _newFolderController.clear();
                              });
                            },
                            leading: Icon(
                              Icons.folder,
                              color: isSelected ? Colors.amber[700] : Colors.grey,
                              size: 20,
                            ),
                            title: Text(
                              folder,
                              style: TextStyle(
                                fontFamily: 'PatrickHand',
                                fontSize: 16,
                                color: isSelected ? Colors.amber[900] : const Color(0xFF2D3E50),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            trailing: isSelected
                              ? Icon(Icons.check, color: Colors.amber[700], size: 18)
                              : null,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  // Empty state - no folders yet
                  WiredCard(
                    padding: const EdgeInsets.all(16),
                    borderColor: Colors.amber.withValues(alpha: 0.3),
                    backgroundColor: Colors.amber.withValues(alpha: 0.05),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber[700], size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No folders yet! Create your first folder below.',
                            style: TextStyle(
                              fontFamily: 'PatrickHand',
                              fontSize: 15,
                              color: Colors.amber[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],


                // Create New Folder
                Text(
                  'CREATE NEW FOLDER',
                  style: TextStyle(
                    fontFamily: 'PatrickHand',
                    color: Colors.grey[600],
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                WiredCard(
                  padding: EdgeInsets.zero,
                  borderColor: const Color(0xFF2D3E50).withValues(alpha: 0.2),
                  backgroundColor: Colors.white,
                  child: TextField(
                    controller: _newFolderController,
                    style: const TextStyle(fontFamily: 'PatrickHand', fontSize: 16, color: Color(0xFF2D3E50)),
                    decoration: InputDecoration(
                      hintText: 'Enter folder name...',
                      hintStyle: TextStyle(fontFamily: 'PatrickHand', fontSize: 16, color: Colors.grey.withValues(alpha: 0.5)),
                      prefixIcon: Icon(Icons.create_new_folder, color: Colors.grey.withValues(alpha: 0.5), size: 20),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(fontFamily: 'PatrickHand', color: Colors.grey[600], fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    WiredButton(
                      onPressed: () {
                        final folder = _newFolderController.text.isNotEmpty
                            ? _newFolderController.text
                            : _selectedFolder;
                        Navigator.pop(context, folder);
                      },
                      backgroundColor: const Color(0xFF2D3E50),
                      filled: true,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      child: Text(
                        'Confirm',
                        style: TextStyle(
                          fontFamily: 'PatrickHand',
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
