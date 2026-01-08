import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../core/services/pdf_helper.dart';

class PdfCropViewer extends StatefulWidget {
  final String pdfUrl;
  final int pageNumber; // 1-indexed
  final double x; // Percentage 0-100
  final double y; // Percentage 0-100
  final double width; // Percentage 0-100
  final double height; // Percentage 0-100

  const PdfCropViewer({
    super.key,
    required this.pdfUrl,
    required this.pageNumber,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  @override
  State<PdfCropViewer> createState() => _PdfCropViewerState();
}

class _PdfCropViewerState extends State<PdfCropViewer> {
  late PdfViewerController _pdfController;
  late String _url;
  bool _isLoaded = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _url = PdfHelper.getProxiedUrl(widget.pdfUrl);
  }

  @override
  Widget build(BuildContext context) {
    // Safety checks
    final safeW = widget.width <= 0 ? 100.0 : widget.width;
    final safeH = widget.height <= 0 ? 100.0 : widget.height;

    // Calculate aspect ratio of the CROP
    // A4 is roughly 1:1.414 (width:height) -> 210mm x 297mm
    // PDF width units? Usually we assume A4 portrait for these exams.
    // If we assume the container has width 'w', what height should it have?
    // We can just let it fit width and calculate height based on crop ratio.
    // Crop Ratio = (safeW * PageW) / (safeH * PageH)
    // Page Ratio = 1 / 1.414 = 0.707
    // Crop Aspect Ratio = (safeW / safeH) * 0.707

    // Scale factor needed to fit the crop width into the container width
    // Scale = 100 / safeW
    final scale = 100 / safeW;

    // Constraint-based sizes
    // We assume Page Width matches Container Width (Scale to fit)
    // Page Height is derived from aspect ratio (A4)

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewWidth = constraints.maxWidth;
        final pageW = viewWidth;
        // A4 Aspect Ratio 1:1.414.
        // We use this to estimate Y offsets.
        // If the actual PDF varies, Y cropping might be slightly off, but acceptable for exams.
        final pageH = pageW * 1.414;

        // Calculate offsets to move the crop origin to (0,0)
        // We want (x% of W, y% of H) to map to (0,0)
        final dx = -(widget.x / 100.0) * pageW;
        final dy = -(widget.y / 100.0) * pageH;

        // View Height derived from crop aspect ratio
        final cropAspectRatio = (safeW / safeH) * (1 / 1.414); // width/height
        final viewHeight = viewWidth / cropAspectRatio;

        return Container(
          height: viewHeight,
          width: viewWidth,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Stack(
            children: [
               Transform(
                 alignment: Alignment.topLeft,
                 transform: Matrix4.identity()
                   ..scale(scale, scale)
                   ..translate(dx, dy),
                 child: IgnorePointer(
                   child: SfPdfViewer.network(
                     _url,
                     controller: _pdfController,
                     enableDoubleTapZooming: false,
                     enableTextSelection: false,
                     canShowScrollHead: false,
                     pageLayoutMode: PdfPageLayoutMode.single,
                     interactionMode: PdfInteractionMode.pan,
                     onDocumentLoaded: (args) {
                       if (mounted) {
                         _pdfController.jumpToPage(widget.pageNumber);
                         setState(() {
                           _isLoaded = true;
                           _hasError = false;
                         });
                       }
                     },
                     onDocumentLoadFailed: (args) {
                       if (mounted) {
                         setState(() {
                           _isLoaded = false;
                           _hasError = true;
                         });
                         debugPrint('PDF Load Failed: ${args.error}');
                         debugPrint('Description: ${args.description}');
                       }
                     },
                   ),
                 ),
               ),

               if (!_isLoaded || _hasError)
                 Positioned.fill(
                   child: Container(
                     color: Colors.grey[100],
                     child: Center(
                       child: _hasError
                           ? Column(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 const Icon(Icons.error_outline, color: Colors.red, size: 32),
                                 const SizedBox(height: 8),
                                 const Text('Failed to load PDF', style: TextStyle(color: Colors.red)),
                               ],
                             )
                           : const CircularProgressIndicator(),
                     ),
                   ),
                 ),
            ],
          ),
        );
      }
    );
  }
}
