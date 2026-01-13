import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../past_papers/models/question_model.dart';
import '../data/bookmark_repository.dart';
import '../data/notes_repository.dart';
import '../../../core/services/toast_service.dart';
import '../widgets/bookmark_folder_panel.dart';
import 'note_editor_dialog.dart';
import '../../../shared/wired/wired_widgets.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final BookmarkRepository _bookmarkRepo = BookmarkRepository();
  final NotesRepository _notesRepo = NotesRepository();
  
  List<QuestionModel> _questions = [];
  List<String> _folders = ['My Bookmarks'];
  String _selectedFolder = 'My Bookmarks';
  bool _isLoading = true;
  Map<String, bool> _hasNotes = {};

  // Sketchy Theme Colors
  static const Color _primaryColor = Color(0xFF2D3E50); // Deep Navy
  static const Color _backgroundColor = Color(0xFFFDFBF7); // Cream beige

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
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await _loadFolders();
    await _loadQuestions();
    setState(() => _isLoading = false);
  }

  Future<void> _loadFolders() async {
    final folders = await _bookmarkRepo.getFolders();
    if (mounted) {
      // Filter out 'My Bookmarks' from database to avoid duplicates
      final filteredFolders = folders.where((f) => f != 'My Bookmarks').toList();
      setState(() => _folders = ['My Bookmarks', ...filteredFolders]);
    }
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      final questions = await _bookmarkRepo.getBookmarkedQuestions(folder: _selectedFolder);
      
      // Check for notes
      final notesMap = <String, bool>{};
      for (var q in questions) {
        final note = await _notesRepo.getNote(q.id);
        if (note != null) {
          notesMap[q.id] = true;
        }
      }

      if (mounted) {
        setState(() {
          _questions = questions;
          _hasNotes = notesMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastService.showError('Failed to load bookmarks');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          'Bookmarks',
          style: _patrickHand(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _primaryColor),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: _primaryColor.withValues(alpha: 0.2),
            height: 1,
          ),
        ),
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
          // Vertical divider - sketchy style
          Container(
            width: 1,
            color: _primaryColor.withValues(alpha: 0.2),
          ),
          // Content area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _primaryColor))
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
            CustomPaint(
              painter: WiredBorderPainter(
                color: _primaryColor.withValues(alpha: 0.2),
                strokeWidth: 1.5,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Icon(
                  Icons.bookmark_border,
                  size: 48,
                  color: _primaryColor.withValues(alpha: 0.4),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No bookmarks in this folder',
              style: _patrickHand(
                fontSize: 20,
                color: _primaryColor.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bookmark questions while practicing',
              style: _patrickHand(
                fontSize: 16,
                color: _primaryColor.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadQuestions,
      color: _primaryColor,
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
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: WiredCard(
        backgroundColor: isAI ? const Color(0xFFF5F0E1) : Colors.white,
        borderColor: isAI ? Colors.orange.withValues(alpha: 0.3) : _primaryColor.withValues(alpha: 0.2),
        borderWidth: 1.5,
        padding: const EdgeInsets.all(0),
        child: InkWell(
          onTap: () => context.push('/question/${question.id}'),
          borderRadius: BorderRadius.circular(12),
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
                        color: isAI ? Colors.orange : _primaryColor.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isAI ? Colors.orange : _primaryColor,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        isAI ? 'AI Generated' : 'Q${question.questionNumber}',
                        style: _patrickHand(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (question.isMCQ && !isAI)
                      WiredCard(
                        backgroundColor: Colors.blue.withValues(alpha: 0.1),
                        borderColor: Colors.blue.withValues(alpha: 0.4),
                        borderWidth: 1.0,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          'MCQ',
                          style: _patrickHand(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (hasNote)
                      Icon(
                        Icons.note,
                        color: isAI ? Colors.orange : Colors.amber,
                        size: 20,
                      ),
                    const SizedBox(width: 8),
                    Theme(
                      data: Theme.of(context).copyWith(
                        popupMenuTheme: PopupMenuThemeData(
                          color: const Color(0xFFFDFBF7), // Cream background
                          shape: WiredShapeBorder(
                            color: _primaryColor,
                            width: 1.5,
                          ),
                          elevation: 0, // Removed elevation shadow to rely on wired border
                        ),
                      ),
                      child: PopupMenuButton(
                        icon: Icon(
                          Icons.more_vert,
                          color: _primaryColor.withValues(alpha: 0.6),
                        ),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'move',
                            height: 48,
                            child: Row(
                              children: [
                                Icon(Icons.folder_outlined, size: 20, color: _primaryColor),
                                const SizedBox(width: 12),
                                Text('Move to folder', style: _patrickHand(color: _primaryColor, fontSize: 18)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'remove',
                            height: 48,
                            child: Row(
                              children: [
                                const Icon(Icons.bookmark_remove, size: 20, color: Colors.red),
                                const SizedBox(width: 12),
                                Text('Remove bookmark', style: _patrickHand(color: Colors.red, fontSize: 18)),
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
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                MarkdownBody(
                  data: question.content.length > 150
                      ? '${question.content.substring(0, 150)}...'
                      : question.content,
                  styleSheet: MarkdownStyleSheet(
                    p: _patrickHand(
                      color: _primaryColor,
                      fontSize: 16,
                      height: 1.5,
                    ),
                    strong: _patrickHand(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (question.hasPaperInfo) ...[
                  const SizedBox(height: 8),
                  Text(
                    question.paperLabel,
                    style: _patrickHand(
                      color: _primaryColor.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
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
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: WiredCard(
          backgroundColor: Colors.white,
          borderColor: _primaryColor,
          borderWidth: 1.5,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Move to folder',
                style: _patrickHand(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: _folders.map((folder) {
                    final isSelected = folder == _selectedFolder;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => Navigator.pop(context, folder),
                        child: WiredCard(
                          backgroundColor: Colors.white,
                          borderColor: _primaryColor.withValues(alpha: 0.3),
                          borderWidth: 1.5,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(Icons.folder_outlined, color: _primaryColor.withValues(alpha: 0.7), size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  folder,
                                  style: _patrickHand(fontSize: 18),
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check, color: _primaryColor, size: 20),
                            ],
                          ),
                        ),
                      ),
                    );
                }).toList(),
              ),
            ],
          ),
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
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: WiredCard(
          backgroundColor: Colors.white,
          borderColor: _primaryColor,
          borderWidth: 1.5,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'New Folder',
                style: _patrickHand(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              WiredCard(
                backgroundColor: Colors.transparent,
                borderColor: _primaryColor.withValues(alpha: 0.5),
                borderWidth: 1.5,
                padding: EdgeInsets.zero,
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'Folder name',
                    hintStyle: _patrickHand(color: _primaryColor.withValues(alpha: 0.5)),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: _patrickHand(fontSize: 18),
                  autofocus: true,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  WiredButton(
                    onPressed: () => Navigator.pop(context, false),
                    backgroundColor: Colors.transparent,
                    borderColor: _primaryColor.withValues(alpha: 0.3),
                    child: Text('Cancel', style: _patrickHand(color: _primaryColor.withValues(alpha: 0.7))),
                  ),
                  const SizedBox(width: 12),
                  WiredButton(
                    onPressed: () => Navigator.pop(context, true),
                    filled: true,
                    backgroundColor: const Color(0xFFFFB300), // Amber
                    borderColor: const Color(0xFFFFB300),
                    child: Text('Create', style: _patrickHand(color: _primaryColor, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
