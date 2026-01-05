import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../screens/image_annotation_dialog.dart';

class DraggableNoteWidget extends StatefulWidget {
  final String questionId;
  final String? initialNote;
  final List<String>? initialImageUrls;
  final VoidCallback onClose;
  final Function(String text, List<String> images) onSave;
  final Function(Offset delta) onDrag;

  const DraggableNoteWidget({
    super.key,
    required this.questionId,
    this.initialNote,
    this.initialImageUrls,
    required this.onClose,
    required this.onSave,
    required this.onDrag,
  });

  @override
  State<DraggableNoteWidget> createState() => _DraggableNoteWidgetState();
}

class _DraggableNoteWidgetState extends State<DraggableNoteWidget> {
  late TextEditingController _controller;
  bool _hasChanges = false;
  List<String> _imageUrls = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote ?? '');
    _imageUrls = List.from(widget.initialImageUrls ?? []);
    _controller.addListener(() {
      if (!_hasChanges && _controller.text != (widget.initialNote ?? '')) {
        setState(() => _hasChanges = true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => _isUploading = true);

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null) throw Exception('Could not read file');

      final userId = Supabase.instance.client.auth.currentUser!.id;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final path = '$userId/$fileName';

      await Supabase.instance.client.storage.from('note-images').uploadBinary(path, bytes);

      final url = Supabase.instance.client.storage.from('note-images').getPublicUrl(path);

      setState(() {
        _imageUrls.add(url);
        _hasChanges = true;
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
      }
    }
  }

  void _removeImage(String url) {
    setState(() {
      _imageUrls.remove(url);
      _hasChanges = true;
    });
  }

  Future<void> _addSketch() async {
    final newUrl = await showDialog<String>(
      context: context,
      builder: (context) => const ImageAnnotationDialog(imageUrl: null),
    );

    if (newUrl != null && mounted) {
      setState(() {
        _imageUrls.add(newUrl);
        _hasChanges = true;
      });
    }
  }

  Future<void> _annotateImage(String url) async {
    final newUrl = await showDialog<String>(
      context: context,
      builder: (context) => ImageAnnotationDialog(imageUrl: url),
    );

    if (newUrl != null && mounted) {
      setState(() {
        final index = _imageUrls.indexOf(url);
        if (index != -1) {
          _imageUrls[index] = newUrl;
          _hasChanges = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wordCount = _controller.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      color: Colors.transparent, // Handling color in Container
      child: Container(
        width: 400, // Slightly smaller than 500
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color: const Color(0xFFE8DCC8),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Hug content
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Draggable Header
            GestureDetector(
              onPanUpdate: (details) => widget.onDrag(details.delta),
              child: Container(
                color: Colors.transparent, // Hit test for the whole header row area
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B6F47),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.drag_indicator, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Notes',
                      style: TextStyle(
                        color: Color(0xFF2D2D2D),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF2D2D2D), size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 20, color: Color(0xFFD4C4A8)),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Text Area
                    TextField(
                      controller: _controller,
                      maxLines: null,
                      minLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Write here...',
                        hintStyle: const TextStyle(color: Color(0xFF999999)),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      style: const TextStyle(color: Color(0xFF2D2D2D), height: 1.5, fontSize: 14),
                    ),

                    const SizedBox(height: 16),

                    // Image Thumbnails
                    if (_imageUrls.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _imageUrls.map((url) => _buildImageThumbnail(url)).toList(),
                        ),
                      ),

                    if (_imageUrls.isNotEmpty) const SizedBox(height: 12),

                    // Action Buttons
                    Row(
                      children: [
                        _buildActionButton(
                          icon: Icons.image,
                          label: 'Image',
                          loading: _isUploading,
                          onTap: _isUploading ? null : _pickAndUploadImage
                        ),
                        const SizedBox(width: 8),
                        _buildActionButton(
                          icon: Icons.edit,
                          label: 'Sketch',
                          onTap: _addSketch
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Footer
            Row(
              children: [
                Text(
                  '$wordCount words',
                  style: const TextStyle(color: Color(0xFF6B5D4F), fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                TextButton(
                  onPressed: widget.onClose,
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF666666), fontSize: 13)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _hasChanges || widget.initialNote == null
                      ? () => widget.onSave(_controller.text, _imageUrls)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B6F47),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, bool loading = false, VoidCallback? onTap}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: loading
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(icon, size: 16),
      label: Text(loading ? '...' : label, style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF8B6F47),
        side: const BorderSide(color: Color(0xFF8B6F47)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildImageThumbnail(String url) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _annotateImage(url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                Container(width: 60, height: 60, color: Colors.grey[300], child: const Icon(Icons.broken_image, size: 20)),
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: () => _removeImage(url),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 12),
            ),
          ),
        ),
      ],
    );
  }
}
