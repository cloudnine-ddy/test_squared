import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';

class GeneratedQuestionCard extends StatefulWidget {
  final Map<String, dynamic> questionData;
  final int questionIndex;

  const GeneratedQuestionCard({
    super.key,
    required this.questionData,
    this.questionIndex = 1,
  });

  @override
  State<GeneratedQuestionCard> createState() => _GeneratedQuestionCardState();
}

class _GeneratedQuestionCardState extends State<GeneratedQuestionCard> {
  bool _showAnswer = false;
  bool _isSaving = false;
  bool _isSaved = false;
  bool? _isRecommended; // null = no vote, true = up, false = down

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
        return ['Hard Questions', 'Review Later', 'Exams'];
      }

      folders.sort();
      return folders;
    } catch (e) {
      return ['Hard Questions', 'Review Later', 'Exams']; // Fallback
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

      // 1. Insert into questions table
      final questionRes = await Supabase.instance.client.from('questions').insert({
        'content': qData['content'] ?? '',
        'type': 'ai_generated',
        'marks': qData['marks'] ?? 0,
        'official_answer': qData['official_answer'] ?? '',
        'explanation': {'markdown': qData['explanation'] ?? ''},
        'topic_ids': [],
        'created_by': userId,
      }).select('id').single();

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
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F0E1),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 5),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'AI Generated Question #${widget.questionIndex}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                             decoration: BoxDecoration(
                               color: Colors.orange.withOpacity(0.2),
                               borderRadius: BorderRadius.circular(8),
                               border: Border.all(color: Colors.orange, width: 0.5),
                             ),
                             child: const Text(
                               'Preview',
                               style: TextStyle(color: Colors.deepOrange, fontSize: 12, fontWeight: FontWeight.bold),
                             ),
                           ),
                           const Spacer(),
                           IconButton(
                             icon: const Icon(Icons.close, color: Colors.grey),
                             onPressed: () => Navigator.pop(context),
                           ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Content
                      MarkdownBody(
                        data: widget.questionData['content'] ?? '',
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(fontSize: 16, height: 1.6, color: Color(0xFF2D2D2D)),
                          strong: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Show Answer Button (Functional in Preview?)
                      // User requested "Show Answer" in preview too?
                      // Screenshot has "Show Answer" (eye icon).
                      // I'll add a simple TextButton placeholder or functional toggle inside dialog?
                      // Functional requires Stateful dialog.
                      // For now, I'll just show the Save button as primary action.

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                             Navigator.pop(context); // Close preview
                             _handleSaveQuestion(); // Trigger save
                          },
                          icon: const Icon(Icons.bookmark_add, size: 20),
                          label: const Text('Save to Collection'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE8DCC8),
                            foregroundColor: const Color(0xFF5D4037),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F0E1), // Beige
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8DCC8), width: 1),
            boxShadow: [
               BoxShadow(
                 color: Colors.black.withOpacity(0.05),
                 blurRadius: 4,
                 offset: const Offset(0, 2),
               )
            ],
          ),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'AI Generated Question #${widget.questionIndex}',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              if (!_isSaved)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange, width: 0.5),
                  ),
                  child: const Text(
                    'Preview',
                    style: TextStyle(color: Colors.deepOrange, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),

              if (!_isSaved) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: _handleExpandPreview,
                  child: const Icon(Icons.fullscreen, color: Colors.deepOrange, size: 20),
                ),
              ],
              const Spacer(),
              if (marks > 0)
                Text(
                  '$marks marks',
                  style: const TextStyle(
                    color: Color(0xFF8B6F47),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Question Content
          MarkdownBody(
            data: content,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(
                color: Color(0xFF2D2D2D),
                fontSize: 15,
                height: 1.5,
              ),
              strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
            ),
          ),
          const SizedBox(height: 20),

          // Answer Section
          if (_showAnswer) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI Explanation:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                  ),
                  const SizedBox(height: 6),
                  MarkdownBody(data: explanation ?? 'No explanation available.'),

                  const SizedBox(height: 12),
                  const Divider(height: 16),
                  const Text(
                    'Note: AI generated questions do not have verified official answer keys.',
                    style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],

          // Footer Actions
          Row(
            children: [
               TextButton.icon(
                onPressed: () => setState(() => _showAnswer = !_showAnswer),
                icon: Icon(_showAnswer ? Icons.visibility_off : Icons.visibility, size: 16),
                label: Text(
                  _showAnswer ? 'Hide Answer' : 'Show Answer',
                  style: const TextStyle(fontSize: 13),
                ),
                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
              ),
            ],
          ),

          const Divider(height: 24),

          // Recommendation UI (Last section)
          // Recommendation UI (Last section)
          if (_isSaved && _showAnswer) ...[
             Row(
               children: [
                 const Expanded(child: Text('Do you recommend this question to someone else?', style: TextStyle(fontSize: 12, color: Colors.grey))),
                 const SizedBox(width: 8),
                 IconButton(
                   icon: Icon(_isRecommended == true ? Icons.thumb_up : Icons.thumb_up_outlined, size: 18),
                   color: _isRecommended == true ? Colors.green : Colors.grey,
                   onPressed: () => setState(() => _isRecommended = true),
                   padding: EdgeInsets.zero,
                   constraints: const BoxConstraints(),
                 ),
                 const SizedBox(width: 12),
                 IconButton(
                   icon: Icon(_isRecommended == false ? Icons.thumb_down : Icons.thumb_down_outlined, size: 18),
                   color: _isRecommended == false ? Colors.red : Colors.grey,
                   onPressed: () => setState(() => _isRecommended = false),
                   padding: EdgeInsets.zero,
                   constraints: const BoxConstraints(),
                 ),
               ],
             ),
             const SizedBox(height: 12),
          ],

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSavings ? null : (_isSaved ? null : _handleSaveQuestion),
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_isSaved ? Icons.check : Icons.bookmark_add, size: 18),
              label: Text(_isSaved ? 'Saved to Collection' : 'Save to Collection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSaved ? Colors.green : const Color(0xFFE8DCC8),
                foregroundColor: _isSaved ? Colors.white : const Color(0xFF5D4037),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
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
      backgroundColor: AppColors.sidebar,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bookmark, color: Colors.amber, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Bookmark Question',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (_isLoading)
               const Center(child: CircularProgressIndicator())
            else ...[
              // Folder Selection
              const Text(
                'SELECT FOLDER',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _existingFolders.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: Colors.white.withOpacity(0.1),
                  ),
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
                        color: isSelected ? Colors.amber : Colors.grey,
                        size: 20,
                      ),
                      title: Text(
                        folder,
                        style: TextStyle(
                          color: isSelected ? Colors.amber : Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                        ? const Icon(Icons.check, color: Colors.amber, size: 18)
                        : null,
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Create New Folder
              const Text(
                'CREATE NEW FOLDER',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newFolderController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter folder name...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  prefixIcon: Icon(Icons.create_new_folder, color: Colors.white.withOpacity(0.3), size: 20),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.amber),
                  ),
                ),
                onChanged: (val) {
                  if (val.isNotEmpty && _selectedFolder != null) {
                    setState(() => _selectedFolder = null);
                  }
                },
              ),

              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      String finalFolder = _newFolderController.text.trim();
                      if (finalFolder.isEmpty) {
                        finalFolder = _selectedFolder ?? 'Hard Questions';
                      }
                      Navigator.pop(context, finalFolder);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Save Bookmark', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
