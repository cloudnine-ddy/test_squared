import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:confetti/confetti.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/wired/wired_widgets.dart';
import '../auth/providers/auth_provider.dart';

/// Checkout page for manual payment processing via QR and receipt upload
class CheckoutPage extends ConsumerStatefulWidget {
  final String planType; // 'pro' or 'elite'
  
  const CheckoutPage({
    super.key,
    required this.planType,
  });

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  // Color constants
  static const Color _primaryColor = Color(0xFF2D3E50);
  static const Color _backgroundColor = Color(0xFFFDFBF7);

  PlatformFile? _selectedFile;
  bool _isUploading = false;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  TextStyle _patrickHand({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'PatrickHand',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? _primaryColor,
      height: height,
    );
  }

  Future<void> _pickReceipt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true, // Important: allows getting bytes on all platforms
    );

    if (result != null) {
      setState(() {
        _selectedFile = result.files.first;
      });
    }
  }

  Future<void> _submitPayment() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please upload a receipt first!', style: _patrickHand(color: Colors.white))),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      final user = supabase.auth.currentUser;
      
      if (user == null) throw Exception('User not authenticated');

      String? publicUrl;
      
      // 1. Upload file to storage
      // Use uploadBinary for all platforms to avoid dart:io dependency which breaks web
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.${_selectedFile!.extension}';
      final path = 'receipts/$fileName';

      if (_selectedFile!.bytes != null) {
        await supabase.storage.from('receipts').uploadBinary(path, _selectedFile!.bytes!);
      } else {
        throw Exception('File data not available. Please try again.');
      }

      publicUrl = supabase.storage.from('receipts').getPublicUrl(path);

      // 2. Update profile with premium status and receipt URL
      // We set premium_until to 30 days from now
      final premiumUntil = DateTime.now().add(const Duration(days: 30));

      await supabase.from('profiles').update({
        'subscription_tier': 'premium',
        'premium_until': premiumUntil.toIso8601String(),
        'payment_receipt_url': publicUrl,
      }).eq('id', user.id);

      // 3. Success Feedback
      _confettiController.play();
      
      // Refresh user data
      ref.invalidate(currentUserProvider);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: _backgroundColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Payment Received!', style: _patrickHand(fontSize: 24, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Your receipt has been uploaded. We will verify it shortly. You now have full access to Premium features!',
                  textAlign: TextAlign.center,
                  style: _patrickHand(fontSize: 18),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/dashboard');
                },
                child: Text('Go to Dashboard', style: _patrickHand(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}', style: _patrickHand(color: Colors.white))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPro = widget.planType.toLowerCase() == 'pro';
    final String planName = isPro ? 'Pro' : 'Elite';
    final String price = isPro ? 'RM 10' : 'RM 29';
    final Color accentColor = isPro ? AppColors.primary : AppColors.accent;
    
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _primaryColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Checkout',
          style: _patrickHand(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _primaryColor,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Plan Summary Card
                    WiredCard(
                      backgroundColor: Colors.white,
                      borderColor: accentColor,
                      borderWidth: 2,
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Icon(isPro ? Icons.star : Icons.diamond, color: accentColor, size: 40),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Test² $planName',
                                  style: _patrickHand(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '$price / month',
                                  style: _patrickHand(fontSize: 16, color: accentColor, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // QR Code Section
                    Text(
                      'Step 1: Scan & Pay',
                      style: _patrickHand(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    WiredCard(
                      backgroundColor: Colors.white,
                      borderColor: _primaryColor.withValues(alpha: 0.2),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.qr_code_2, size: 80, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('QR Code Placeholder', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Scan the QR code above to pay $price via DuitNow/Touch\'n Go',
                            textAlign: TextAlign.center,
                            style: _patrickHand(fontSize: 14, color: _primaryColor.withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Upload Section
                    Text(
                      'Step 2: Upload Receipt',
                      style: _patrickHand(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _pickReceipt,
                      child: WiredCard(
                        backgroundColor: _selectedFile != null ? Colors.green.withValues(alpha: 0.05) : Colors.white,
                        borderColor: _selectedFile != null ? Colors.green : _primaryColor.withValues(alpha: 0.2),
                        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                        child: Column(
                          children: [
                            Icon(
                              _selectedFile != null ? Icons.file_present : Icons.cloud_upload_outlined,
                              size: 48,
                              color: _selectedFile != null ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedFile != null ? _selectedFile!.name : 'Click to select receipt (Image or PDF)',
                              textAlign: TextAlign.center,
                              style: _patrickHand(
                                fontSize: 16,
                                color: _selectedFile != null ? Colors.green : _primaryColor.withValues(alpha: 0.7),
                                fontWeight: _selectedFile != null ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            if (_selectedFile != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                                style: _patrickHand(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Action Buttons
                    if (_isUploading)
                      const CircularProgressIndicator(color: AppColors.primary)
                    else
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: WiredButton(
                              onPressed: _submitPayment,
                              backgroundColor: AppColors.primary,
                              filled: true,
                              borderColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                'Submit & Activate',
                                style: _patrickHand(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => context.pop(),
                            child: Text(
                              'Cancel',
                              style: _patrickHand(color: Colors.grey, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
          
          // Confetti!
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple
              ],
            ),
          ),
        ],
      ),
    );
  }
}
