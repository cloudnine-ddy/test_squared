import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';

/// PDF Preview Widget using iframe for Flutter Web
class PdfPreviewDialog extends StatefulWidget {
  final String pdfUrl;
  final String title;

  const PdfPreviewDialog({
    super.key,
    required this.pdfUrl,
    required this.title,
  });

  @override
  State<PdfPreviewDialog> createState() => _PdfPreviewDialogState();
}

class _PdfPreviewDialogState extends State<PdfPreviewDialog> {
  late String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'pdf-preview-${DateTime.now().millisecondsSinceEpoch}';
    
    // Register the iframe element
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..src = widget.pdfUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%';
        return iframe;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.sidebar,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.picture_as_pdf, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    // Open in new tab
                    html.window.open(widget.pdfUrl, '_blank');
                  },
                  icon: const Icon(Icons.open_in_new, color: AppColors.textSecondary),
                  tooltip: 'Open in new tab',
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 16),
            // PDF Viewer
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: HtmlElementView(viewType: _viewId),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to show PDF preview dialog
void showPdfPreview(BuildContext context, String pdfUrl, String title) {
  showDialog(
    context: context,
    builder: (context) => PdfPreviewDialog(pdfUrl: pdfUrl, title: title),
  );
}
