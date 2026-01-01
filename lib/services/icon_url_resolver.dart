import 'package:firebase_storage/firebase_storage.dart';

/// Ensures we only pass HTTPS URLs to Image.network.
///
/// If Firestore still contains gs:// URLs, we convert them at runtime.
class IconUrlResolver {
  IconUrlResolver._();

  static bool _isHttps(String s) => s.startsWith('https://');
  static bool _isGs(String s) => s.startsWith('gs://');

  /// Returns an HTTPS downloadURL, or null if it cannot be resolved.
  static Future<String?> resolveToHttps(String raw) async {
    final v = raw.trim();
    if (v.isEmpty) return null;
    if (_isHttps(v)) return v;

    try {
      final storage = FirebaseStorage.instance;
      if (_isGs(v)) {
        return await storage
            .refFromURL(v)
            .getDownloadURL()
            .timeout(const Duration(seconds: 8));
      }

      // Accept plain storage paths defensively.
      final url = await storage
          .ref(v)
          .getDownloadURL()
          .timeout(const Duration(seconds: 8));
      return url;
    } catch (_) {
      return null;
    }
  }
}
