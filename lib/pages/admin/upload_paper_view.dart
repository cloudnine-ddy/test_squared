import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/toast_service.dart';
import '../../core/theme/app_theme.dart';

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

  // Question paper file
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;
  
  // Mark scheme file (optional)
  String? _markSchemeFileName;
  Uint8List? _markSchemeFileBytes;

  final List<String> _seasons = const ['March', 'June', 'November'];

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
      final data = await supabase
          .from('subjects')
          .select('id, name')
          .order('name');
      final subjects = List<Map<String, dynamic>>.from(data);

      if (mounted) {
        setState(() {
          _subjects = subjects;
          _selectedSubjectId ??=
              subjects.isNotEmpty ? subjects.first['id']?.toString() : null;
        });
      }
    } catch (_) {
      ToastService.showError('Failed to load subjects');
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
    }).select().single();

    // Step 2: Analyzing
    if (mounted) {
      setState(() {
        _uploadStep = 2;
        _statusMessage = markSchemeUrl != null 
            ? 'Analyzing paper + extracting answers...'
            : 'Analyzing with AI...';
      });
    }

    await supabase.functions.invoke(
      'analyze-paper',
      body: {
        'paperId': newPaper['id'],
        'pdfUrl': publicUrl,
        if (markSchemeUrl != null) 'markSchemeUrl': markSchemeUrl,
      },
    );

    if (mounted) {
      setState(() {
        _uploadStep = 5;
        _statusMessage = 'Success! Questions Extracted.';
      });
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
      iconColor = Colors.grey;
      iconData = Icons.radio_button_off;
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
                    color: isComplete || isCurrent ? Colors.white : Colors.white54,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            color: AppTheme.surfaceDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
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
                            color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.upload_file,
                            color: Color(0xFF818CF8),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Upload Exam Paper',
                              style: TextStyle(
                                color: AppTheme.textWhite,
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Upload a PDF and AI will extract questions',
                              style: TextStyle(
                                color: AppTheme.textGray,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Subject dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedSubjectId,
                      decoration: InputDecoration(
                        labelText: 'Subject',
                        filled: true,
                        fillColor: const Color(0xFF1F2937),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: _subjects
                          .map(
                            (subject) => DropdownMenuItem<String>(
                              value: subject['id']?.toString(),
                              child: Text(
                                subject['name']?.toString() ?? 'Unknown',
                                style: const TextStyle(
                                  color: AppTheme.textWhite,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: _isLoadingSubjects
                          ? null
                          : (value) {
                              setState(() {
                                _selectedSubjectId = value;
                              });
                            },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a subject';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    // Year input
                    TextFormField(
                      controller: _yearController,
                      decoration: InputDecoration(
                        labelText: 'Year',
                        hintText: 'e.g. 2024',
                        filled: true,
                        fillColor: const Color(0xFF1F2937),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(color: AppTheme.textWhite),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a year';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid year';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    // Season dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedSeason,
                      decoration: InputDecoration(
                        labelText: 'Season',
                        filled: true,
                        fillColor: const Color(0xFF1F2937),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: _seasons
                          .map(
                            (season) => DropdownMenuItem<String>(
                              value: season,
                              child: Text(
                                season,
                                style: const TextStyle(
                                  color: AppTheme.textWhite,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSeason = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a season';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    // Variant input
                    TextFormField(
                      controller: _variantController,
                      decoration: InputDecoration(
                        labelText: 'Variant',
                        hintText: 'e.g. 1, 2, 3',
                        filled: true,
                        fillColor: const Color(0xFF1F2937),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(color: AppTheme.textWhite),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a variant';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid variant';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    // File picker
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2937),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedFileName != null
                              ? const Color(0xFF6366F1).withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.1),
                          width: _selectedFileName != null ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _selectedFileName != null
                                ? Icons.check_circle
                                : Icons.cloud_upload_outlined,
                            color: _selectedFileName != null
                                ? const Color(0xFF10B981)
                                : Colors.white.withValues(alpha: 0.5),
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          if (_selectedFileName != null) ...[
                            Text(
                              _selectedFileName!,
                              style: const TextStyle(
                                color: AppTheme.textWhite,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                          ],
                          OutlinedButton.icon(
                            onPressed: _isSubmitting ? null : _pickPdf,
                            icon: const Icon(Icons.attach_file),
                            label: Text(_selectedFileName != null
                                ? 'Change PDF'
                                : 'Select PDF'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF818CF8),
                              side: const BorderSide(color: Color(0xFF6366F1)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Mark scheme file picker (optional)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2937),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _markSchemeFileName != null
                              ? Colors.green.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.1),
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
                                    : Colors.white.withValues(alpha: 0.5),
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
                                            ? AppTheme.textWhite
                                            : Colors.white.withValues(alpha: 0.7),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (_markSchemeFileName == null)
                                      Text(
                                        'AI will extract answers & generate solutions',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.4),
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
                          color: const Color(0xFF1F2937),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Upload Progress',
                              style: TextStyle(
                                color: Colors.white,
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
    );
  }
}
