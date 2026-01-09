import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import 'image_annotation_dialog.dart';
import '../../../shared/wired/wired_widgets.dart';

class NoteEditorDialog extends StatefulWidget {
  final String questionId;
  final String? initialNote;
  final List<String>? initialImageUrls;

  const NoteEditorDialog({
    super.key,
    required this.questionId,
    this.initialNote,
    this.initialImageUrls,
  });

  @override
  State<NoteEditorDialog> createState() => _NoteEditorDialogState();
}

class _NoteEditorDialogState extends State<NoteEditorDialog> {
  late TextEditingController _controller;
  bool _hasChanges = false;
  List<String> _imageUrls = [];
  bool _isUploading = false;

  static const Color _primaryColor = Color(0xFF2D3E50);

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
        withData: true, // Get bytes for web
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => _isUploading = true);

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null) {
        throw Exception('Could not read file');
      }

      // Upload to Supabase Storage
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final path = '$userId/$fileName';

      await Supabase.instance.client.storage
          .from('note-images')
          .uploadBinary(path, bytes);

      final url = Supabase.instance.client.storage
          .from('note-images')
          .getPublicUrl(path);

      setState(() {
        _imageUrls.add(url);
        _hasChanges = true;
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    }
  }

  void _removeImage(String url) {
    setState(() {
      _imageUrls.remove(url);
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final wordCount = _controller.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: WiredCard(
        backgroundColor: Colors.white,
        borderColor: _primaryColor,
        borderWidth: 1.5,
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                   Icon(Icons.edit_note, color: _primaryColor, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Your Notes',
                    style: _patrickHand(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: _primaryColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Text Area
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: _primaryColor.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TextField(
                  controller: _controller,
                  maxLines: 10,
                  decoration: InputDecoration(
                    hintText: 'Write your thoughts, key points, or reminders here...',
                    hintStyle: _patrickHand(color: _primaryColor.withValues(alpha: 0.4)),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  style: _patrickHand(fontSize: 18, height: 1.5),
                ),
              ),
              const SizedBox(height: 16),

              // Image Thumbnails
              if (_imageUrls.isNotEmpty)
                WiredCard(
                  backgroundColor: _primaryColor.withValues(alpha: 0.05),
                  borderColor: _primaryColor.withValues(alpha: 0.1),
                  borderWidth: 1,
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _imageUrls.map((url) => _buildImageThumbnail(url)).toList(),
                  ),
                ),

              if (_imageUrls.isNotEmpty) const SizedBox(height: 12),

              // Upload Image Button
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _isUploading ? null : _pickAndUploadImage,
                    icon: _isUploading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _primaryColor),
                          )
                        : const Icon(Icons.image, size: 18),
                    label: Text(_isUploading ? 'Uploading...' : 'Upload Image'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primaryColor,
                      side: BorderSide(color: _primaryColor.withValues(alpha: 0.5)),
                      textStyle: _patrickHand(fontWeight: FontWeight.bold),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _addSketch,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Sketch'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primaryColor,
                      side: BorderSide(color: _primaryColor.withValues(alpha: 0.5)),
                      textStyle: _patrickHand(fontWeight: FontWeight.bold),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Footer
              Row(
                children: [
                  Text(
                    '$wordCount words',
                    style: _patrickHand(
                      color: _primaryColor.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: _patrickHand(color: Colors.grey)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _hasChanges || widget.initialNote == null
                        ? () => Navigator.pop(context, {'text': _controller.text, 'images': _imageUrls})
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      textStyle: _patrickHand(fontWeight: FontWeight.bold),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Save Note'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _buildImageThumbnail(String url) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _annotateImage(url),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: _primaryColor.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  );
                },
              ),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeImage(url),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}
