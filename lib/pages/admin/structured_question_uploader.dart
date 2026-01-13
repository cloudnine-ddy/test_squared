import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/toast_service.dart';
import 'package:test_squared/features/past_papers/models/question_blocks.dart'; // ExamContentBlocks

/// Admin widget for creating structured questions with dynamic blocks
class StructuredQuestionUploader extends StatefulWidget {
  const StructuredQuestionUploader({super.key});

  @override
  State<StructuredQuestionUploader> createState() => _StructuredQuestionUploaderState();
}

class _StructuredQuestionUploaderState extends State<StructuredQuestionUploader> {
  final _formKey = GlobalKey<FormState>();
  final List<ExamContentBlock> _blocks = [];
  
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _topics = [];
  String? _selectedSubjectId;
  List<String> _selectedTopicIds = [];
  int _questionNumber = 1;
  int _totalMarks = 1;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchSubjects();
  }

  Future<void> _fetchSubjects() async {
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('subjects')
          .select('id, name')
          .order('name');
      
      if (mounted) {
        setState(() {
          _subjects = List<Map<String, dynamic>>.from(data);
          if (_subjects.isNotEmpty) {
            _selectedSubjectId = _subjects.first['id']?.toString();
            _fetchTopics();
          }
        });
      }
    } catch (e) {
      ToastService.showError('Failed to load subjects');
    }
  }

  Future<void> _fetchTopics() async {
    if (_selectedSubjectId == null) return;

    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('topics')
          .select('id, name')
          .eq('subject_id', _selectedSubjectId!)
          .order('name');
      
      if (mounted) {
        setState(() {
          _topics = List<Map<String, dynamic>>.from(data);
          _selectedTopicIds = [];
        });
      }
    } catch (e) {
      ToastService.showError('Failed to load topics');
    }
  }

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
            decoration: const InputDecoration(
              hintText: 'Enter text content...',
              border: OutlineInputBorder(),
            ),
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
                    _blocks.add(TextBlock(content: controller.text));
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
        final labelController = TextEditingController(text: 'Figure ${_blocks.whereType<FigureBlock>().length + 1}');
        final descController = TextEditingController();
        return AlertDialog(
          title: const Text('Add Figure Block'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'Image URL',
                  hintText: 'https://...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: labelController,
                decoration: const InputDecoration(
                  labelText: 'Figure Label',
                  hintText: 'Figure 1',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (labelController.text.isNotEmpty) {
                  setState(() {
                    _blocks.add(FigureBlock(
                      url: urlController.text.isEmpty ? null : urlController.text,
                      figureLabel: labelController.text,
                      description: descController.text,
                    ));
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
    showDialog(
      context: context,
      builder: (context) {
        final labelController = TextEditingController(text: _getNextPartLabel());
        final contentController = TextEditingController();
        final marksController = TextEditingController(text: '1');
        final answerController = TextEditingController();
        String inputType = 'text_area';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Question Part'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: labelController,
                      decoration: const InputDecoration(
                        labelText: 'Part Label (e.g., a), b), i))',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Question Text',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: marksController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Marks',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: inputType,
                      decoration: const InputDecoration(
                        labelText: 'Input Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'text_area', child: Text('Text Area')),
                        DropdownMenuItem(value: 'fill_in_blanks', child: Text('Fill in Blanks')),
                        DropdownMenuItem(value: 'mcq', child: Text('Multiple Choice')),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          inputType = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: answerController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Model Answer',
                        hintText: 'Enter the correct answer for grading',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (labelController.text.isNotEmpty && contentController.text.isNotEmpty) {
                      setState(() {
                        _blocks.add(QuestionPartBlock(
                          label: labelController.text,
                          content: contentController.text,
                          marks: int.tryParse(marksController.text) ?? 1,
                          inputType: inputType,
                          correctAnswer: answerController.text,
                        ));
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
      },
    );
  }

  String _getNextPartLabel() {
     // Simple helper to guess next part label based on existing blocks
     // Implementation can be smarter, but simple default is fine
     final parts = _blocks.whereType<QuestionPartBlock>().length;
     if (parts == 0) return 'a)';
     if (parts == 1) return 'b)';
     if (parts == 2) return 'c)';
     return '';
  }

  void _removeBlock(int index) {
    setState(() {
      _blocks.removeAt(index);
    });
  }

  void _moveBlockUp(int index) {
    if (index > 0) {
      setState(() {
        final block = _blocks.removeAt(index);
        _blocks.insert(index - 1, block);
      });
    }
  }

  void _moveBlockDown(int index) {
    if (index < _blocks.length - 1) {
      setState(() {
        final block = _blocks.removeAt(index);
        _blocks.insert(index + 1, block);
      });
    }
  }

  Future<void> _submitQuestion() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_blocks.isEmpty) {
      ToastService.showError('Please add at least one block');
      return;
    }

    if (_selectedTopicIds.isEmpty) {
      ToastService.showError('Please select at least one topic');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final supabase = Supabase.instance.client;
      
      // Create a summary content from text blocks
      final contentParts = _blocks
          .whereType<TextBlock>()
          .map((b) => b.content)
          .take(2)
          .join(' ');
      
      final questionData = {
        'type': 'structured',
        'question_number': _questionNumber,
        'content': contentParts.isEmpty ? 'Structured Question $_questionNumber' : contentParts,
        'structure_data': _blocks.map((b) => b.toMap()).toList(),
        'topic_ids': _selectedTopicIds,
        'marks': _totalMarks,
        'official_answer': '', 
        'ai_answer': null,
      };

      await supabase.from('questions').insert(questionData);

      if (mounted) {
        ToastService.showSuccess('Smart question created successfully!');
        setState(() {
          _blocks.clear();
          _questionNumber++;
          _totalMarks = 1;
        });
      }
    } catch (e) {
      ToastService.showError('Failed to create question: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Smart Question'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnDark,
      ),
      body: Form(
        key: _formKey,
        child: Row(
          children: [
            // Left panel - Form
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ... (Subjects/Topics selectors same as before)
                    _buildMetaSelectors(),
                    
                    const SizedBox(height: 24),

                    // Add block buttons
                    const Text(
                      'Add Content Blocks',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _addTextBlock,
                          icon: const Icon(Icons.text_fields),
                          label: const Text('Text'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _addFigureBlock,
                          icon: const Icon(Icons.image),
                          label: const Text('Figure'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _addQuestionPartBlock,
                          icon: const Icon(Icons.quiz),
                          label: const Text('Question Part'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitQuestion,
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Create Question'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Right panel - Preview
            Expanded(
              flex: 3,
              child: Container(
                color: AppColors.background,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: AppColors.surface,
                      child: const Text(
                        'Structure Preview',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _blocks.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                             if (oldIndex < newIndex) {
                               newIndex -= 1;
                             }
                             final item = _blocks.removeAt(oldIndex);
                             _blocks.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          return _buildBlockPreview(index);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaSelectors() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         DropdownButtonFormField<String>(
          value: _selectedSubjectId,
          decoration: const InputDecoration(
            labelText: 'Subject',
            border: OutlineInputBorder(),
          ),
          items: _subjects.map((subject) {
            return DropdownMenuItem<String>(
              value: subject['id']?.toString(),
              child: Text(subject['name']?.toString() ?? ''),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedSubjectId = value;
              _fetchTopics();
            });
          },
        ),
        const SizedBox(height: 16),
        const Text('Topics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _topics.map((topic) {
            final isSelected = _selectedTopicIds.contains(topic['id']);
            return FilterChip(
              label: Text(topic['name']?.toString() ?? ''),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedTopicIds.add(topic['id'].toString());
                  } else {
                    _selectedTopicIds.remove(topic['id'].toString());
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _questionNumber.toString(),
                decoration: const InputDecoration(labelText: 'Question Number'),
                keyboardType: TextInputType.number,
                onChanged: (v) => _questionNumber = int.tryParse(v) ?? 1,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                initialValue: _totalMarks.toString(),
                decoration: const InputDecoration(labelText: 'Total Marks'),
                keyboardType: TextInputType.number,
                 onChanged: (v) => _totalMarks = int.tryParse(v) ?? 1,
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildBlockPreview(int index) {
    final block = _blocks[index];
    
    return Card(
      key: ValueKey(block), // Important for ReorderableListView
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text('${block.type.toUpperCase()} Block'),
        subtitle: _buildBlockContent(block),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _removeBlock(index),
        ),
        leading: const Icon(Icons.drag_handle),
      ),
    );
  }

  Widget _buildBlockContent(ExamContentBlock block) {
    if (block is TextBlock) {
      return Text(block.content, maxLines: 2, overflow: TextOverflow.ellipsis);
    } else if (block is FigureBlock) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Label: ${block.figureLabel}', style: const TextStyle(fontWeight: FontWeight.bold)),
          if (block.url != null) Text('URL: ${block.url}', style: const TextStyle(fontSize: 12)),
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
}
