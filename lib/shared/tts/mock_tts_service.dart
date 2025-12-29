import 'dart:async';

import 'package:flutter/foundation.dart';

import 'tts_service.dart';

class MockTtsService implements TtsService {
  final ValueNotifier<bool> _speaking = ValueNotifier(false);

  void Function(TtsProgress progress)? _progressListener;

  @override
  ValueListenable<bool> get speakingListenable => _speaking;

  @override
  ValueListenable<bool> get speaking => speakingListenable;

  @override
  void setProgressListener(void Function(TtsProgress progress)? listener) {
    _progressListener = listener;
  }

  Timer? _timer;

  @override
  Future<void> init() async {
    // No-op.
  }

  @override
  Future<List<Map<String, String>>> listVoices({String? locale}) async {
    return const [];
  }

  @override
  Future<void> speak({
    required String text,
    String? locale,
    Map<String, String>? voice,
    double? volume,
    double? rate,
    double? pitch,
  }) async {
    // Simulate cancellation of previous speech.
    await stop();

    if (text.trim().isEmpty) return;

    _speaking.value = true;

    // Progress is intentionally not simulated here.
    // Real engines may or may not provide it; controller logic must handle both.
    _progressListener?.call(
      TtsProgress(text: text, start: 0, end: 0, word: null),
    );

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
  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    _progressListener = null;
    _speaking.dispose();
  }
}
