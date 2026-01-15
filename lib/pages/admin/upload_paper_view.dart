import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/toast_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';

/// Upload paper view - extracted from the original admin page
class UploadPaperView extends StatefulWidget {
  const UploadPaperView({super.key});

  @override
  State<UploadPaperView> createState() => _UploadPaperViewState();
}

class _UploadPaperViewState extends State<UploadPaperView> {
  bool _isLoadingSubjects = false;
  bool _isSubmitting = false;
  String? _statusMessage;
  int _uploadStep = 0; // 0=idle, 1=uploading, 2=analyzing, 3=extracting, 4=cropping, 5=done

  final _formKey = GlobalKey<FormState>();
  final _yearController = TextEditingController();
  final _variantController = TextEditingController();

  List<Map<String, dynamic>> _subjects = [];
  String? _selectedSubjectId;
  String? _selectedSeason;
  String _paperType = 'subjective'; // 'objective' or 'subjective'
  String _selectedCurriculum = 'SPM'; // Default to SPM

  // Question paper file
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;

  // Mark scheme file (optional)
  String? _markSchemeFileName;
  Uint8List? _markSchemeFileBytes;

  final List<String> _seasons = const ['March', 'June', 'November'];
  final List<String> _curriculums = const ['SPM', 'IGCSE', 'A-Level'];

  @override
  void initState() {
    super.initState();
    _fetchSubjects();
  }

  @override
  void dispose() {
    _yearController.dispose();
    _variantController.dispose();
    super.dispose();
  }

  Future<void> _fetchSubjects() async {
    setState(() {
      _isLoadingSubjects = true;
    });

    try {
      final supabase = Supabase.instance.client;
      // UPDATED: Filter by 'curriculum' column (text) instead of 'curriculum_id'
      final data = await supabase
          .from('subjects')
          .select('id, name, curriculum')
          .eq('curriculum', _selectedCurriculum)
          .order('name');
      final subjects = List<Map<String, dynamic>>.from(data);

      if (mounted) {
        setState(() {
          _subjects = subjects;
          // Reset selected subject when curriculum changes
          _selectedSubjectId = subjects.isNotEmpty ? subjects.first['id']?.toString() : null;
        });
      }
    } catch (e) {
      ToastService.showError('Failed to load subjects: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSubjects = false;
        });
      }
    }
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    if (file.bytes == null) {
      ToastService.showError(
        kIsWeb ? 'Failed to read file data' : 'Failed to read PDF bytes',
      );
      return;
    }

    setState(() {
      _selectedFileName = file.name;
      _selectedFileBytes = file.bytes;
    });
  }

  Future<void> _pickMarkScheme() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    if (file.bytes == null) {
      ToastService.showError('Failed to read mark scheme');
      return;
    }

    setState(() {
      _markSchemeFileName = file.name;
      _markSchemeFileBytes = file.bytes;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedSubjectId == null) {
      ToastService.showError('Please select a subject');
      return;
    }

    if (_selectedSeason == null) {
      ToastService.showError('Please select a season');
      return;
    }

    if (_selectedFileBytes == null) {
      ToastService.showError('Please select a PDF');
      return;
    }

    final year = int.tryParse(_yearController.text.trim());
    final variant = int.tryParse(_variantController.text.trim());
    if (year == null || variant == null) {
      ToastService.showError('Please enter valid numbers');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _uploadStep = 0;
    });

    try {
      await _uploadPaper(
        year: year,
        variant: variant,
        season: _selectedSeason!,
        subjectId: _selectedSubjectId!,
        paperType: _paperType,
        fileBytes: _selectedFileBytes!,
        markSchemeBytes: _markSchemeFileBytes, // Optional
      );

      if (mounted) {
        setState(() {
          _selectedFileName = null;
          _selectedFileBytes = null;
          _markSchemeFileName = null;
          _markSchemeFileBytes = null;
          _selectedSeason = null;
          _yearController.clear();
          _variantController.clear();
        });
      }

      ToastService.showSuccess('Success! Questions Extracted.');
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = null;
        });
      }
      ToastService.showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _uploadPaper({
    required int year,
    required int variant,
    required String season,
    required String subjectId,
    required String paperType,
    required Uint8List fileBytes,
    Uint8List? markSchemeBytes,
  }) async {
    final supabase = Supabase.instance.client;
    const bucketName = 'exam-papers';
    final filePath = 'pdfs/$subjectId/${year}_${season}_$variant.pdf';

    // Step 1: Uploading
    if (mounted) {
      setState(() {
        _uploadStep = 1;
        _statusMessage = 'Uploading question paper...';
      });
    }

    // Upload question paper
    await supabase.storage.from(bucketName).uploadBinary(
          filePath,
          fileBytes,
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: true,
          ),
        );

    final String publicUrl =
        supabase.storage.from(bucketName).getPublicUrl(filePath);

    // Upload mark scheme if provided
    String? markSchemeUrl;
    if (markSchemeBytes != null) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Uploading mark scheme...';
        });
      }

      final markSchemePath = 'pdfs/$subjectId/${year}_${season}_${variant}_ms.pdf';
      await supabase.storage.from(bucketName).uploadBinary(
            markSchemePath,
            markSchemeBytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: true,
            ),
          );
      markSchemeUrl = supabase.storage.from(bucketName).getPublicUrl(markSchemePath);
    }

    final newPaper = await supabase.from('papers').insert({
      'subject_id': subjectId,
      'year': year,
      'season': season,
      'variant': variant,
      'pdf_url': publicUrl,
      'paper_type': paperType,
    }).select().single();

    // Step 2: Analyzing in batches
    if (mounted) {
      setState(() {
        _uploadStep = 2;
        _statusMessage = 'Starting AI analysis...';
      });
    }

    // For Structured papers, we now use the batching logic just like standard papers
    // but pointing to a different edge function.
    await _processPdfInBatches(
      paperId: newPaper['id'],
      pdfUrl: publicUrl,
      paperType: paperType,
      markSchemeUrl: markSchemeUrl,
    );

    if (mounted) {
      setState(() {
        _uploadStep = 5;
        _statusMessage = 'Success! Questions Extracted.';
      });
    }
  }

  Future<void> _processPdfInBatches({
    required String paperId,
    required String pdfUrl,
    required String paperType,
    String? markSchemeUrl,
  }) async {
    const int batchSize = 5; // Changed to 5 for better accuracy
    final supabase = Supabase.instance.client;

    // First batch to get total page count
    if (mounted) {
      setState(() {
        _statusMessage = 'Analyzing pages 1-$batchSize...';
      });
    }

    try {
      final functionName = paperType == 'structured' ? 'process-structured-paper' : 'analyze-paper';

      final firstBatch = await supabase.functions.invoke(
        functionName,
        body: {
          'paperId': paperId,
          'pdfUrl': pdfUrl,
          'paperType': paperType,
          'startPage': 0,
          'endPage': batchSize,
          if (markSchemeUrl != null) 'markSchemeUrl': markSchemeUrl,
        },
      );

      if (firstBatch.data == null || firstBatch.data['success'] != true) {
        throw Exception('First batch failed');
      }

      int totalPages = firstBatch.data['total_pages'] ?? 100; // Default to larger if null to ensure loop runs check
      if (firstBatch.data['total_pages'] != null) {
          debugPrint('✅ Total pages detected: $totalPages');
      }

      // Process remaining batches
      // Start loop from batchSize because 0..batchSize is already done
      for (int start = batchSize; start < totalPages; start += batchSize) {
        final end = (start + batchSize > totalPages) ? totalPages : start + batchSize;

        if (mounted) {
          setState(() {
            _statusMessage = 'Analyzing pages ${start + 1}-$end...';
          });
        }

        print('[Batch] Processing pages ${start + 1} to $end of $totalPages');

        try {
          final functionName = paperType == 'structured' ? 'process-structured-paper' : 'analyze-paper';
          final batchResponse = await supabase.functions.invoke(
            functionName,
            body: {
              'paperId': paperId,
              'pdfUrl': pdfUrl,
              'paperType': paperType,
              'startPage': start,
              'endPage': end,
              if (markSchemeUrl != null) 'markSchemeUrl': markSchemeUrl,
            },
          );

          if (batchResponse.data?['success'] == true) {
            print('[Batch] Success: ${batchResponse.data['count']} questions extracted');
          } else {
             print('[Batch] Warning: ${batchResponse.data}');
          }

          // Rate Limit Throttling for Gemini 2.0 Flash Exp (10 RPM) - Optimized to 2s
          // Relying on retry logic for backpressure if limit is hit
          await Future.delayed(const Duration(seconds: 2));
        } catch (e) {
          print('[Batch] Error processing pages $start-$end: $e');
          // Continue with next batch even if this one failed
        }

        // Small delay between batches
        await Future.delayed(const Duration(milliseconds: 500));
      }

      print('[Complete] All batches processed. Total pages: $totalPages');

      // Process Mark Scheme (Background Task)
      if (markSchemeUrl != null) {
        if (mounted) setState(() => _statusMessage = 'Starting Mark Scheme processing (Background)...');
        print('[Mark Scheme] Starting extraction (Background)...');

        try {
          final msResponse = await supabase.functions.invoke(
            'process-mark-scheme',
            body: {
              'paperId': paperId,
              'markSchemeUrl': markSchemeUrl,
            },
          );

          if (msResponse.data?['success'] == true) {
             print('[Mark Scheme] Background Task Started: ${msResponse.data['message']}');
             if (mounted) setState(() => _statusMessage = 'Mark Scheme processing in background.');
          } else {
             print('[Mark Scheme] Warning: ${msResponse.data}');
          }
        } catch (e) {
          print('[Mark Scheme] Error: $e');
        }
      }
    } catch (e) {
      print('[Error] Batch processing failed: $e');
      rethrow;
    }
  }

  Widget _buildProgressStep(int step, String title, String subtitle) {
    final isComplete = _uploadStep >= step;
    final isCurrent = _uploadStep == step - 1 || (_uploadStep == step && step < 5);

    Color iconColor;
    IconData iconData;

    if (isComplete) {
      iconColor = const Color(0xFF10B981);
      iconData = Icons.check_circle;
    } else if (isCurrent) {
      iconColor = Colors.blue;
      iconData = Icons.radio_button_on;
    } else {
      iconColor = AppColors.textSecondary.withValues(alpha: 0.3);
      iconData = Icons.radio_button_off;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (isCurrent && !isComplete)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(iconColor),
              ),
            )
          else
            Icon(iconData, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isComplete || isCurrent ? AppColors.textPrimary : AppColors.textSecondary,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIcon(int step, String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF37352F) : const Color(0xFFF7F6F3),
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? const Color(0xFF37352F) : const Color(0xFFE9E9E7),
            ),
          ),
          child: Center(
            child: Text(
              step.toString(),
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF787774),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        color: isActive ? const Color(0xFF6366F1) : AppColors.border,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16), // Align with circle center roughly
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE9E9E7)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF37352F).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE9E9E7)),
                          ),
                          child: const Icon(
                            Icons.upload_file,
                            color: Color(0xFF787774),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text(
                                  'Upload Exam Paper',
                                  style: TextStyle(
                                    color: Color(0xFF37352F),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Upload a PDF and AI will extract questions',
                                  style: TextStyle(
                                    color: Color(0xFF787774),
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Visual Stepper
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStepIcon(1, 'Details', _uploadStep >= 0),
                        _buildStepLine(_uploadStep >= 1),
                        _buildStepIcon(2, 'Upload', _uploadStep >= 1),
                         _buildStepLine(_uploadStep >= 2),
                        _buildStepIcon(3, 'Process', _uploadStep >= 2),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Curriculum and Subject Row
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCurriculum,
                            decoration: InputDecoration(
                              labelText: 'Curriculum',
                              labelStyle: const TextStyle(color: Color(0xFF787774), fontSize: 13),
                              filled: true,
                              fillColor: const Color(0xFFF7F6F3),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
                              ),
                            ),
                            items: _curriculums.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Color(0xFF37352F), fontSize: 14)))).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedCurriculum = value);
                                _fetchSubjects();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedSubjectId,
                            decoration: InputDecoration(
                              labelText: 'Subject',
                              labelStyle: const TextStyle(color: Color(0xFF787774), fontSize: 13),
                              filled: true,
                              fillColor: const Color(0xFFF7F6F3),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
                              ),
                            ),
                            items: _subjects.map((s) => DropdownMenuItem(value: s['id']?.toString(), child: Text(s['name'] ?? 'Unknown', style: const TextStyle(color: Color(0xFF37352F), fontSize: 14)))).toList(),
                            onChanged: _isLoadingSubjects ? null : (v) => setState(() => _selectedSubjectId = v),
                            validator: (v) => v == null ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Paper Details Row (Year, Season, Variant)
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _yearController,
                            decoration: InputDecoration(
                              labelText: 'Year',
                              labelStyle: const TextStyle(color: Color(0xFF787774), fontSize: 13),
                              hintText: '2024',
                              filled: true,
                              fillColor: const Color(0xFFF7F6F3),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE9E9E7))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE9E9E7))),
                            ),
                            style: const TextStyle(color: Color(0xFF37352F), fontSize: 14),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (v) => v?.isNotEmpty == true ? null : 'Required',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value: _selectedSeason,
                            decoration: InputDecoration(
                              labelText: 'Season',
                              labelStyle: const TextStyle(color: Color(0xFF787774), fontSize: 13),
                              filled: true,
                              fillColor: const Color(0xFFF7F6F3),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE9E9E7))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE9E9E7))),
                            ),
                            items: _seasons.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(color: Color(0xFF37352F), fontSize: 14)))).toList(),
                            onChanged: (v) => setState(() => _selectedSeason = v),
                            validator: (v) => v == null ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _variantController,
                            decoration: InputDecoration(
                              labelText: 'Variant',
                              labelStyle: const TextStyle(color: Color(0xFF787774), fontSize: 13),
                              hintText: '1',
                              filled: true,
                              fillColor: const Color(0xFFF7F6F3),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE9E9E7))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE9E9E7))),
                            ),
                            style: const TextStyle(color: Color(0xFF37352F), fontSize: 14),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            validator: (v) => v?.isNotEmpty == true ? null : 'Required',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Paper Type Selection
                     Container(
                      padding: const EdgeInsets.all(4),
                       decoration: BoxDecoration(
                        color: const Color(0xFFF7F6F3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE9E9E7)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _paperType = 'objective'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _paperType == 'objective' ? Colors.blue.withValues(alpha: 0.2) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _paperType == 'objective' ? Colors.blue : Colors.transparent),
                                ),
                                alignment: Alignment.center,
                                child: Text('Objective', style: TextStyle(color: _paperType == 'objective' ? Colors.blue : const Color(0xFF787774), fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _paperType = 'subjective'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _paperType == 'subjective' ? Colors.purple.withValues(alpha: 0.2) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _paperType == 'subjective' ? Colors.purple : Colors.transparent),
                                ),
                                alignment: Alignment.center,
                                child: Text('Subjective', style: TextStyle(color: _paperType == 'subjective' ? Colors.purple : const Color(0xFF787774), fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _paperType = 'structured'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: _paperType == 'structured' ? Colors.orange.withValues(alpha: 0.2) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _paperType == 'structured' ? Colors.orange : Colors.transparent),
                                ),
                                alignment: Alignment.center,
                                child: Text('Structured', style: TextStyle(color: _paperType == 'structured' ? Colors.orange : const Color(0xFF787774), fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Enhanced Drop Zone
                    InkWell(
                      onTap: _isSubmitting ? null : _pickPdf,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F6F3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedFileName != null ? const Color(0xFF37352F) : const Color(0xFFE9E9E7),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_selectedFileName != null) ...[
                               const Icon(Icons.check_circle, size: 48, color: Colors.green),
                               const SizedBox(height: 16),
                               Text(
                                _selectedFileName!,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                             ] else ...[
                              Icon(Icons.cloud_upload_outlined, size: 48, color: AppColors.textPrimary.withOpacity(0.5)),
                              const SizedBox(height: 16),
                              Text(
                                'Click to upload PDF',
                                style: TextStyle(
                                  color: AppColors.textPrimary.withOpacity(0.7),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Supports PDF files up to 10MB',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Mark scheme file picker (optional)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _markSchemeFileName != null
                              ? Colors.green.withValues(alpha: 0.5)
                              : AppColors.border,
                          width: _markSchemeFileName != null ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                _markSchemeFileName != null
                                    ? Icons.check_circle
                                    : Icons.description_outlined,
                                color: _markSchemeFileName != null
                                    ? const Color(0xFF10B981)
                                    : AppColors.textSecondary,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _markSchemeFileName ?? 'Mark Scheme (Optional)',
                                      style: TextStyle(
                                        color: _markSchemeFileName != null
                                            ? AppColors.textPrimary
                                            : AppColors.textPrimary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (_markSchemeFileName == null)
                                      Text(
                                        'AI will extract answers & generate solutions',
                                        style: TextStyle(
                                          color: AppColors.textPrimary.withValues(alpha: 0.4),
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              OutlinedButton(
                                onPressed: _isSubmitting ? null : _pickMarkScheme,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.green,
                                  side: BorderSide(
                                    color: Colors.green.withValues(alpha: 0.5),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                                child: Text(_markSchemeFileName != null
                                    ? 'Change'
                                    : 'Select'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    // Submit button
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor:
                              const Color(0xFF6366F1).withValues(alpha: 0.5),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.upload, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Upload & Analyze',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (_isSubmitting || _statusMessage?.contains('Success') == true) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.border,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Upload Progress',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildProgressStep(1, 'Uploading Paper', 'Sending PDF to server'),
                            _buildProgressStep(2, 'Analyzing', 'AI extracting questions'),
                            _buildProgressStep(3, 'Processing Answers', 'Matching with mark scheme'),
                            _buildProgressStep(4, 'Cropping Figures', 'Extracting images'),
                            _buildProgressStep(5, 'Complete', 'All done!'),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
