import 'package:flutter/foundation.dart';

import '../../../shared/tts/tts_service.dart';
import '../models/story_chapter.dart';

class NarrationController extends ChangeNotifier {
  final TtsService _tts;

  NarrationController({required TtsService tts}) : _tts = tts {
    _tts.speaking.addListener(_onSpeakingChanged);
  }

  bool get isSpeaking => _tts.speaking.value;

  Future<void> speakChapter(
    StoryChapter chapter, {
    String? locale,
    String? voice,
    double? rate,
    double? pitch,
  }) async {
    // Decide behavior when already speaking: restart from new chapter.
    await _tts.stop();
    await _tts.speak(
      chapter.text,
      locale: locale,
      voice: voice,
      rate: rate,
      pitch: pitch,
    );
  }

  Future<void> speakText(
    String text, {
    String? locale,
    String? voice,
    double? rate,
    double? pitch,
  }) async {
    await _tts.stop();
    await _tts.speak(
      text,
      locale: locale,
      voice: voice,
      rate: rate,
      pitch: pitch,
    );
  }

  Future<void> stop() => _tts.stop();

  void _onSpeakingChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _tts.speaking.removeListener(_onSpeakingChanged);
    super.dispose();
  }
}
