import 'package:flutter/material.dart';
import '../../../shared/wired/wired_widgets.dart';

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

  static const Color _primaryColor = Color(0xFF2D3E50);

  TextStyle _patrickHand({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: 'PatrickHand',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? _primaryColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.transparent, // Let parent background show through
        border: Border(
          right: BorderSide(
            color: _primaryColor.withValues(alpha: 0.1),
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
                  color: _primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Folders',
                  style: _patrickHand(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.create_new_folder,
                    color: _primaryColor,
                    size: 20,
                  ),
                  onPressed: onCreateFolder,
                  tooltip: 'New folder',
                ),
              ],
            ),
          ),
          Divider(
            color: _primaryColor.withValues(alpha: 0.1),
            height: 1,
          ),
          // Folder list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: WiredCard(
        backgroundColor: isSelected ? _primaryColor.withValues(alpha: 0.1) : Colors.white,
        borderColor: isSelected ? _primaryColor.withValues(alpha: 0.4) : _primaryColor.withValues(alpha: 0.2),
        borderWidth: 1.5,
        padding: const EdgeInsets.all(0),
        child: _buildListTile(context, folder, isSelected),
      ),
    );
  }

  Widget _buildListTile(BuildContext context, String folder, bool isSelected) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      leading: Icon(
        isSelected ? Icons.folder_open : Icons.folder_outlined,
        color: isSelected ? _primaryColor : _primaryColor.withValues(alpha: 0.6),
        size: 20,
      ),
      title: Text(
        folder,
        style: _patrickHand(
          color: isSelected ? _primaryColor : _primaryColor.withValues(alpha: 0.8),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 18,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: folder != 'My Bookmarks'
          ? Theme(
              data: Theme.of(context).copyWith(
                  popupMenuTheme: PopupMenuThemeData(
                color: const Color(0xFFFDFBF7), // Cream background
                shape: WiredShapeBorder(
                  color: _primaryColor,
                  width: 1.5,
                ),
                elevation: 0,
              )),
              child: PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  size: 18,
                  color: _primaryColor.withValues(alpha: 0.5),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'rename',
                    height: 48,
                    child: Row(
                      children: [
                        const Icon(Icons.edit, size: 20, color: _primaryColor),
                        const SizedBox(width: 12),
                        Text('Rename', style: _patrickHand(fontSize: 18)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    height: 48,
                    child: Row(
                      children: [
                        const Icon(Icons.delete, size: 20, color: Colors.red),
                        const SizedBox(width: 12),
                        Text('Delete', style: _patrickHand(color: Colors.red, fontSize: 18)),
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
              ),
            )
          : null,
      onTap: () => onFolderSelected(folder),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String folder) {
    showDialog(
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
                'Delete Folder',
                style: _patrickHand(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to delete "$folder"? All bookmarks in this folder will be moved to "My Bookmarks".',
                style: _patrickHand(
                  fontSize: 18,
                  color: _primaryColor.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  WiredButton(
                    onPressed: () => Navigator.pop(context),
                    backgroundColor: Colors.transparent,
                    borderColor: _primaryColor.withValues(alpha: 0.3),
                    child: Text('Cancel', style: _patrickHand(color: _primaryColor.withValues(alpha: 0.7))),
                  ),
                  const SizedBox(width: 12),
                  WiredButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onDeleteFolder(folder);
                    },
                    filled: true,
                    backgroundColor: const Color(0xFFFF5252), // Red
                    borderColor: const Color(0xFFFF5252),
                    child: Text('Delete', style: _patrickHand(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, String folder) {
    final controller = TextEditingController(text: folder);

    showDialog(
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
                'Rename Folder',
                style: _patrickHand(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              CustomPaint(
                painter: WiredBorderPainter(
                  color: _primaryColor.withValues(alpha: 0.5),
                  strokeWidth: 1.5,
                ),
                child: Container(
                  color: Colors.white,
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
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  WiredButton(
                    onPressed: () => Navigator.pop(context),
                    backgroundColor: Colors.transparent,
                    borderColor: _primaryColor.withValues(alpha: 0.3),
                    child: Text('Cancel', style: _patrickHand(color: _primaryColor.withValues(alpha: 0.7))),
                  ),
                  const SizedBox(width: 12),
                  WiredButton(
                    onPressed: () {
                      if (controller.text.isNotEmpty && controller.text != folder) {
                        Navigator.pop(context);
                        onRenameFolder(folder, controller.text);
                      }
                    },
                    filled: true,
                    backgroundColor: const Color(0xFFFFB300), // Amber
                    borderColor: const Color(0xFFFFB300),
                    child: Text('Rename', style: _patrickHand(color: _primaryColor, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
