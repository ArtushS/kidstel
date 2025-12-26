import 'package:flutter/foundation.dart';

import 'tts_service.dart';

/// Stub implementation to prepare DI switching.
///
/// Replace internals with a real TTS plugin (e.g. flutter_tts) when ready.
class FlutterTtsService implements TtsService {
  final ValueNotifier<bool> _speaking = ValueNotifier(false);

  @override
  ValueListenable<bool> get speaking => _speaking;

  @override
  Future<void> speak(
    String text, {
    String? locale,
    String? voice,
    double? rate,
    double? pitch,
  }) async {
    // TODO: integrate real TTS plugin.
    await stop();
    if (text.trim().isEmpty) return;

    debugPrint(
      'FlutterTtsService.speak(locale=$locale, voice=$voice, rate=$rate, pitch=$pitch): ${text.substring(0, text.length.clamp(0, 80))}',
    );
    _speaking.value = true;

    // In stub mode, immediately mark as finished.
    _speaking.value = false;
  }

  @override
  Future<void> stop() async {
    // TODO: stop real TTS.
    _speaking.value = false;
  }

  @override
  void dispose() {
    _speaking.dispose();
  }
}
