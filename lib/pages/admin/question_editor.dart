import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/toast_service.dart';
import '../../core/services/pdf_helper.dart';
import '../../features/past_papers/widgets/pdf_crop_viewer.dart';
import 'package:test_squared/features/past_papers/models/question_blocks.dart'; // ExamContentBlocks

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
  late TextEditingController _aiSolutionController;
  int _questionNumber = 1;
  List<String> _selectedTopicIds = [];
  String _topicSearchQuery = '';
  String? _imageUrl;
  bool _isTopicsExpanded = false; // Collapsible topics selector

  // Figure cropping
  bool _hasFigure = false;
  int _figurePage = 1;
  double _figureX = 10;
  double _figureY = 30;
  double _figureWidth = 40;
  double _figureHeight = 30;

  // Structured fields
  bool _isStructured = false;
  List<ExamContentBlock> _structureBlocks = [];

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
    _aiSolutionController = TextEditingController();
    _loadQuestion();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _officialAnswerController.dispose();
    _aiSolutionController.dispose();
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

      // STRUCTURED DATA
      final structureData = _question?['structure_data'];
      if (structureData != null && structureData is List && structureData.isNotEmpty) {
        _isStructured = true;
        try {
            _structureBlocks = (structureData as List).map((x) {
               // Handle the JSON map -> Block conversion
               // Assuming ExamContentBlock.fromMap factory exists and handles 'type'
                final map = Map<String, dynamic>.from(x as Map);
                // Simple factory dispatch based on type if not in model
                final type = map['type'];
                if (type == 'text') return TextBlock.fromMap(map);
                if (type == 'figure') return FigureBlock.fromMap(map);
                if (type == 'question_part') return QuestionPartBlock.fromMap(map);
                return TextBlock(content: 'Unknown block type: $type');
            }).toList();
        } catch (e) {
            print('Error parsing structure data: $e');
            _isStructured = false; // Fallback
        }
      }

      // AI Solution
      if (aiAnswer is Map) {
        _aiSolutionController.text = aiAnswer['text']?.toString() ?? aiAnswer['ai_solution']?.toString() ?? '';
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
    print('[QuestionEditor] _saveQuestion called');
    print('[QuestionEditor] _formKey.currentState: ${_formKey.currentState}');
    print('[QuestionEditor] _isStructured: $_isStructured');
    print('[QuestionEditor] _structureBlocks.length: ${_structureBlocks.length}');

    if (_formKey.currentState == null) {
      print('[QuestionEditor] ERROR: Form key current state is null!');
      ToastService.showError('Form not initialized properly');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      print('[QuestionEditor] Form validation failed');
      ToastService.showError('Please fill in all required fields');
      return;
    }

    if (mounted) setState(() => _isSaving = true);

    try {
      // Build ai_answer - Merge with existing
      Map<String, dynamic> aiAnswer = {};
      if (_question?['ai_answer'] is Map) {
         aiAnswer = Map<String, dynamic>.from(_question!['ai_answer']);
      }

      if (_hasFigure) {
        aiAnswer['has_figure'] = true;
        aiAnswer['figure_location'] = {
            'page': _figurePage,
            'x_percent': _figureX,
            'y_percent': _figureY,
            'width_percent': _figureWidth,
            'height_percent': _figureHeight,
        };
      } else {
        aiAnswer['has_figure'] = false;
      }

      // Save AI Solution
      if (_aiSolutionController.text.isNotEmpty) {
        aiAnswer['text'] = _aiSolutionController.text.trim();
        aiAnswer['ai_solution'] = _aiSolutionController.text.trim();
      }

      // Prepare update data
      final Map<String, dynamic> updateData = {
        'question_number': _questionNumber,
        'topic_ids': _selectedTopicIds,
        'ai_answer': aiAnswer,
      };

      if (_isStructured) {
         // STRUCTURED UPDATE
         // 1. Save blocks
         updateData['structure_data'] = _structureBlocks.map((b) => b.toMap()).toList();
         updateData['type'] = 'structured';

         // 2. Generate summary content
         final summary = _structureBlocks
            .whereType<TextBlock>()
            .map((b) => b.content)
            .take(2)
            .join(' ');
         updateData['content'] = summary.isNotEmpty ? summary : 'Structured Question $_questionNumber';

         // 3. Official answer and marks?
         // Note: official_answer logic for structured is complex, maybe just leave basic field?
         // For now, let's keep the main official_answer field as a fallback/summary
         updateData['official_answer'] = _officialAnswerController.text.trim();

      } else {
         // LEGACY/MCQ UPDATE
         updateData['content'] = _contentController.text.trim();
         updateData['official_answer'] = _officialAnswerController.text.trim();
         updateData['options'] = _isMCQ ? _options : null;
         updateData['correct_answer'] = _isMCQ ? _correctAnswer : null;
      }

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

  // --- STRUCTURED BLOCK HELPERS ---

  void _addTextBlock() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Add Text Block'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Enter text content...', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  setState(() {
                    _structureBlocks.add(TextBlock(content: controller.text));
                    _markChanged();
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addFigureBlock() {
    showDialog(
      context: context,
      builder: (context) {
        final urlController = TextEditingController();
        final labelController = TextEditingController(text: 'Figure ${_structureBlocks.whereType<FigureBlock>().length + 1}');
        final descController = TextEditingController();
        return AlertDialog(
          title: const Text('Add Figure Block'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlController,
                decoration: const InputDecoration(labelText: 'Image URL', hintText: 'https://...', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: labelController,
                decoration: const InputDecoration(labelText: 'Figure Label', hintText: 'Figure 1', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (labelController.text.isNotEmpty) {
                  setState(() {
                    _structureBlocks.add(FigureBlock(
                      url: urlController.text.isEmpty ? null : urlController.text,
                      figureLabel: labelController.text,
                      description: descController.text,
                    ));
                    _markChanged();
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _addQuestionPartBlock() {
    _openQuestionPartDialog();
  }

  void _openQuestionPartDialog({QuestionPartBlock? existingBlock, int? index}) {
    showDialog(
      context: context,
      builder: (context) {
        final labelController = TextEditingController(text: existingBlock?.label ?? _getNextPartLabel());
        final contentController = TextEditingController(text: existingBlock?.content ?? '');
        final marksController = TextEditingController(text: existingBlock?.marks.toString() ?? '1');
        final answerController = TextEditingController(text: existingBlock?.correctAnswer?.toString() ?? '');
        final officialAnswerController = TextEditingController(text: existingBlock?.officialAnswer ?? '');
        final aiAnswerController = TextEditingController(text: existingBlock?.aiAnswer ?? '');
        String inputType = existingBlock?.inputType ?? 'text_area';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existingBlock == null ? 'Add Question Part' : 'Edit Question Part'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: labelController,
                      decoration: const InputDecoration(labelText: 'Part Label', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Question Text', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: marksController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Marks', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: inputType,
                      decoration: const InputDecoration(labelText: 'Input Type', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'text_area', child: Text('Text Area')),
                        DropdownMenuItem(value: 'fill_in_blanks', child: Text('Fill in Blanks')),
                        DropdownMenuItem(value: 'mcq', child: Text('Multiple Choice')),
                      ],
                      onChanged: (value) => setDialogState(() => inputType = value!),
                    ),
                     const SizedBox(height: 12),
                    TextField(
                      controller: officialAnswerController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Official Answer / Mark Scheme',
                        border: OutlineInputBorder(),
                        hintText: 'Explanation from mark scheme...'
                      ),
                    ),
                     const SizedBox(height: 12),
                    TextField(
                      controller: aiAnswerController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'AI Answer / Explanation',
                        border: OutlineInputBorder(),
                        hintText: 'AI generated explanation...'
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    if (labelController.text.isNotEmpty && contentController.text.isNotEmpty) {
                      setState(() {
                        final newBlock = QuestionPartBlock(
                          label: labelController.text,
                          content: contentController.text,
                          marks: int.tryParse(marksController.text) ?? 1,
                          inputType: inputType,
                          correctAnswer: answerController.text,
                          officialAnswer: officialAnswerController.text,
                          aiAnswer: aiAnswerController.text,
                        );

                        if (index != null && index < _structureBlocks.length) {
                          _structureBlocks[index] = newBlock;
                        } else {
                          _structureBlocks.add(newBlock);
                        }
                         _markChanged();
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: Text(existingBlock == null ? 'Add' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getNextPartLabel() {
     final parts = _structureBlocks.whereType<QuestionPartBlock>().length;
     // Simple labeling strategy
     const labels = ['a)', 'b)', 'c)', 'd)', 'e)', 'f)'];
     if (parts < labels.length) return labels[parts];
     return '';
  }

  void _removeBlock(int index) {
    setState(() {
      _structureBlocks.removeAt(index);
      _markChanged();
    });
  }

  Widget _buildBlockPreview(int index) {
    final block = _structureBlocks[index];

    return Card(
      key: ValueKey(block),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text('${block.type.toUpperCase()} Block'),
        subtitle: _buildBlockContent(block),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (block is QuestionPartBlock)
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _openQuestionPartDialog(existingBlock: block, index: index),
              ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _removeBlock(index),
            ),
          ],
        ),
        leading: const Icon(Icons.drag_handle),
      ),
    );
  }

  Future<void> _editFigureCrop(int index) async {
    final block = _structureBlocks[index];
    if (block is! FigureBlock || _paper == null || _paper!['pdf_url'] == null) return;

    // Extract current crop info or use defaults
    int page = 1;
    double x = 10, y = 30, w = 40, h = 30;

    if (block.meta != null) {
      if (block.meta!.containsKey('page')) page = (block.meta!['page'] as num).toInt();
      // bbox might be nested or flat, let's look for bbox object first
      var bbox = block.meta!['bbox'];
      if (bbox is Map) {
         x = (bbox['x'] as num?)?.toDouble() ?? x;
         y = (bbox['y'] as num?)?.toDouble() ?? y;
         w = (bbox['width'] as num?)?.toDouble() ?? w;
         h = (bbox['height'] as num?)?.toDouble() ?? h;
      }
    }

    // Open Crop Dialog
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CropDialog(
        pdfUrl: _paper!['pdf_url'],
        page: page,
        x: x,
        y: y,
        width: w,
        height: h,
      ),
    );

    if (result != null && mounted) {
      setState(() => _isSaving = true);

      try {
        // We have new crop coordinates, call crop-figure immediately
        final newPage = result['page'] as int;
        final newBbox = {
           'x': result['x'],
           'y': result['y'],
           'width': result['width'],
           'height': result['height']
        };

        final response = await _supabase.functions.invoke(
          'crop-figure',
          body: {
            'pdfUrl': _paper!['pdf_url'],
            'questionId': widget.questionId,
            'page': newPage,
            'bbox': newBbox,
          },
        );

        if (response.data?['image_url'] != null) {
           final newUrl = '${response.data['image_url']}?t=${DateTime.now().millisecondsSinceEpoch}';

           setState(() {
              // Update the block with new URL and Metadata
              _structureBlocks[index] = FigureBlock(
                 url: newUrl,
                 figureLabel: block.figureLabel,
                 description: block.description,
                 meta: {
                    'page': newPage,
                    'bbox': newBbox
                 }
              );
              _markChanged();
           });
           ToastService.showSuccess('Figure updated!');
        } else {
           throw Exception(response.data?['error'] ?? 'No image returned');
        }

      } catch (e) {
        ToastService.showError('Crop update failed: $e');
      } finally {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildBlockContent(ExamContentBlock block) {
    if (block is TextBlock) {
      return Text(block.content, maxLines: 2, overflow: TextOverflow.ellipsis);
    } else if (block is FigureBlock) {
      final index = _structureBlocks.indexOf(block);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
               Text('Label: ${block.figureLabel}', style: const TextStyle(fontWeight: FontWeight.bold)),
               const Spacer(),
               if (index != -1)
                 TextButton.icon(
                    icon: const Icon(Icons.crop, size: 16),
                    label: const Text('Edit Crop', style: TextStyle(fontSize: 12)),
                    onPressed: () => _editFigureCrop(index),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                 ),
            ],
          ),
          if (block.url != null)
             Text('URL: ${block.url}', style: const TextStyle(fontSize: 12))
          else
             const Text('No Image URL (Waiting for crop)', style: TextStyle(fontSize: 12, color: Colors.orange)),
        ],
      );
    } else if (block is QuestionPartBlock) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Part ${block.label}  [${block.marks} marks]', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(block.content, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final paperInfo = _paper != null
        ? '${_paper!['year']} ${_paper!['season']} V${_paper!['variant']}'
        : 'Unknown Paper';

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _saveQuestion,
      },
      child: Focus(
        autofocus: true,
        child: Container(
          color: AppColors.background,
          child: Column(
            children: [
              // Header
              _buildHeader(paperInfo),

              // Form - Vertical Layout (single scrollable column)
              Expanded(
                child: _isStructured ? _buildStructuredForm() : _buildLegacyForm(),
              ),
            ],
          ),
        ),
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
        // Selected Topics Chips (Always visible)
        if (_selectedTopicIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _selectedTopicIds.map((id) {
                final topic = _allTopics.firstWhere((t) => t['id'] == id, orElse: () => {'name': 'Unknown'});
                return Chip(
                  label: Text(topic['name'], style: const TextStyle(fontSize: 11)),
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  labelStyle: const TextStyle(color: AppColors.primary),
                  deleteIcon: const Icon(Icons.close, size: 12, color: AppColors.primary),
                  onDeleted: () {
                    setState(() {
                      _selectedTopicIds.remove(id);
                      _markChanged();
                    });
                  },
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              }).toList(),
            ),
          ),

        // Collapsible selector toggle
        InkWell(
          onTap: () => setState(() => _isTopicsExpanded = !_isTopicsExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  _isTopicsExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  _isTopicsExpanded ? 'Hide topic selector' : 'Add topics (${_allTopics.length} available)',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                if (_selectedTopicIds.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_selectedTopicIds.length} selected',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Expandable selector (only shown when expanded)
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _isTopicsExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            margin: const EdgeInsets.only(top: 8),
            height: 200, // Reduced from 300
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
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
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
                        title: Text(topic['name'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                        activeColor: AppColors.primary,
                        checkColor: Colors.white,
                        dense: true,
                        visualDensity: VisualDensity.compact,
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
            ] else if (_paper != null && _paper!['pdf_url'] != null) ...[
              // Client-side PDF Crop Preview
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: PdfCropViewer(
                  pdfUrl: _paper!['pdf_url'],
                  pageNumber: _figurePage,
                  x: _figureX,
                  y: _figureY,
                  width: _figureWidth,
                  height: _figureHeight,
                ),
              ),
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

  // --- FORM BUILDERS ---

  Widget _buildLegacyForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question Content
            _buildSection(
              'Question Content',
              TextFormField(
                controller: _contentController,
                decoration: _inputDecoration('Enter question content...'),
                maxLines: 6,
                style: const TextStyle(fontSize: 15),
                onChanged: (_) => _markChanged(),
              ),
            ),

            const SizedBox(height: 20),

            // Two columns for metadata: Question Number + Topics
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question Number (small)
                SizedBox(
                  width: 120,
                  child: _buildSection(
                    'Q#',
                    TextFormField(
                      initialValue: _questionNumber.toString(),
                      decoration: _inputDecoration(''),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        _questionNumber = int.tryParse(v) ?? 1;
                        _markChanged();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // Topics (expandable)
                Expanded(
                  child: _buildSection(
                    'Topics',
                    _buildOptimizedTopicSelector(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Figure & Image Section
            _buildSection(
              'Figure & Image',
              _buildFigureSection(),
            ),

            const SizedBox(height: 20),

            // Official Answer
            _buildSection(
              'Official Answer',
              TextFormField(
                controller: _officialAnswerController,
                decoration: _inputDecoration('Enter official answer...'),
                maxLines: 5,
                onChanged: (val) {
                  _markChanged();
                  // Sync to MCQ selection if it matches an option label
                  if (_isMCQ && val.trim().isNotEmpty) {
                    final upperVal = val.trim().toUpperCase();
                    final matchingOption = _options.firstWhere(
                      (opt) => (opt['label'] as String?)?.toUpperCase() == upperVal,
                      orElse: () => {},
                    );
                    if (matchingOption.isNotEmpty) {
                      setState(() => _correctAnswer = matchingOption['label']);
                    }
                  }
                },
              ),
            ),

            const SizedBox(height: 20),

            // AI Solution
            _buildSection(
              'AI Solution (Step-by-Step)',
              TextFormField(
                controller: _aiSolutionController,
                decoration: _inputDecoration('AI generated solution...'),
                maxLines: 6,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary.withOpacity(0.9),
                ),
                onChanged: (_) => _markChanged(),
              ),
            ),

            // MCQ Options (if applicable)
            if (_isMCQ) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSection('MCQ Options', const SizedBox.shrink()),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        final nextLabel = String.fromCharCode(65 + _options.length);
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
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _options[i]['label'] == _correctAnswer
                              ? Colors.green
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: _options[i]['label'] ?? '',
                            groupValue: _correctAnswer,
                            activeColor: Colors.green,
                            onChanged: (val) {
                              setState(() {
                                _correctAnswer = val;
                                // Sync to Official Answer field
                                if (val != null && _isMCQ) {
                                  _officialAnswerController.text = val;
                                }
                                _markChanged();
                              });
                            },
                          ),
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

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStructuredForm() {
    return Row(
      children: [
        // Left - Editor
        Expanded(
          flex: 5, // 50%
          child: Column(
            children: [
               Expanded(
                 child: ReorderableListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _structureBlocks.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                         if (oldIndex < newIndex) {
                           newIndex -= 1;
                         }
                         final item = _structureBlocks.removeAt(oldIndex);
                         _structureBlocks.insert(newIndex, item);
                         _markChanged();
                      });
                    },
                    itemBuilder: (context, index) {
                      return _buildBlockPreview(index);
                    },
                 ),
               ),
               // Action Bar
               Container(
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(
                   color: AppColors.surface,
                   border: Border(top: BorderSide(color: AppColors.border)),
                 ),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     ElevatedButton.icon(onPressed: _addTextBlock, icon: const Icon(Icons.text_fields), label: const Text('Text')),
                     const SizedBox(width: 8),
                     ElevatedButton.icon(onPressed: _addFigureBlock, icon: const Icon(Icons.image), label: const Text('Figure')),
                     const SizedBox(width: 8),
                     ElevatedButton.icon(onPressed: _addQuestionPartBlock, icon: const Icon(Icons.quiz), label: const Text('Part')),
                   ],
                 ),
               ),
            ],
          ),
        ),

        // Right - Metadata (Topics, Q#, etc.)
        Container(width: 1, color: AppColors.border),
        Expanded(
          flex: 4, // 40%
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text('Metadata', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 16),

                   // Q Number
                   TextFormField(
                      initialValue: _questionNumber.toString(),
                      decoration: _inputDecoration('Q Number'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        _questionNumber = int.tryParse(v) ?? 1;
                        _markChanged();
                      },
                   ),

                   const SizedBox(height: 16),
                   _buildSection('Topics', _buildOptimizedTopicSelector()),

                   const SizedBox(height: 16),

                   // AI & Official Answer Summary
                   _buildSection(
                      'AI Answer Overview',
                      TextFormField(
                        controller: _aiSolutionController,
                        decoration: _inputDecoration('General AI Explanation...'),
                        maxLines: 4,
                        onChanged: (_) => _markChanged(),
                      ),
                   ),

                   const SizedBox(height: 16),
                   _buildSection(
                      'Official Answer Note',
                      TextFormField(
                        controller: _officialAnswerController,
                        decoration: _inputDecoration('Mark scheme notes...'),
                        maxLines: 4,
                        onChanged: (_) => _markChanged(),
                      ),
                   ),
                ],
              ),
            ),
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

  bool _isLoading = true;
  bool _hasError = false;
  String? _imageUrl;
  Uint8List? _imageBase64;
  String? _errorMessage;

  void notifyError(String msg) {
    setState(() {
      _hasError = true;
      _errorMessage = msg;
    });
    debugPrint('❌ Render Error: $msg');
  }

  late int _page;
  late double _x;
  late double _y;
  late double _width;
  late double _height;

  @override
  void initState() {
    super.initState();
    // Ensure page is at least 1
    _page = widget.page > 0 ? widget.page : 1;
    _x = widget.x;
    _y = widget.y;
    _width = widget.width;
    _height = widget.height;
    _renderPageAsImage();
  }

  Future<void> _renderPageAsImage() async {
    try {
      debugPrint('🖼️ Rendering page $_page as image...');

      // Call render-page edge function to convert PDF page to PNG
      final response = await _supabase.functions.invoke(
        'render-page',
        body: {
          'pdfUrl': widget.pdfUrl,
          'page': _page,
        },
      );

      if (response.status != 200) {
        notifyError('Render failed: HTTP ${response.status}');
        setState(() => _isLoading = false);
        return;
      }

      final data = response.data;
      if (data['error'] != null) {
        notifyError(data['error'].toString());
        setState(() => _isLoading = false);
        return;
      }

      final imageBase64 = data['image_base64'] as String?;
      final imageUrl = data['image_url'] as String?;

      if (imageBase64 != null) {
         debugPrint('✅ Page rendered (Base64)');
         setState(() {
            _imageBase64 = base64Decode(imageBase64);
            _imageUrl = null;
            _isLoading = false;
         });
      } else if (imageUrl != null) {
          debugPrint('✅ Page rendered (URL): $imageUrl');
          setState(() {
            _imageUrl = imageUrl;
            _imageBase64 = null;
            _isLoading = false;
          });
      } else {
        notifyError('No image data returned');
        setState(() => _isLoading = false);
      }

    } catch (e) {
      notifyError('Failed to render page: $e');
      setState(() => _isLoading = false);
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
                    child: LayoutBuilder(
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
                              setState(() {
                                _page--;
                                _isLoading = true;
                                _imageUrl = null;
                              });
                              _renderPageAsImage();
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
                              setState(() {
                                _page++;
                                _isLoading = true;
                                _imageUrl = null;
                              });
                              _renderPageAsImage();
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
          // Loading indicator
          if (_isLoading)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Rendering page...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),

          // Rendered page image (from pdf.co)
          // Rendered page image (from pdf.co)
          if (_imageBase64 != null)
             Positioned.fill(
               child: Image.memory(
                  _imageBase64!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(child: Text('Failed to load image', style: TextStyle(color: Colors.red)));
                  },
               ),
             )
          else if (_imageUrl != null)
            Positioned.fill(
              child: Image.network(
                _imageUrl!,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(child: Text('Failed to load image', style: TextStyle(color: Colors.red)));
                },
              ),
            ),

          if (_hasError)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.8),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       const Icon(Icons.error_outline, color: Colors.red, size: 48),
                       const SizedBox(height: 16),
                       const Text('Failed to render page', style: TextStyle(color: Colors.white, fontSize: 18)),
                       const SizedBox(height: 8),
                       Text(_errorMessage ?? 'Unknown error', style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
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
