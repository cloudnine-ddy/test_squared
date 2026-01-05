import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_colors.dart';
import '../../core/services/toast_service.dart';

/// Interactive crop editor for adjusting figure bounding boxes
class FigureCropEditor extends StatefulWidget {
  final Map<String, dynamic> question;
  final VoidCallback onClose;

  const FigureCropEditor({
    super.key,
    required this.question,
    required this.onClose,
  });

  @override
  State<FigureCropEditor> createState() => _FigureCropEditorState();
}

class _FigureCropEditorState extends State<FigureCropEditor> {
  final _supabase = Supabase.instance.client;
  
  bool _isCropping = false;
  bool _isLoadingPage = false;
  String? _pdfUrl;
  String? _pageImageUrl; // Rendered page image
  
  // Crop box in percentages (0-100)
  double _cropX = 10;
  double _cropY = 30;
  double _cropWidth = 40;
  double _cropHeight = 30;
  
  // Page info
  int _currentPage = 1;
  
  @override
  void initState() {
    super.initState();
    _initializeFromQuestion();
  }
  
  void _initializeFromQuestion() {
    final paper = widget.question['paper'] as Map<String, dynamic>?;
    _pdfUrl = paper?['pdf_url'];
    
    // Get initial crop box from ai_answer
    final aiAnswer = widget.question['ai_answer'] as Map<String, dynamic>?;
    final figureLocation = aiAnswer?['figure_location'] as Map<String, dynamic>?;
    
    if (figureLocation != null) {
      setState(() {
        _currentPage = (figureLocation['page'] as num?)?.toInt() ?? 1;
        _cropX = (figureLocation['x_percent'] as num?)?.toDouble() ?? 10;
        _cropY = (figureLocation['y_percent'] as num?)?.toDouble() ?? 30;
        _cropWidth = (figureLocation['width_percent'] as num?)?.toDouble() ?? 40;
        _cropHeight = (figureLocation['height_percent'] as num?)?.toDouble() ?? 30;
      });
    }
    
    // Load the PDF page preview
    _loadPagePreview();
  }
  
  Future<void> _loadPagePreview() async {
    if (_pdfUrl == null) return;
    
    setState(() => _isLoadingPage = true);
    
    try {
      final response = await _supabase.functions.invoke(
        'render-page',
        body: {
          'pdfUrl': _pdfUrl,
          'page': _currentPage,
        },
      );
      
      if (response.data?['image_url'] != null) {
        if (mounted) {
          setState(() {
            _pageImageUrl = response.data['image_url'];
            _isLoadingPage = false;
          });
        }
      } else {
        throw Exception(response.data?['error'] ?? 'Failed to render page');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPage = false);
        ToastService.showError('Could not load page preview');
      }
    }
  }

  Future<void> _saveCrop() async {
    setState(() => _isCropping = true);
    
    try {
      // Update the figure_location in ai_answer
      final updatedAiAnswer = {
        'has_figure': true,
        'figure_location': {
          'page': _currentPage,
          'x_percent': _cropX,
          'y_percent': _cropY,
          'width_percent': _cropWidth,
          'height_percent': _cropHeight,
        },
      };
      
      // Save to database
      await _supabase
          .from('questions')
          .update({'ai_answer': updatedAiAnswer})
          .eq('id', widget.question['id']);
      
      // Call crop-figure function to re-crop
      final response = await _supabase.functions.invoke(
        'crop-figure',
        body: {
          'pdfUrl': _pdfUrl,
          'questionId': widget.question['id'],
          'page': _currentPage,
          'bbox': {
            'x': _cropX,
            'y': _cropY,
            'width': _cropWidth,
            'height': _cropHeight,
          },
        },
      );
      
      if (response.status != 200 && response.data?['error'] != null) {
        throw Exception(response.data?['error']);
      }
      
      ToastService.showSuccess('Figure cropped and saved!');
      widget.onClose();
    } catch (e) {
      ToastService.showError('Failed to crop: $e');
    } finally {
      if (mounted) {
        setState(() => _isCropping = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // Header
          _buildHeader(),
          
          // Main content
          Expanded(
            child: Row(
              children: [
                // PDF preview with crop overlay
                Expanded(
                  flex: 2,
                  child: _buildPreviewArea(),
                ),
                
                // Controls panel
                Container(
                  width: 300,
                  decoration: BoxDecoration(
                    color: AppColors.sidebar,
                    border: Border(
                      left: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  child: _buildControlsPanel(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final paper = widget.question['paper'] as Map<String, dynamic>?;
    final paperInfo = paper != null
        ? '${paper['year']} ${paper['season']} V${paper['variant']}'
        : 'Unknown Paper';
    
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.arrow_back),
            color: Colors.white.withValues(alpha: 0.7),
            tooltip: 'Back to list',
          ),
          const SizedBox(width: 16),
          
          // Title
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Crop Figure - Q${widget.question['question_number']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                paperInfo,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          
          const Spacer(),
          
          // Save button
          ElevatedButton.icon(
            onPressed: _isCropping ? null : _saveCrop,
            icon: _isCropping
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.crop_original),
            label: Text(_isCropping ? 'Cropping...' : 'Save & Crop'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewArea() {
    return Container(
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate aspect ratio for A4 (210mm x 297mm)
          const aspectRatio = 210 / 297;
          double width = constraints.maxWidth;
          double height = constraints.maxHeight;
          
          if (width / height > aspectRatio) {
            width = height * aspectRatio;
          } else {
            height = width / aspectRatio;
          }
          
          return Center(
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: [
                  // PDF page image or loading indicator
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _isLoadingPage
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text(
                                  'Loading page...',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : _pageImageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  _pageImageUrl!,
                                  fit: BoxFit.contain,
                                  width: width,
                                  height: height,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.error, color: Colors.red[300], size: 48),
                                        const SizedBox(height: 8),
                                        const Text('Failed to load page'),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.picture_as_pdf,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Page $_currentPage',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Loading preview...',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                  ),
                  
                  // Crop overlay
                  _buildCropOverlay(width, height),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCropOverlay(double containerWidth, double containerHeight) {
    final left = (_cropX / 100) * containerWidth;
    final top = (_cropY / 100) * containerHeight;
    final width = (_cropWidth / 100) * containerWidth;
    final height = (_cropHeight / 100) * containerHeight;
    
    return Stack(
      children: [
        // Darkened areas outside crop
        // Top
        Positioned(
          left: 0,
          top: 0,
          right: 0,
          height: top,
          child: Container(color: Colors.black.withValues(alpha: 0.5)),
        ),
        // Bottom
        Positioned(
          left: 0,
          top: top + height,
          right: 0,
          bottom: 0,
          child: Container(color: Colors.black.withValues(alpha: 0.5)),
        ),
        // Left
        Positioned(
          left: 0,
          top: top,
          width: left,
          height: height,
          child: Container(color: Colors.black.withValues(alpha: 0.5)),
        ),
        // Right
        Positioned(
          left: left + width,
          top: top,
          right: 0,
          height: height,
          child: Container(color: Colors.black.withValues(alpha: 0.5)),
        ),
        
        // Crop box border
        Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _cropX += (details.delta.dx / containerWidth) * 100;
                _cropY += (details.delta.dy / containerHeight) * 100;
                
                // Clamp values
                _cropX = _cropX.clamp(0, 100 - _cropWidth);
                _cropY = _cropY.clamp(0, 100 - _cropHeight);
              });
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF6366F1),
                  width: 2,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.open_with,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ),
        
        // Corner handles
        _buildCornerHandle(left, top, containerWidth, containerHeight, 'topLeft'),
        _buildCornerHandle(left + width - 12, top, containerWidth, containerHeight, 'topRight'),
        _buildCornerHandle(left, top + height - 12, containerWidth, containerHeight, 'bottomLeft'),
        _buildCornerHandle(left + width - 12, top + height - 12, containerWidth, containerHeight, 'bottomRight'),
      ],
    );
  }

  Widget _buildCornerHandle(
    double left,
    double top,
    double containerWidth,
    double containerHeight,
    String corner,
  ) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            final dx = (details.delta.dx / containerWidth) * 100;
            final dy = (details.delta.dy / containerHeight) * 100;
            
            switch (corner) {
              case 'topLeft':
                _cropX += dx;
                _cropY += dy;
                _cropWidth -= dx;
                _cropHeight -= dy;
                break;
              case 'topRight':
                _cropY += dy;
                _cropWidth += dx;
                _cropHeight -= dy;
                break;
              case 'bottomLeft':
                _cropX += dx;
                _cropWidth -= dx;
                _cropHeight += dy;
                break;
              case 'bottomRight':
                _cropWidth += dx;
                _cropHeight += dy;
                break;
            }
            
            // Clamp values
            _cropX = _cropX.clamp(0, 95);
            _cropY = _cropY.clamp(0, 95);
            _cropWidth = _cropWidth.clamp(5, 100 - _cropX);
            _cropHeight = _cropHeight.clamp(5, 100 - _cropY);
          });
        },
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: Colors.white, width: 1),
          ),
        ),
      ),
    );
  }

  Widget _buildControlsPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current image
          Text(
            'Current Image',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: widget.question['image_url'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.question['image_url'],
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          color: Colors.white.withValues(alpha: 0.3),
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No image yet',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          
          const SizedBox(height: 24),
          
          // Page selector
          Text(
            'Page',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: _currentPage > 1
                    ? () {
                        setState(() => _currentPage--);
                        _loadPagePreview();
                      }
                    : null,
                icon: const Icon(Icons.remove),
                color: Colors.white.withValues(alpha: 0.7),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_currentPage',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() => _currentPage++);
                  _loadPagePreview();
                },
                icon: const Icon(Icons.add),
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Position sliders
          _buildSlider('X Position', _cropX, (v) => setState(() => _cropX = v)),
          _buildSlider('Y Position', _cropY, (v) => setState(() => _cropY = v)),
          _buildSlider('Width', _cropWidth, (v) => setState(() => _cropWidth = v)),
          _buildSlider('Height', _cropHeight, (v) => setState(() => _cropHeight = v)),
          
          const SizedBox(height: 24),
          
          // Reset button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _initializeFromQuestion,
              icon: const Icon(Icons.refresh),
              label: const Text('Reset to Original'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.7),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              Text(
                '${value.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: value.clamp(0, 100),
              min: 0,
              max: 100,
              onChanged: onChanged,
              activeColor: const Color(0xFF6366F1),
              inactiveColor: Colors.white.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}
