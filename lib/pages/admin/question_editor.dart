import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/toast_service.dart';

/// Full Question Editor - Edit all fields of a question
class QuestionEditor extends StatefulWidget {
  final String questionId;
  final String paperId;
  final VoidCallback onClose;
  final VoidCallback? onDelete;

  const QuestionEditor({
    super.key,
    required this.questionId,
    required this.paperId,
    required this.onClose,
    this.onDelete,
  });

  @override
  State<QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<QuestionEditor> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;

  // Question data
  Map<String, dynamic>? _question;
  Map<String, dynamic>? _paper;
  List<Map<String, dynamic>> _allTopics = [];

  // Form controllers
  late TextEditingController _contentController;
  late TextEditingController _officialAnswerController;
  int _questionNumber = 1;
  List<String> _selectedTopicIds = [];
  String _topicSearchQuery = '';
  String? _imageUrl;

  // Figure cropping
  bool _hasFigure = false;
  int _figurePage = 1;
  double _figureX = 10;
  double _figureY = 30;
  double _figureWidth = 40;
  double _figureHeight = 30;

  // MCQ fields
  bool _isMCQ = false;
  List<Map<String, dynamic>> _options = [];
  String? _correctAnswer;
  String? _originalAnswer; // AI-extracted answer (shown with green border)

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController();
    _officialAnswerController = TextEditingController();
    _loadQuestion();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _officialAnswerController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestion() async {
    setState(() => _isLoading = true);

    try {
      // Load question
      final questionRes = await _supabase
          .from('questions')
          .select()
          .eq('id', widget.questionId)
          .single();

      // Load paper
      final paperRes = await _supabase
          .from('papers')
          .select()
          .eq('id', widget.paperId)
          .single();

      // Load topics for this subject only
      final subjectId = paperRes['subject_id'];
      final topicsRes = await _supabase
          .from('topics')
          .select('id, name')
          .eq('subject_id', subjectId)
          .order('name');

      _question = questionRes;
      _paper = paperRes;
      _allTopics = List<Map<String, dynamic>>.from(topicsRes);

      // Populate form
      _contentController.text = _question?['content'] ?? '';
      _officialAnswerController.text = _question?['official_answer'] ?? '';
      _questionNumber = _question?['question_number'] ?? 1;
      _imageUrl = _question?['image_url'];

      // Topic IDs
      final topicIds = _question?['topic_ids'];
      if (topicIds is List) {
        _selectedTopicIds = topicIds.map((e) => e.toString()).toList();
      }

      // Figure data from ai_answer
      final aiAnswer = _question?['ai_answer'];
      if (aiAnswer is Map) {
        _hasFigure = aiAnswer['has_figure'] == true;
        final loc = aiAnswer['figure_location'];
        if (loc is Map) {
          _figurePage = (loc['page'] as num?)?.toInt() ?? 1;
          _figureX = (loc['x_percent'] as num?)?.toDouble() ?? 10;
          _figureY = (loc['y_percent'] as num?)?.toDouble() ?? 30;
          _figureWidth = (loc['width_percent'] as num?)?.toDouble() ?? 40;
          _figureHeight = (loc['height_percent'] as num?)?.toDouble() ?? 30;
        }
      }

      // MCQ data
      _isMCQ = _question?['type'] == 'mcq';
      _correctAnswer = _question?['correct_answer']?.toString();
      _originalAnswer = _correctAnswer; // Store original AI answer
      final optionsRaw = _question?['options'];
      if (optionsRaw is List) {
        _options = optionsRaw.map((o) => Map<String, dynamic>.from(o as Map)).toList();
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        ToastService.showError('Failed to load question: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveQuestion() async {
    if (!_formKey.currentState!.validate()) return;

    if (mounted) setState(() => _isSaving = true);

    try {
      // Build ai_answer
      Map<String, dynamic>? aiAnswer;
      if (_hasFigure) {
        aiAnswer = {
          'has_figure': true,
          'figure_location': {
            'page': _figurePage,
            'x_percent': _figureX,
            'y_percent': _figureY,
            'width_percent': _figureWidth,
            'height_percent': _figureHeight,
          },
        };
      }

      // Prepare update data
      final updateData = {
        'content': _contentController.text.trim(),
        'official_answer': _officialAnswerController.text.trim(),
        'question_number': _questionNumber,
        'topic_ids': _selectedTopicIds,
        'ai_answer': aiAnswer,
        'options': _isMCQ ? _options : null,
        'correct_answer': _isMCQ ? _correctAnswer : null,
      };

      print('[QuestionEditor] Updating question ${widget.questionId}');
      print('[QuestionEditor] Update data: $updateData');

      // Update question
      final response = await _supabase
          .from('questions')
          .update(updateData)
          .eq('id', widget.questionId)
          .select();

      print('[QuestionEditor] Update response: $response');

      if (!mounted) return;
      ToastService.showSuccess('Question saved!');
      setState(() {
        _hasChanges = false;
        _isSaving = false;
      });
    } on PostgrestException catch (e) {
      // Detailed Postgrest error logging
      print('[QuestionEditor] PostgrestException:');
      print('  Code: ${e.code}');
      print('  Message: ${e.message}');
      print('  Details: ${e.details}');
      print('  Hint: ${e.hint}');

      if (mounted) {
        ToastService.showError('Database error: ${e.message}\nDetails: ${e.details ?? "None"}');
        setState(() => _isSaving = false);
      }
    } catch (e, stackTrace) {
      // General error logging
      print('[QuestionEditor] General error: $e');
      print('[QuestionEditor] Stack trace: $stackTrace');

      if (mounted) {
        ToastService.showError('Failed to save: $e');
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _cropFigure() async {
    if (_paper == null) return;

    if (mounted) setState(() => _isSaving = true);

    try {
      final response = await _supabase.functions.invoke(
        'crop-figure',
        body: {
          'pdfUrl': _paper!['pdf_url'],
          'questionId': widget.questionId,
          'page': _figurePage,
          'bbox': {
            'x': _figureX,
            'y': _figureY,
            'width': _figureWidth,
            'height': _figureHeight,
          },
        },
      );

      if (!mounted) return;

      if (response.data?['image_url'] != null) {
        // Add timestamp to bust browser cache
        final imageUrl = '${response.data['image_url']}?t=${DateTime.now().millisecondsSinceEpoch}';
        setState(() {
          _imageUrl = imageUrl;
        });
        ToastService.showSuccess('Figure cropped and saved!');
      } else {
        throw Exception(response.data?['error'] ?? 'Failed to crop');
      }
    } catch (e) {
      if (mounted) ToastService.showError('Crop failed: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final paperInfo = _paper != null
        ? '${_paper!['year']} ${_paper!['season']} V${_paper!['variant']}'
        : 'Unknown Paper';

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // Header
          _buildHeader(paperInfo),

          // Form (Split View)
          Expanded(
            child: Form(
              key: _formKey,
              child: Row(
                children: [
                  // LEFT COLUMN - Content & Visuals
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Content
                          _buildSection(
                            'Question Content',
                            TextFormField(
                              controller: _contentController,
                              decoration: _inputDecoration('Enter question content...'),
                              maxLines: 8,
                              style: const TextStyle(fontSize: 16),
                              onChanged: (_) => _markChanged(),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Figure section
                          _buildSection(
                            'Figure & Image',
                            _buildFigureSection(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Container(width: 1, color: AppColors.border),

                  // RIGHT COLUMN - Metadata & Answers
                  Expanded(
                    flex: 2,
                    child: Container(
                      color: AppColors.surface.withOpacity(0.5),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             // Question number
                            _buildSection(
                              'Question Number',
                              TextFormField(
                                initialValue: _questionNumber.toString(),
                                decoration: _inputDecoration('Q#'),
                                keyboardType: TextInputType.number,
                                onChanged: (v) {
                                  _questionNumber = int.tryParse(v) ?? 1;
                                  _markChanged();
                                },
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Topics (Optimized)
                            _buildSection(
                              'Topics',
                              _buildOptimizedTopicSelector(),
                            ),

                            const SizedBox(height: 24),

                            // Official Answer
                            _buildSection(
                              'Official Answer',
                              TextFormField(
                                controller: _officialAnswerController,
                                decoration: _inputDecoration('Enter official answer...'),
                                maxLines: 6,
                                onChanged: (_) => _markChanged(),
                              ),
                            ),

                             // MCQ Options (Editable)
                            if (_isMCQ) ...[
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildSection('MCQ Options', const SizedBox.shrink()),
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        final nextLabel = String.fromCharCode(65 + _options.length); // A, B, C...
                                        _options.add({'label': nextLabel, 'text': ''});
                                        _markChanged();
                                      });
                                    },
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Add Option'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Column(
                                children: [
                                  for (int i = 0; i < _options.length; i++)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: _options[i]['label'] == _correctAnswer
                                              ? Colors.green
                                              : AppColors.border,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // Correct Answer Radio
                                          Radio<String>(
                                            value: _options[i]['label'] ?? '',
                                            groupValue: _correctAnswer,
                                            activeColor: Colors.green,
                                            onChanged: (val) {
                                              setState(() {
                                                _correctAnswer = val;
                                                _markChanged();
                                              });
                                            },
                                          ),
                                          // Label Field
                                          SizedBox(
                                            width: 40,
                                            child: TextFormField(
                                              initialValue: _options[i]['label'],
                                              textAlign: TextAlign.center,
                                              decoration: const InputDecoration(
                                                border: InputBorder.none,
                                                isDense: true,
                                              ),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: _options[i]['label'] == _correctAnswer ? Colors.green : AppColors.textPrimary,
                                              ),
                                              onChanged: (val) {
                                                _options[i]['label'] = val;
                                                _markChanged();
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Text Field
                                          Expanded(
                                            child: TextFormField(
                                              initialValue: _options[i]['text'],
                                              decoration: const InputDecoration(
                                                border: InputBorder.none,
                                                hintText: 'Option text...',
                                                isDense: true,
                                              ),
                                              style: TextStyle(color: AppColors.textPrimary.withOpacity(0.9)),
                                              maxLines: null,
                                              onChanged: (val) {
                                                _options[i]['text'] = val;
                                                _markChanged();
                                              },
                                            ),
                                          ),
                                          // Delete Option
                                          IconButton(
                                            icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                                            onPressed: () {
                                              setState(() {
                                                if (_correctAnswer == _options[i]['label']) {
                                                  _correctAnswer = null;
                                                }
                                                _options.removeAt(i);
                                                _markChanged();
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptimizedTopicSelector() {
    // Filter available topics based on search query
    final filteredTopics = _allTopics.where((t) {
      final name = (t['name'] ?? '').toString().toLowerCase();
      final query = _topicSearchQuery.toLowerCase();
      return name.contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected Topics Chips (Keep these for quick view/remove)
        if (_selectedTopicIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedTopicIds.map((id) {
                final topic = _allTopics.firstWhere((t) => t['id'] == id, orElse: () => {'name': 'Unknown'});
                return Chip(
                  label: Text(topic['name'], style: const TextStyle(fontSize: 12)),
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  labelStyle: const TextStyle(color: AppColors.primary),
                  deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.primary),
                  onDeleted: () {
                    setState(() {
                      _selectedTopicIds.remove(id);
                      _markChanged();
                    });
                  },
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                );
              }).toList(),
            ),
          ),

        // Selector Container
        Container(
          height: 300,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  decoration: _inputDecoration('Search topics...').copyWith(
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (v) => setState(() => _topicSearchQuery = v),
                ),
              ),

              // List
              Expanded(
                child: ListView.builder(
                  itemCount: filteredTopics.length,
                  itemBuilder: (context, index) {
                    final topic = filteredTopics[index];
                    final isSelected = _selectedTopicIds.contains(topic['id']);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(topic['name'] ?? '', style: const TextStyle(color: AppColors.textPrimary)),
                      activeColor: AppColors.primary,
                      checkColor: Colors.white,
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (bool? selected) {
                        setState(() {
                          if (selected == true) {
                            _selectedTopicIds.add(topic['id']);
                          } else {
                            _selectedTopicIds.remove(topic['id']);
                          }
                          _markChanged();
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFigureSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Has figure toggle
          Row(
            children: [
              Switch(
                value: _hasFigure,
                onChanged: (v) {
                  setState(() {
                    _hasFigure = v;
                    _markChanged();
                  });
                },
                activeColor: const Color(0xFF6366F1),
              ),
              const SizedBox(width: 8),
              Text(
                'Has Figure',
                style: TextStyle(
                  color: AppColors.textPrimary.withOpacity(0.8),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          if (_hasFigure) ...[
            const SizedBox(height: 16),

            // Current image preview
            if (_imageUrl != null) ...[
              Container(
                height: 250, // Larger preview
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.border,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _imageUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Crop controls
            Row(
              children: [
                Expanded(
                  child: _buildSlider('Page', _figurePage.toDouble(), 1, 20, (v) {
                    setState(() {
                      _figurePage = v.round();
                      _markChanged();
                    });
                  }),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(child: _buildSlider('X', _figureX, 0, 100, (v) {
                  setState(() { _figureX = v; _markChanged(); });
                })),
                const SizedBox(width: 16),
                Expanded(child: _buildSlider('Y', _figureY, 0, 100, (v) {
                  setState(() { _figureY = v; _markChanged(); });
                })),
              ],
            ),
            Row(
              children: [
                Expanded(child: _buildSlider('W', _figureWidth, 5, 100, (v) {
                  setState(() { _figureWidth = v; _markChanged(); });
                })),
                const SizedBox(width: 16),
                Expanded(child: _buildSlider('H', _figureHeight, 5, 100, (v) {
                  setState(() { _figureHeight = v; _markChanged(); });
                })),
              ],
            ),

            const SizedBox(height: 16),

            // Crop button - opens dialog
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _openCropDialog,
                icon: const Icon(Icons.crop),
                label: const Text('Open Crop Editor'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(String paperInfo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.arrow_back),
            color: AppColors.textPrimary,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Question $_questionNumber',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                paperInfo,
                style: TextStyle(
                  color: AppColors.textPrimary.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (_hasChanges)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Unsaved changes',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                ),
              ),
            ),
          // Delete button
          if (widget.onDelete != null)
            IconButton(
              onPressed: widget.onDelete,
              icon: const Icon(Icons.delete_outline),
              color: Colors.red.withValues(alpha: 0.7),
              tooltip: 'Delete question',
            ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveQuestion,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(_isSaving ? 'Saving...' : 'Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppColors.textPrimary.withValues(alpha: 0.8),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }

  Future<void> _openCropDialog() async {
    final pdfUrl = _paper?['pdf_url'];
    if (pdfUrl == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CropDialog(
        pdfUrl: pdfUrl,
        page: _figurePage,
        x: _figureX,
        y: _figureY,
        width: _figureWidth,
        height: _figureHeight,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _figurePage = result['page'];
        _figureX = result['x'];
        _figureY = result['y'];
        _figureWidth = result['width'];
        _figureHeight = result['height'];
        _markChanged();
      });

      // Crop the figure
      await _cropFigure();
    }
  }

  Widget _buildSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppColors.textPrimary.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
            Text(
              value.toStringAsFixed(0),
              style: TextStyle(
                color: AppColors.textPrimary.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: const Color(0xFF6366F1),
            inactiveColor: AppColors.border,
          ),
        ),
      ],
    );
  }
}

/// Fullscreen crop dialog with visual preview
class _CropDialog extends StatefulWidget {
  final String pdfUrl;
  final int page;
  final double x;
  final double y;
  final double width;
  final double height;

  const _CropDialog({
    required this.pdfUrl,
    required this.page,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  @override
  State<_CropDialog> createState() => _CropDialogState();
}

class _CropDialogState extends State<_CropDialog> {
  final _supabase = Supabase.instance.client;

  late int _page;
  late double _x;
  late double _y;
  late double _width;
  late double _height;

  String? _pageImageUrl;
  bool _isLoadingPage = false;

  @override
  void initState() {
    super.initState();
    _page = widget.page;
    _x = widget.x;
    _y = widget.y;
    _width = widget.width;
    _height = widget.height;
    _loadPage();
  }

  Future<void> _loadPage() async {
    setState(() => _isLoadingPage = true);

    try {
      final response = await _supabase.functions.invoke(
        'render-page',
        body: {
          'pdfUrl': widget.pdfUrl,
          'page': _page,
        },
      );

      if (response.data?['image_url'] != null) {
        setState(() {
          _pageImageUrl = response.data['image_url'];
          _isLoadingPage = false;
        });
      } else {
        setState(() => _isLoadingPage = false);
      }
    } catch (e) {
      setState(() => _isLoadingPage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.sidebar,
              border: Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  color: AppColors.textPrimary,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Crop Figure',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context, {
                      'page': _page,
                      'x': _x,
                      'y': _y,
                      'width': _width,
                      'height': _height,
                    });
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Apply & Crop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: Row(
              children: [
                // Preview area
                Expanded(
                  flex: 3,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _isLoadingPage
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 12),
                                Text(
                                  'Loading page...',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ],
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              return Center(
                                child: _buildPreviewWithCrop(
                                  constraints.maxWidth * 0.9,
                                  constraints.maxHeight * 0.9,
                                ),
                              );
                            },
                          ),
                  ),
                ),

                // Controls
                Container(
                  width: 280,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.sidebar,
                    border: Border(
                      left: BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Page selector
                      Text(
                        'Page',
                        style: TextStyle(
                          color: AppColors.textPrimary.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _page > 1 ? () {
                              setState(() => _page--);
                              _loadPage();
                            } : null,
                            icon: const Icon(Icons.remove),
                            color: Colors.white,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$_page',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() => _page++);
                              _loadPage();
                            },
                            icon: const Icon(Icons.add),
                            color: Colors.white,
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Position
                      _buildSlider('X Position', _x, (v) => setState(() => _x = v)),
                      _buildSlider('Y Position', _y, (v) => setState(() => _y = v)),
                      _buildSlider('Width', _width, (v) => setState(() => _width = v)),
                      _buildSlider('Height', _height, (v) => setState(() => _height = v)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewWithCrop(double maxW, double maxH) {
    // pdf.co renders at 72 DPI by default: 595 x 842 pixels for A4
    const aspectRatio = 595 / 842;
    double w = maxW;
    double h = maxH;

    if (w / h > aspectRatio) {
      w = h * aspectRatio;
    } else {
      h = w / aspectRatio;
    }

    final cropLeft = (_x / 100) * w;
    final cropTop = (_y / 100) * h;
    final cropWidth = (_width / 100) * w;
    final cropHeight = (_height / 100) * h;

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          // Page image
          if (_pageImageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                _pageImageUrl!,
                width: w,
                height: h,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.white,
                  child: const Center(child: Icon(Icons.error)),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(
                child: Text('Page preview', style: TextStyle(color: Colors.grey)),
              ),
            ),

          // Dark overlay on non-crop areas
          Positioned.fill(
            child: CustomPaint(
              painter: _CropOverlayPainter(
                cropRect: Rect.fromLTWH(cropLeft, cropTop, cropWidth, cropHeight),
              ),
            ),
          ),

          // Crop box border (draggable to move)
          Positioned(
            left: cropLeft,
            top: cropTop,
            width: cropWidth,
            height: cropHeight,
            child: GestureDetector(
              onPanUpdate: (d) {
                setState(() {
                  _x += (d.delta.dx / w) * 100;
                  _y += (d.delta.dy / h) * 100;
                  _x = _x.clamp(0, 100 - _width);
                  _y = _y.clamp(0, 100 - _height);
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF6366F1), width: 2),
                ),
                child: Center(
                  child: Icon(
                    Icons.open_with,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),

          // Corner resize handles
          // Top-left
          _buildResizeHandle(cropLeft - 6, cropTop - 6, w, h, 'topLeft'),
          // Top-right
          _buildResizeHandle(cropLeft + cropWidth - 6, cropTop - 6, w, h, 'topRight'),
          // Bottom-left
          _buildResizeHandle(cropLeft - 6, cropTop + cropHeight - 6, w, h, 'bottomLeft'),
          // Bottom-right
          _buildResizeHandle(cropLeft + cropWidth - 6, cropTop + cropHeight - 6, w, h, 'bottomRight'),
        ],
      ),
    );
  }

  Widget _buildResizeHandle(double left, double top, double containerW, double containerH, String corner) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanUpdate: (d) {
          setState(() {
            final dx = (d.delta.dx / containerW) * 100;
            final dy = (d.delta.dy / containerH) * 100;

            switch (corner) {
              case 'topLeft':
                _x = (_x + dx).clamp(0, _x + _width - 5);
                _y = (_y + dy).clamp(0, _y + _height - 5);
                _width = (_width - dx).clamp(5, 100);
                _height = (_height - dy).clamp(5, 100);
                break;
              case 'topRight':
                _y = (_y + dy).clamp(0, _y + _height - 5);
                _width = (_width + dx).clamp(5, 100 - _x);
                _height = (_height - dy).clamp(5, 100);
                break;
              case 'bottomLeft':
                _x = (_x + dx).clamp(0, _x + _width - 5);
                _width = (_width - dx).clamp(5, 100);
                _height = (_height + dy).clamp(5, 100 - _y);
                break;
              case 'bottomRight':
                _width = (_width + dx).clamp(5, 100 - _x);
                _height = (_height + dy).clamp(5, 100 - _y);
                break;
            }
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

  Widget _buildSlider(String label, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.6), fontSize: 12),
              ),
              Text(
                '${value.toStringAsFixed(0)}%',
                style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.8), fontSize: 12),
              ),
            ],
          ),
          Slider(
            value: value.clamp(0, 100),
            min: 0,
            max: 100,
            onChanged: onChanged,
            activeColor: const Color(0xFF6366F1),
            inactiveColor: AppColors.border,
          ),
        ],
      ),
    );
  }
}

/// Painter for crop overlay
class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;

  _CropOverlayPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.5);

    // Top
    canvas.drawRect(
      Rect.fromLTRB(0, 0, size.width, cropRect.top),
      paint,
    );
    // Bottom
    canvas.drawRect(
      Rect.fromLTRB(0, cropRect.bottom, size.width, size.height),
      paint,
    );
    // Left
    canvas.drawRect(
      Rect.fromLTRB(0, cropRect.top, cropRect.left, cropRect.bottom),
      paint,
    );
    // Right
    canvas.drawRect(
      Rect.fromLTRB(cropRect.right, cropRect.top, size.width, cropRect.bottom),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect;
  }
}
