import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/toast_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_colors.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  bool _isCheckingAccess = true;
  bool _isLoadingSubjects = false;
  bool _isSubmitting = false;
  String? _statusMessage;

  final _formKey = GlobalKey<FormState>();
  final _yearController = TextEditingController();
  final _variantController = TextEditingController();

  List<Map<String, dynamic>> _subjects = [];
  String? _selectedSubjectId;
  String? _selectedSeason;

  String? _selectedFileName;
  Uint8List? _selectedFileBytes;

  final List<String> _seasons = const ['March', 'June', 'November'];

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  @override
  void dispose() {
    _yearController.dispose();
    _variantController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAccess() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      _redirectNonAdmin();
      return;
    }

    try {
      final profile = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      final role = (profile?['role'] as String?)?.toLowerCase();

      if (role != 'admin') {
        _redirectNonAdmin();
        return;
      }

      if (mounted) {
        setState(() {
          _isCheckingAccess = false;
        });
      }
      await _fetchSubjects();
    } catch (_) {
      _redirectNonAdmin();
    }
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

  void _redirectNonAdmin() {
    if (!mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ToastService.showError('Access Denied');
      context.go('/dashboard');
    });
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
    });

    try {
      await _uploadPaper(
        year: year,
        variant: variant,
        season: _selectedSeason!,
        subjectId: _selectedSubjectId!,
        fileBytes: _selectedFileBytes!,
      );

      if (mounted) {
        setState(() {
          _selectedFileName = null;
          _selectedFileBytes = null;
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
      ToastService.showError('Error');
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
  }) async {
    final supabase = Supabase.instance.client;
    const bucketName = 'exam-papers';
    final filePath = 'pdfs/$subjectId/${year}_${season}_${variant}.pdf';

    if (mounted) {
      setState(() {
        _statusMessage = 'Uploading...';
      });
    }

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

    final newPaper = await supabase.from('papers').insert({
      'subject_id': subjectId,
      'year': year,
      'season': season,
      'variant': variant,
      'pdf_url': publicUrl,
    }).select().single();

    if (mounted) {
      setState(() {
        _statusMessage = 'Analyzing with AI...';
      });
    }

    await supabase.functions.invoke(
      'analyze-paper',
      body: {
        'paperId': newPaper['id'],
        'pdfUrl': publicUrl,
      },
    );

    if (mounted) {
      setState(() {
        _statusMessage = 'Success! Questions Extracted.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Portal'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnDark,
      ),
      body: _isCheckingAccess
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Card(
                    color: AppColors.surface,
                    elevation: 4,
                    shadowColor: AppColors.shadow,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Upload Exam Paper',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 20),
                            DropdownButtonFormField<String>(
                              value: _selectedSubjectId,
                              decoration: InputDecoration(
                                labelText: 'Subject',
                                labelStyle: TextStyle(color: AppColors.textSecondary),
                                filled: true,
                                fillColor: AppColors.background,
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
                                        subject['name']?.toString() ??
                                            'Unknown',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
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
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _yearController,
                              decoration: InputDecoration(
                                labelText: 'Year',
                                labelStyle: TextStyle(color: AppColors.textSecondary),
                                filled: true,
                                fillColor: AppColors.background,
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
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _selectedSeason,
                              decoration: InputDecoration(
                                labelText: 'Season',
                                labelStyle: TextStyle(color: AppColors.textSecondary),
                                filled: true,
                                fillColor: AppColors.background,
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
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
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
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _variantController,
                              decoration: InputDecoration(
                                labelText: 'Variant',
                                labelStyle: TextStyle(color: AppColors.textSecondary),
                                filled: true,
                                fillColor: AppColors.background,
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
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _isSubmitting ? null : _pickPdf,
                              icon: const Icon(Icons.attach_file),
                              label: const Text('Select PDF'),
                            ),
                            if (_selectedFileName != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _selectedFileName!,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _submit,
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Text('Upload'),
                              ),
                            ),
                            if (_statusMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _statusMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
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
