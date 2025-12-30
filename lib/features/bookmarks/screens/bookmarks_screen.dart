import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/toast_service.dart';
import '../data/bookmark_repository.dart';
import '../data/notes_repository.dart';
import '../../past_papers/models/question_model.dart';
import 'note_editor_dialog.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> with SingleTickerProviderStateMixin {
  final _bookmarkRepo = BookmarkRepository();
  final _notesRepo = NotesRepository();
  
  List<String> _folders = [];
  String _selectedFolder = 'My Bookmarks';
  List<QuestionModel> _questions = [];
  Map<String, bool> _hasNotes = {};
  bool _isLoading = true;
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final folders = await _bookmarkRepo.getFolders();
      if (folders.isEmpty) {
        folders.add('My Bookmarks');
      }

      _tabController = TabController(length: folders.length, vsync: this);
      _tabController.addListener(() {
        if (_tabController.indexIsChanging) {
          setState(() {
            _selectedFolder = folders[_tabController.index];
          });
          _loadQuestions();
        }
      });

      setState(() {
        _folders = folders;
        _selectedFolder = folders.first;
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
      backgroundColor: AppTheme.backgroundDeepest,
      appBar: AppBar(
        title: const Text('Bookmarks'),
        backgroundColor: AppTheme.surfaceDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: _showCreateFolderDialog,
            tooltip: 'New folder',
          ),
        ],
        bottom: _folders.isNotEmpty
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: AppTheme.primaryBlue,
                tabs: _folders.map((folder) => Tab(text: folder)).toList(),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Q${question.questionNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (question.isMCQ)
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
                      color: Colors.amber,
                      size: 18,
                    ),
                  const SizedBox(width: 8),
                  PopupMenuButton(
                    icon: Icon(
                      Icons.more_vert,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    color: AppTheme.surfaceDark,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'move',
                        child: const Row(
                          children: [
                            Icon(Icons.folder_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Move to folder'),
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
              Text(
                question.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (question.hasPaperInfo) ...[
                const SizedBox(height: 8),
                Text(
                  question.paperLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
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
        backgroundColor: AppTheme.surfaceDark,
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
        backgroundColor: AppTheme.surfaceDark,
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
      ToastService.showInfo('Add a bookmark to the new folder to create it');
    }
  }
}
