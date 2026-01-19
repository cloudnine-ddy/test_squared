import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../../../shared/wired/wired_widgets.dart';

class ImageAnnotationDialog extends StatefulWidget {
  final String? imageUrl;

  const ImageAnnotationDialog({super.key, this.imageUrl});

  @override
  State<ImageAnnotationDialog> createState() => _ImageAnnotationDialogState();
}

class _ImageAnnotationDialogState extends State<ImageAnnotationDialog> {
  final List<DrawingPoint?> _points = [];
  final GlobalKey _globalKey = GlobalKey(); // For RepaintBoundary

  Color _selectedColor = Colors.black; // Default to black for writing
  double _strokeWidth = 3.0;
  bool _isSaving = false;

  // Undo/Redo history
  List<List<DrawingPoint?>> _history = [];

  @override
  void initState() {
    super.initState();
    if (widget.imageUrl != null) {
      _loadImageSize();
    }
  }

  Future<void> _loadImageSize() async {
    // Only needed for network images to confirm size, but we use layout builder anyway
  }

  void _addPoint(DrawingPoint? point) {
    setState(() {
      _points.add(point);
    });
  }

  void _undo() {
    if (_history.isNotEmpty) {
      setState(() {
        _points.clear();
        _points.addAll(_history.removeLast());
      });
    }
  }

  void _saveToHistory() {
    setState(() {
      _history.add(List.from(_points));
    });
  }

  Future<void> _saveAnnotation() async {
    setState(() => _isSaving = true);
    try {
      print('[Sketch] Starting save annotation...');

      // 1. Capture the boundary as an image
      final context = _globalKey.currentContext;
      if (context == null) {
        throw Exception('RepaintBoundary context is null');
      }

      RenderRepaintBoundary boundary = context.findRenderObject() as RenderRepaintBoundary;
      print('[Sketch] Boundary size: ${boundary.size}');

      // Wait for the boundary to be ready (sometimes needed for first frame)
      await Future.delayed(const Duration(milliseconds: 100));

      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      print('[Sketch] Image captured: ${image.width}x${image.height}');

      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to capture image');

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      print('[Sketch] PNG bytes: ${pngBytes.length}');

      // 2. Upload to Supabase
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final userId = user.id;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_annotated.png';
      final path = '$userId/$fileName';
      print('[Sketch] Uploading to path: $path');

      await Supabase.instance.client.storage
          .from('note-images')
          .uploadBinary(path, pngBytes);
      print('[Sketch] Upload complete');

      final newUrl = Supabase.instance.client.storage
          .from('note-images')
          .getPublicUrl(path);
      print('[Sketch] Public URL: $newUrl');

      if (mounted) {
        Navigator.pop(this.context, newUrl);
      }
    } catch (e, stackTrace) {
      print('[Sketch] ERROR: $e');
      print('[Sketch] Stack: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(content: Text('Failed to save annotation: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Toolbar
          WiredCard(
            backgroundColor: Colors.white,
            borderColor: const Color(0xFF2D3E50),
            borderWidth: 1.5,
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildColorButton(Colors.red),
                _buildColorButton(Colors.black),
                _buildColorButton(Colors.blue),
                _buildColorButton(Colors.green),
                _buildColorButton(Colors.yellow),
                const SizedBox(width: 12),
                Container(
                  width: 1,
                  height: 24,
                  color: const Color(0xFF2D3E50).withOpacity(0.2),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.undo, color: Color(0xFF2D3E50)),
                  onPressed: _history.isNotEmpty ? _undo : null,
                  tooltip: 'Undo',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Color(0xFF2D3E50)),
                  onPressed: () {
                     _saveToHistory();
                     setState(() => _points.clear());
                  },
                  tooltip: 'Clear All',
                ),
                const Spacer(),
                 TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel', style: TextStyle(fontFamily: 'PatrickHand', fontSize: 18)),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveAnnotation,
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: Text(_isSaving ? 'Saving...' : 'Save', style: const TextStyle(fontFamily: 'PatrickHand', fontSize: 18, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D3E50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Drawing Area - Fixed size for reliable capture
          Expanded(
            child: Center(
              child: RepaintBoundary(
                key: _globalKey,
                child: Container(
                  width: 600,
                  height: 500,
                  decoration: BoxDecoration(
                    color: Colors.white, // White paper background
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 4),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Base Image (if provided)
                        if (widget.imageUrl != null)
                          Image.network(
                            widget.imageUrl!,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, event) {
                              if (event == null) return child;
                              return const Center(child: CircularProgressIndicator());
                            },
                          )
                        else
                          // Blank Paper Mode: Just a container that fills space
                          Container(
                            width: 600,
                            height: 500,
                            color: Colors.white,
                            child: CustomPaint(
                              size: const Size(600, 500),
                              painter: _PaperLinesPainter(), // Optional: Add lines
                            ),
                          ),

                        // Gesture Detector & Custom Paint
                        Positioned.fill(
                          child: GestureDetector(
                            onPanStart: (details) {
                              _saveToHistory();
                              _addPoint(DrawingPoint(
                                offset: details.localPosition,
                                paint: Paint()
                                  ..color = _selectedColor
                                  ..isAntiAlias = true
                                  ..strokeWidth = _strokeWidth
                                  ..strokeCap = StrokeCap.round
                                  ..strokeJoin = StrokeJoin.round,
                              ));
                            },
                            onPanUpdate: (details) {
                              _addPoint(DrawingPoint(
                                offset: details.localPosition,
                                paint: Paint()
                                  ..color = _selectedColor
                                  ..isAntiAlias = true
                                  ..strokeWidth = _strokeWidth
                                  ..strokeCap = StrokeCap.round
                                  ..strokeJoin = StrokeJoin.round,
                              ));
                            },
                            onPanEnd: (details) {
                              _addPoint(null); // End of line
                            },
                            child: CustomPaint(
                              size: const Size(600, 500),
                              painter: _AnnotationPainter(_points),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    final isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.grey[800]! : Colors.transparent,
            width: isSelected ? 3 : 0,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4),
          ],
        ),
      ),
    );
  }
}

class DrawingPoint {
  final Offset offset;
  final Paint paint;

  DrawingPoint({required this.offset, required this.paint});
}

class _AnnotationPainter extends CustomPainter {
  final List<DrawingPoint?> points;

  _AnnotationPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(
          points[i]!.offset,
          points[i + 1]!.offset,
          points[i]!.paint,
        );
      } else if (points[i] != null && points[i + 1] == null) {
        // Draw a single dot
        canvas.drawCircle(
          points[i]!.offset,
          points[i]!.paint.strokeWidth / 2,
          points[i]!.paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _PaperLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.1)
      ..strokeWidth = 1.0;

    double y = 40.0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += 40.0;
    }

    // Margin line
    final marginPaint = Paint()
      ..color = Colors.red.withOpacity(0.1)
      ..strokeWidth = 1.0;
    canvas.drawLine(const Offset(60, 0), Offset(60, size.height), marginPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
