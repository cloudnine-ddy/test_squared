import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/toast_service.dart';
import '../data/bookmark_repository.dart';
import '../data/notes_repository.dart';
import '../../past_papers/models/question_model.dart';
import 'note_editor_dialog.dart';
import '../widgets/bookmark_folder_panel.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final _bookmarkRepo = BookmarkRepository();
  final _notesRepo = NotesRepository();

  List<String> _folders = [];
  String _selectedFolder = 'My Bookmarks';
  List<QuestionModel> _questions = [];
  Map<String, bool> _hasNotes = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final folders = await _bookmarkRepo.getFolders();
      if (folders.isEmpty) {
        folders.add('My Bookmarks');
      }

      setState(() {
        _folders = folders;
        if (!folders.contains(_selectedFolder)) {
          _selectedFolder = folders.first;
        }
      });

      await _loadQuestions();
    } catch (e) {
      ToastService.showError('Failed to load bookmarks');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadQuestions() async {
    try {
      final questions = await _bookmarkRepo.getBookmarkedQuestions(
        folder: _selectedFolder,
      );

      // Check which questions have notes
      final hasNotes = <String, bool>{};
      for (final q in questions) {
        hasNotes[q.id] = await _notesRepo.hasNote(q.id);
      }

      if (mounted) {
        setState(() {
          _questions = questions;
          _hasNotes = hasNotes;
        });
      }
    } catch (e) {
      ToastService.showError('Failed to load questions');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bookmarks'),
        backgroundColor: AppColors.sidebar,
      ),
      body: Row(
        children: [
          // Folder panel
          BookmarkFolderPanel(
            folders: _folders,
            selectedFolder: _selectedFolder,
            onFolderSelected: (folder) {
              setState(() => _selectedFolder = folder);
              _loadQuestions();
            },
            onCreateFolder: _showCreateFolderDialog,
            onDeleteFolder: _deleteFolder,
            onRenameFolder: _renameFolder,
          ),
          // Vertical divider
          Container(
            width: 1,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          // Content area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_questions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No bookmarks in this folder',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bookmark questions while practicing',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadQuestions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _questions.length,
        itemBuilder: (context, index) {
          final question = _questions[index];
          final hasNote = _hasNotes[question.id] ?? false;

          return _buildQuestionCard(question, hasNote);
        },
      ),
    );
  }

  Widget _buildQuestionCard(QuestionModel question, bool hasNote) {
    final isAI = question.type == 'ai_generated';
    final cardColor = isAI ? const Color(0xFFF5F0E1) : AppColors.sidebar;
    final textColor = isAI ? const Color(0xFF2D2D2D) : Colors.white;
    final borderColor = isAI ? const Color(0xFFE8DCC8) : Colors.white.withValues(alpha: 0.1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isAI
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: InkWell(
        onTap: () => context.push('/question/${question.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isAI ? AppColors.primary : null,
                      gradient: isAI
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                            ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isAI ? 'AI Generated' : 'Q${question.questionNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (question.isMCQ && !isAI)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'MCQ',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (hasNote)
                    Icon(
                      Icons.note,
                      color: isAI ? Colors.orange : Colors.amber,
                      size: 18,
                    ),
                  const SizedBox(width: 8),
                  PopupMenuButton(
                    icon: Icon(
                      Icons.more_vert,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                    color: AppColors.sidebar,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'move',
                        child: const Row(
                          children: [
                            Icon(Icons.folder_outlined, size: 18, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Move to folder', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.bookmark_remove, size: 18, color: Colors.red),
                            const SizedBox(width: 8),
                            const Text('Remove bookmark', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) async {
                      if (value == 'remove') {
                        await _removeBookmark(question.id);
                      } else if (value == 'move') {
                        await _showMoveDialog(question.id);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              MarkdownBody(
                data: question.content.length > 150
                    ? '${question.content.substring(0, 150)}...'
                    : question.content,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  strong: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (question.hasPaperInfo) ...[
                const SizedBox(height: 8),
                Text(
                  question.paperLabel,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _removeBookmark(String questionId) async {
    try {
      await _bookmarkRepo.removeBookmark(questionId);
      ToastService.showSuccess('Bookmark removed');
      _loadQuestions();
    } catch (e) {
      ToastService.showError('Failed to remove bookmark');
    }
  }

  Future<void> _showMoveDialog(String questionId) async {
    final newFolder = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.sidebar,
        title: const Text('Move to folder', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _folders.map((folder) {
            return ListTile(
              title: Text(folder, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, folder),
            );
          }).toList(),
        ),
      ),
    );

    if (newFolder != null && newFolder != _selectedFolder) {
      try {
        await _bookmarkRepo.moveToFolder(questionId, newFolder);
        ToastService.showSuccess('Moved to $newFolder');
        _loadQuestions();
      } catch (e) {
        ToastService.showError('Failed to move bookmark');
      }
    }
  }

  Future<void> _showCreateFolderDialog() async {
    final controller = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.sidebar,
        title: const Text('New Folder', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Folder name',
            hintStyle: TextStyle(color: Colors.white54),
          ),
          style: const TextStyle(color: Colors.white),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == true && controller.text.isNotEmpty) {
      setState(() {
        _folders.add(controller.text);
        _selectedFolder = controller.text;
      });
      ToastService.showSuccess('Folder created');
      _loadQuestions();
    }
  }

  Future<void> _deleteFolder(String folder) async {
    try {
      // Move all bookmarks from this folder to "My Bookmarks"
      await _bookmarkRepo.moveFolderBookmarks(folder, 'My Bookmarks');

      setState(() {
        _folders.remove(folder);
        if (_selectedFolder == folder) {
          _selectedFolder = 'My Bookmarks';
        }
      });

      ToastService.showSuccess('Folder deleted');
      _loadQuestions();
    } catch (e) {
      ToastService.showError('Failed to delete folder');
    }
  }

  Future<void> _renameFolder(String oldName, String newName) async {
    try {
      await _bookmarkRepo.renameFolder(oldName, newName);

      setState(() {
        final index = _folders.indexOf(oldName);
        if (index != -1) {
          _folders[index] = newName;
        }
        if (_selectedFolder == oldName) {
          _selectedFolder = newName;
        }
      });

      ToastService.showSuccess('Folder renamed');
    } catch (e) {
      ToastService.showError('Failed to rename folder');
    }
  }
}
