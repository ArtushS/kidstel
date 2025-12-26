import 'dart:async';

import 'package:flutter/foundation.dart';

import 'tts_service.dart';

class MockTtsService implements TtsService {
  final ValueNotifier<bool> _speaking = ValueNotifier(false);

  @override
  ValueListenable<bool> get speaking => _speaking;

  Timer? _timer;

  @override
  Future<void> speak(
    String text, {
    String? locale,
    String? voice,
    double? rate,
    double? pitch,
  }) async {
    // Simulate cancellation of previous speech.
    await stop();

    if (text.trim().isEmpty) return;

    _speaking.value = true;

    // Simulate duration proportional to text length, capped.
    final ms = (text.length * 25).clamp(600, 8000);
    _timer = Timer(Duration(milliseconds: ms), () {
      _speaking.value = false;
    });
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _speaking.value = false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _speaking.dispose();
  }
}
