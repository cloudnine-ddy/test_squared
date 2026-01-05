import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
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
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFF9F6EE), // Cream background
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 0,
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                   Container(
                     padding: const EdgeInsets.all(10),
                     decoration: BoxDecoration(
                       color: const Color(0xFFE4E1D8), // Slightly darker cream/grey
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: const Icon(Icons.bookmark, color: Color(0xFF2C3E50), size: 24),
                   ),
                   const SizedBox(width: 16),
                   const Text(
                    'Bookmark Question',
                    style: TextStyle(
                      color: Color(0xFF1A1C1E),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Folder Selection
              if (folders.isNotEmpty) ...[
                const Text(
                  'SELECT FOLDER',
                  style: TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: SingleChildScrollView(
                    child: Column(
                      children: folders.map((folder) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(folder),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEBE8E0), // Input/Item background
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.folder, color: Color(0xFF4A4A4A), size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  folder,
                                  style: const TextStyle(
                                    color: Color(0xFF1A1C1E),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15,
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.chevron_right,
                                  color: Color(0xFF8E8E93),
                                  size: 20
                                ),
                              ],
                            ),
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // New Folder Input
              const Text(
                'CREATE NEW FOLDER',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newFolderController,
                style: const TextStyle(color: Color(0xFF1A1C1E)),
                decoration: InputDecoration(
                  hintText: 'Enter folder name...',
                  hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
                  filled: true,
                  fillColor: Colors.transparent, // Outline style or filled? Design shows outline
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  prefixIcon: const Icon(Icons.create_new_folder_outlined, color: Color(0xFF4A4A4A)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF8E8E93), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1A1C1E), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF4A4A4A),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEBC25C), // Mustard/Yellow
                      foregroundColor: const Color(0xFF1A1C1E),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30), // Pill shape
                      ),
                    ),
                    child: const Text('Save Bookmark', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: _toggleBookmark,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
             gradient: _isBookmarked
                ? const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [const Color(0xFF384050), const Color(0xFF2B3240)], // Lighter Grey
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isBookmarked
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              if (_isBookmarked)
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: _isLoading
              ? Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _isBookmarked ? Colors.black : Colors.white
                    ),
                  ),
                )
              : Icon(
                  _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                  color: _isBookmarked ? Colors.black : Colors.white,
                  size: 22,
                ),
        ),
      ),
    );
  }
}
