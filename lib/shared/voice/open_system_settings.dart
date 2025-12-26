import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Best-effort opening of system settings.
///
/// Notes:
/// - The app cannot enable/install STT language packs.
/// - On Android, `app-settings:` typically opens the app details screen.
/// - Some OEMs may not support this; caller should show a manual fallback.
Future<bool> openAppSettings() async {
  try {
    final uri = Uri.parse('app-settings:');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (kDebugMode) {
      debugPrint('openAppSettings -> $ok');
    }
    return ok;
  } catch (e) {
    if (kDebugMode) {
      debugPrint('openAppSettings failed: $e');
    }
    return false;
  }
}
