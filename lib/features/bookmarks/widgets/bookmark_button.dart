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
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E232F), // Lighter surface
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
        ),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                   Container(
                     padding: const EdgeInsets.all(10),
                     decoration: BoxDecoration(
                       color: Colors.amber.withValues(alpha: 0.1),
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: const Icon(Icons.bookmark_rounded, color: Colors.amber, size: 24),
                   ),
                   const SizedBox(width: 16),
                   const Text(
                    'Bookmark Question',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              if (folders.isNotEmpty) ...[
                Text(
                  'SELECT FOLDER',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.folder_rounded, color: Colors.amber, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  folder,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15,
                                  ),
                                ),
                                const Spacer(),
                                Icon(Icons.arrow_forward_ios_rounded, 
                                  color: Colors.white.withValues(alpha: 0.3), 
                                  size: 14
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
              
              Text(
                'CREATE NEW FOLDER',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600, 
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newFolderController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter folder name...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.3),
                  prefixIcon: Icon(Icons.create_new_folder_outlined, color: Colors.white.withValues(alpha: 0.5)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.amber, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withValues(alpha: 0.7),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
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
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
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
