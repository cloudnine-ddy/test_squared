import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/wired/wired_widgets.dart';
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
  double _width = 420;
  double _height = 400;

  // Sketchy Theme Colors
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
    print('[Note] Opening sketch dialog...');
    final newUrl = await showDialog<String>(
      context: context,
      builder: (context) => const ImageAnnotationDialog(imageUrl: null),
    );

    print('[Note] Sketch dialog returned: $newUrl');
    if (newUrl != null && mounted) {
      print('[Note] Adding URL to _imageUrls. Current count: ${_imageUrls.length}');
      setState(() {
        _imageUrls.add(newUrl);
        _hasChanges = true;
      });
      print('[Note] After adding: ${_imageUrls.length} images');
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
    // Clamp dimensions
    _width = _width.clamp(320.0, 800.0);
    _height = _height.clamp(300.0, 800.0);

    final wordCount = _controller.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    // Debug: print image count on each build
    print('[Note] Build called. Image count: ${_imageUrls.length}');

    return SizedBox(
      width: _width,
      height: _height,
      child: WiredCard(
        backgroundColor: const Color(0xFFFDFBF7), // Creamy paper color
        borderColor: _primaryColor,
        borderWidth: 2,
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header (Draggable)
                GestureDetector(
                  onPanUpdate: (details) => widget.onDrag(details.delta),
                  child: Container(
                    color: Colors.transparent, // Hit test
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.drag_indicator, color: _primaryColor.withValues(alpha: 0.4), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Notes',
                          style: _patrickHand(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: widget.onClose,
                          child: Icon(Icons.close, color: _primaryColor, size: 24),
                        ),
                      ],
                    ),
                  ),
                ),

                // Divider
                Container(
                  height: 1,
                  color: _primaryColor.withValues(alpha: 0.2),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),

                // Content Area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Images Section (show at top so it's visible!)
                        if (_imageUrls.isNotEmpty) ...[
                          Text(
                            'Attachments (${_imageUrls.length})',
                            style: _patrickHand(
                              fontSize: 14,
                              color: _primaryColor.withValues(alpha: 0.6),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: _imageUrls.map((url) => _buildImageThumbnail(url)).toList(),
                          ),
                          const SizedBox(height: 16),
                          Divider(color: _primaryColor.withValues(alpha: 0.1)),
                          const SizedBox(height: 8),
                        ],

                        // Text Input
                        TextField(
                          controller: _controller,
                          maxLines: null,
                          minLines: _imageUrls.isEmpty ? 8 : 4, // Reduce when images present
                          style: _patrickHand(fontSize: 18, height: 1.4),
                          decoration: InputDecoration(
                            hintText: 'Write your thoughts here...',
                            hintStyle: _patrickHand(color: Colors.grey.withValues(alpha: 0.7), fontSize: 18),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Toolbar / Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 32, 16), // Extra right padding for resize handle
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.03),
                    border: Border(top: BorderSide(color: _primaryColor.withValues(alpha: 0.1))),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildActionButton(
                            icon: Icons.image_outlined,
                            label: 'Image',
                            loading: _isUploading,
                            onTap: _isUploading ? null : _pickAndUploadImage
                          ),
                          const SizedBox(width: 12),
                          _buildActionButton(
                            icon: Icons.edit_outlined,
                            label: 'Sketch',
                            onTap: _addSketch
                          ),
                          const Spacer(),
                          Text(
                            '$wordCount words',
                            style: _patrickHand(fontSize: 14, color: _primaryColor.withValues(alpha: 0.5)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                           TextButton(
                            onPressed: widget.onClose,
                            child: Text(
                              'Cancel',
                              style: _patrickHand(
                                color: _primaryColor.withValues(alpha: 0.7),
                                fontWeight: FontWeight.bold
                              )
                            ),
                          ),
                          const SizedBox(width: 12),
                          WiredButton(
                            onPressed: _hasChanges || widget.initialNote == null
                                ? () => widget.onSave(_controller.text, _imageUrls)
                                : null,
                            backgroundColor: _hasChanges ? _primaryColor : Colors.grey.shade300,
                            borderColor: _hasChanges ? _primaryColor : Colors.grey.shade400,
                            filled: true,
                            child: Text(
                              'Save Note',
                              style: _patrickHand(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Resize Handle
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _width += details.delta.dx;
                    _height += details.delta.dy;
                  });
                },
                child: Container(
                  width: 30,
                  height: 30,
                  color: Colors.transparent,
                  alignment: Alignment.bottomRight,
                  child: Icon(
                    Icons.north_west, // Arrow pointing to content, or resize icon
                    size: 16,
                    color: _primaryColor.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
             // Custom Corner graphics for resize hint
            Positioned(
              right: 4,
              bottom: 4,
              child: IgnorePointer(
                child: CustomPaint(
                  size: const Size(12, 12),
                  painter: _ResizeHandlePainter(color: _primaryColor.withValues(alpha: 0.4)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, bool loading = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            if (loading)
               SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _primaryColor))
            else
              Icon(icon, size: 18, color: _primaryColor),
            const SizedBox(width: 6),
            Text(label, style: _patrickHand(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildImageThumbnail(String url) {
    print('[Note] Building thumbnail for: $url');
    return WiredCard(
      padding: const EdgeInsets.all(4),
      backgroundColor: Colors.white,
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => _annotateImage(url),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                url,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 70,
                    height: 70,
                    color: Colors.grey[100],
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  print('[Note] Image load error: $error');
                  return Container(
                    width: 70,
                    height: 70,
                    color: Colors.grey[200],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image, size: 20, color: Colors.grey),
                        Text('Error', style: TextStyle(fontSize: 8, color: Colors.grey)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: -4,
            right: -4,
            child: GestureDetector(
              onTap: () => _removeImage(url),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.8), shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResizeHandlePainter extends CustomPainter {
  final Color color;
  _ResizeHandlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Draw three diagonal lines
    canvas.drawLine(Offset(size.width, size.height - 4), Offset(size.width - 4, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height - 9), Offset(size.width - 9, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height - 14), Offset(size.width - 14, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
