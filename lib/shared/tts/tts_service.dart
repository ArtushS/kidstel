import 'package:flutter/foundation.dart';

abstract class TtsService {
  /// Initialize the engine (best-effort). Safe to call multiple times.
  Future<void> init();

  /// Emits whether TTS is currently speaking.
  ValueListenable<bool> get speakingListenable;

  /// Back-compat alias used by older call sites.
  ValueListenable<bool> get speaking => speakingListenable;

  /// Speak the given [text] with optional parameters.
  Future<void> speak({
    required String text,
    String? locale,
    Map<String, String>? voice, // {name, locale}
    double? volume, // 0..1
    double? rate, // speech rate
    double? pitch, // intensity/pitch
  });

  /// Stop any ongoing speech.
  Future<void> stop();

  /// List available system voices.
  ///
  /// Returns a normalized list of maps: {"name": ..., "locale": ...}.
  Future<List<Map<String, String>>> listVoices({String? locale});

  /// Release resources (best-effort).
  Future<void> dispose();
}
