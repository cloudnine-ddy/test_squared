import 'package:flutter/material.dart';
import '../data/bookmark_repository.dart';
import '../../../core/services/toast_service.dart';
import '../../../core/services/analytics_service.dart';

class BookmarkButton extends StatefulWidget {
  final String questionId;
  final bool initialIsBookmarked;
  final VoidCallback? onChanged;

  const BookmarkButton({
    super.key,
    required this.questionId,
    this.initialIsBookmarked = false,
    this.onChanged,
  });

  @override
  State<BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends State<BookmarkButton> with SingleTickerProviderStateMixin {
  final _bookmarkRepo = BookmarkRepository();
  late bool _isBookmarked;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _isBookmarked = widget.initialIsBookmarked;
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _toggleBookmark() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      if (_isBookmarked) {
        await _bookmarkRepo.removeBookmark(widget.questionId);
        ToastService.showSuccess('Bookmark removed');
        AnalyticsService().trackBookmark(widget.questionId, false);
      } else {
        // Show folder selection dialog
        final folder = await _showFolderSelectionDialog();
        if (folder == null) {
          setState(() => _isLoading = false);
          return; // User cancelled
        }
        
        await _bookmarkRepo.addBookmark(widget.questionId, folder: folder);
        ToastService.showSuccess('Bookmarked to $folder!');
        AnalyticsService().trackBookmark(widget.questionId, true);
        _animationController.forward().then((_) => _animationController.reverse());
      }

      setState(() {
        _isBookmarked = !_isBookmarked;
        _isLoading = false;
      });

      widget.onChanged?.call();
    } catch (e) {
      setState(() => _isLoading = false);
      ToastService.showError('Failed to update bookmark');
    }
  }

  Future<String?> _showFolderSelectionDialog() async {
    final folders = await _bookmarkRepo.getFolders();
    final TextEditingController newFolderController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D24),
        title: const Text('Select Folder', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (folders.isNotEmpty) ...[
              const Text('Existing Folders:', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              ...folders.map((folder) => ListTile(
                title: Text(folder, style: const TextStyle(color: Colors.white)),
                leading: const Icon(Icons.folder, color: Colors.amber),
                onTap: () => Navigator.of(context).pop(folder),
              )),
              const Divider(color: Colors.white24),
            ],
            const SizedBox(height: 8),
            const Text('Or create new:', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: newFolderController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'New folder name',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                filled: true,
                fillColor: const Color(0xFF0A0D12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: IconButton(
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: _isBookmarked ? Colors.amber : Colors.white.withValues(alpha: 0.7),
              ),
        onPressed: _toggleBookmark,
        tooltip: _isBookmarked ? 'Remove bookmark' : 'Bookmark',
      ),
    );
  }
}
