import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PdfHelper {
  /// Returns a proxied URL for Web to bypass CORS, or the original URL for native platforms.
  static String getProxiedUrl(String originalUrl) {
    if (kIsWeb) {
      final client = Supabase.instance.client;
      // Construct the Edge Function URL
      // Standard format: https://[project].supabase.co/functions/v1/proxy-pdf
      // Hardcoded project URL as SDK doesn't expose it
      const projectUrl = 'https://cixwhueqvtetnkgazyiy.supabase.co';
      final functionUrl = '$projectUrl/functions/v1/proxy-pdf';

      return '$functionUrl?url=${Uri.encodeComponent(originalUrl)}';
    }
    return originalUrl;
  }
}
