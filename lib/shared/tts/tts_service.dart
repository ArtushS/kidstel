import 'package:flutter/foundation.dart';

abstract class TtsService {
  /// Emits whether TTS is currently speaking.
  ValueListenable<bool> get speaking;

  Future<void> speak(
    String text, {
    String? locale,
    String? voice,
    double? rate,
    double? pitch,
  });

  Future<void> stop();

  void dispose();
}
