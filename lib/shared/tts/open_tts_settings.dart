import 'package:flutter/foundation.dart';

// Android-only; safe no-op elsewhere.
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

/// Best-effort opening of the OS Text-to-Speech settings screen.
///
/// Returns true if we *attempted* to open it successfully.
Future<bool> openTtsSettings() async {
  if (kIsWeb) return false;
  if (defaultTargetPlatform != TargetPlatform.android) return false;

  try {
    const intent = AndroidIntent(
      action: 'com.android.settings.TTS_SETTINGS',
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    await intent.launch();
    return true;
  } catch (e) {
    if (kDebugMode) {
      debugPrint('openTtsSettings failed: $e');
    }
    return false;
  }
}
