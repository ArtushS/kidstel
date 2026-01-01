import 'package:firebase_storage/firebase_storage.dart';

/// Centralized helpers for Firebase Storage URLs used in UI.
///
/// IMPORTANT:
/// - UI widgets must render only HTTPS URLs with Image.network.
/// - If the source is a gs:// URL, we resolve it once and cache in-memory.
class StorageUrls {
  StorageUrls._();

  static const String _placeholderGsUrl =
      'gs://kids-tell-d0ks8m.firebasestorage.app/cms_uploads/placeholder.png';

  static String? _cachedPlaceholderHttps;
  static Future<String>? _inflightPlaceholder;

  /// Returns the HTTPS download URL for the app placeholder image.
  ///
  /// This call is cached in memory to avoid repeated getDownloadURL() calls.
  static Future<String> getPlaceholderDownloadUrl() {
    final cached = _cachedPlaceholderHttps;
    if (cached != null && cached.trim().isNotEmpty) {
      return Future.value(cached);
    }

    // Deduplicate concurrent callers.
    final inflight = _inflightPlaceholder;
    if (inflight != null) return inflight;

    _inflightPlaceholder = FirebaseStorage.instance
        .refFromURL(_placeholderGsUrl)
        .getDownloadURL()
        .then((url) {
          _cachedPlaceholderHttps = url;
          return url;
        })
        .whenComplete(() {
          _inflightPlaceholder = null;
        });

    return _inflightPlaceholder!;
  }
}
