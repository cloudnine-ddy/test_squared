import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Folder navigation panel for bookmarks
class BookmarkFolderPanel extends StatelessWidget {
  final List<String> folders;
  final String selectedFolder;
  final Function(String) onFolderSelected;
  final VoidCallback onCreateFolder;
  final Function(String) onDeleteFolder;
  final Function(String, String) onRenameFolder;

  const BookmarkFolderPanel({
    super.key,
    required this.folders,
    required this.selectedFolder,
    required this.onFolderSelected,
    required this.onCreateFolder,
    required this.onDeleteFolder,
    required this.onRenameFolder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(
          right: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.folder,
                  color: AppTheme.primaryBlue,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Folders',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.create_new_folder,
                    color: AppTheme.primaryBlue,
                    size: 20,
                  ),
                  onPressed: onCreateFolder,
                  tooltip: 'New folder',
                ),
              ],
            ),
          ),
          const Divider(
            color: Colors.white10,
            height: 1,
          ),
          // Folder list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                final isSelected = folder == selectedFolder;
                
                return _buildFolderItem(
                  context,
                  folder,
                  isSelected,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderItem(BuildContext context, String folder, bool isSelected) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primaryBlue.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          isSelected ? Icons.folder_open : Icons.folder_outlined,
          color: isSelected ? AppTheme.primaryBlue : Colors.white70,
          size: 20,
        ),
        title: Text(
          folder,
          style: TextStyle(
            color: isSelected ? AppTheme.primaryBlue : Colors.white,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: folder != 'My Bookmarks'
            ? PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                color: AppTheme.surfaceDark,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 16),
                        SizedBox(width: 8),
                        Text('Rename'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        const Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'delete') {
                    _showDeleteConfirmation(context, folder);
                  } else if (value == 'rename') {
                    _showRenameDialog(context, folder);
                  }
                },
              )
            : null,
        onTap: () => onFolderSelected(folder),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Delete Folder', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete "$folder"? All bookmarks in this folder will be moved to "My Bookmarks".',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDeleteFolder(folder);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, String folder) {
    final controller = TextEditingController(text: folder);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Rename Folder', style: TextStyle(color: Colors.white)),
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty && controller.text != folder) {
                Navigator.pop(context);
                onRenameFolder(folder, controller.text);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }
}
