import 'package:flutter/foundation.dart';

import '../../../shared/tts/tts_service.dart';
import '../models/story_chapter.dart';

class NarrationController extends ChangeNotifier {
  final TtsService _tts;

  NarrationController({required TtsService tts}) : _tts = tts {
    _tts.speaking.addListener(_onSpeakingChanged);
    _tts.setProgressListener(_onProgress);
  }

  String? _fullText;

  // Last known global offset into [_fullText].
  int _offset = 0;

  // When we re-speak from an offset, the engine progress callback offsets start at 0.
  // We keep this to translate progress offsets back into the original full text.
  int _baseOffset = 0;

  bool _paused = false;
  bool _hasProgress = false;

  bool _wasSpeaking = false;
  bool _suppressAutoReset = false;

  List<String>? _segments;
  List<int>? _segmentStartOffsets;
  int _segmentIndex = 0;

  bool get isSpeaking => _tts.speaking.value;

  bool get isPaused => _paused;

  List<String> get segments => _segments ?? const [];

  int get segmentIndex => _segmentIndex;

  Future<void> speakChapter(
    StoryChapter chapter, {
    String? locale,
    Map<String, String>? voice,
    double? volume,
    double? rate,
    double? pitch,
  }) async {
    _ensureSessionText(chapter.text);
    _segmentIndex = 0;
    await seekToOffset(
      0,
      locale: locale,
      voice: voice,
      volume: volume,
      rate: rate,
      pitch: pitch,
    );
  }

  Future<void> speakText(
    String text, {
    String? locale,
    Map<String, String>? voice,
    double? volume,
    double? rate,
    double? pitch,
  }) async {
    _ensureSessionText(text);
    _segmentIndex = 0;
    await seekToOffset(
      0,
      locale: locale,
      voice: voice,
      volume: volume,
      rate: rate,
      pitch: pitch,
    );
  }

  Future<void> pauseNarration() async {
    if (!isSpeaking) return;
    _paused = true;
    notifyListeners();
    // Cross-platform safe pause: stop, but keep offsets/session state.
    await _tts.stop();
  }

  Future<void> resumeNarration({
    String? locale,
    Map<String, String>? voice,
    double? volume,
    double? rate,
    double? pitch,
  }) async {
    final text = _fullText;
    if (text == null || text.trim().isEmpty) return;

    final len = text.length;
    if (len == 0) return;
    if (_offset >= len) {
      // Nothing left to read.
      _resetSession();
      notifyListeners();
      return;
    }

    int resumeOffset = _offset.clamp(0, len);

    // Fallback: if the platform never provided progress callbacks, resume from the
    // currently selected segment start (if any), otherwise from the beginning.
    if (!_hasProgress && resumeOffset == 0) {
      final starts = _segmentStartOffsets;
      if (starts != null && starts.isNotEmpty) {
        final i = _segmentIndex.clamp(0, starts.length - 1);
        resumeOffset = starts[i].clamp(0, len);
      }
    }

    final startAt = _snapToWordBoundary(text, resumeOffset);
    await _restartFromOffset(
      startAt,
      locale: locale,
      voice: voice,
      volume: volume,
      rate: rate,
      pitch: pitch,
    );
  }

  Future<void> stopNarration() async {
    _resetSession();
    notifyListeners();
    await _tts.stop();
  }

  // Back-compat for existing call sites.
  Future<void> stop() => stopNarration();

  Future<void> seekToOffset(
    int offset, {
    String? locale,
    Map<String, String>? voice,
    double? volume,
    double? rate,
    double? pitch,
  }) async {
    final text = _fullText;
    if (text == null || text.trim().isEmpty) return;

    final clamped = offset.clamp(0, text.length);
    final startAt = _snapToWordBoundary(text, clamped);

    await _restartFromOffset(
      startAt,
      locale: locale,
      voice: voice,
      volume: volume,
      rate: rate,
      pitch: pitch,
    );
  }

  void prepareChapter(StoryChapter chapter) {
    _ensureSessionText(chapter.text);
    _ensureSegments();
  }

  Future<void> startFromSegment(
    StoryChapter chapter,
    int index, {
    String? locale,
    Map<String, String>? voice,
    double? volume,
    double? rate,
    double? pitch,
  }) async {
    _ensureSessionText(chapter.text);
    _ensureSegments();

    final starts = _segmentStartOffsets ?? const <int>[];
    if (starts.isEmpty) {
      await seekToOffset(
        0,
        locale: locale,
        voice: voice,
        volume: volume,
        rate: rate,
        pitch: pitch,
      );
      return;
    }

    final i = index.clamp(0, starts.length - 1);
    _segmentIndex = i;
    await seekToOffset(
      starts[i],
      locale: locale,
      voice: voice,
      volume: volume,
      rate: rate,
      pitch: pitch,
    );
  }

  void _onProgress(TtsProgress p) {
    // Some platforms provide progress offsets relative to the last `speak(text: ...)`.
    // Translate to global offsets into [_fullText] using [_baseOffset].
    final full = _fullText;
    if (full == null || full.isEmpty) return;

    _hasProgress = true;

    final globalStart = (_baseOffset + p.start).clamp(0, full.length);
    _offset = globalStart;

    // If we're receiving progress, we are effectively not paused.
    if (_paused) _paused = false;

    notifyListeners();
  }

  void _ensureSessionText(String text) {
    if (_fullText == text) {
      // Keep offsets/paused state.
      return;
    }

    _fullText = text;
    _offset = 0;
    _baseOffset = 0;
    _paused = false;
    _hasProgress = false;
    _segments = null;
    _segmentStartOffsets = null;
    _segmentIndex = 0;
  }

  void _resetSession() {
    _fullText = null;
    _offset = 0;
    _baseOffset = 0;
    _paused = false;
    _hasProgress = false;
    _segments = null;
    _segmentStartOffsets = null;
    _segmentIndex = 0;
    _suppressAutoReset = false;
  }

  Future<void> _restartFromOffset(
    int startAt, {
    String? locale,
    Map<String, String>? voice,
    double? volume,
    double? rate,
    double? pitch,
  }) async {
    final full = _fullText;
    if (full == null || full.isEmpty) return;

    final s = startAt.clamp(0, full.length);
    if (s >= full.length) {
      _resetSession();
      notifyListeners();
      return;
    }

    // Stop current speech but do not treat it as "completion".
    _suppressAutoReset = true;
    await _tts.stop();

    _paused = false;
    _baseOffset = s;
    _offset = s;

    notifyListeners();

    final remaining = full.substring(s);
    await _tts.speak(
      text: remaining,
      locale: locale,
      voice: voice,
      volume: volume,
      rate: rate,
      pitch: pitch,
    );
  }

  void _ensureSegments() {
    final full = _fullText;
    if (full == null || full.isEmpty) {
      _segments = null;
      _segmentStartOffsets = null;
      return;
    }
    if (_segments != null && _segmentStartOffsets != null) return;

    final segs = _buildSegments(full);
    final starts = _buildSegmentStartOffsets(full, segs);
    _segments = segs;
    _segmentStartOffsets = starts;
  }

  List<String> _buildSegments(String text) {
    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .where((s) => s.trim().isNotEmpty)
        .toList(growable: false);
    if (paragraphs.length >= 2) return paragraphs;

    final sentences = text
        .split(RegExp(r'(?<=[\.!\?…])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList(growable: false);
    if (sentences.length >= 2) return sentences;

    return [text];
  }

  List<int> _buildSegmentStartOffsets(String text, List<String> segments) {
    final starts = <int>[];
    var cursor = 0;
    for (final seg in segments) {
      final idx = text.indexOf(seg, cursor);
      if (idx < 0) {
        starts.add(cursor.clamp(0, text.length));
        cursor = (cursor + seg.length).clamp(0, text.length);
      } else {
        starts.add(idx);
        cursor = (idx + seg.length).clamp(0, text.length);
      }
    }
    return starts;
  }

  int _snapToWordBoundary(String text, int offset) {
    final o = offset.clamp(0, text.length);
    if (o <= 0 || o >= text.length) return o;

    bool isBoundaryChar(String ch) {
      if (ch.trim().isEmpty) return true;
      const punctuation = ",.;:!?…—–-()[]{}\"'«»\n\r\t";
      return punctuation.contains(ch);
    }

    var i = o;
    while (i > 0) {
      final ch = text[i - 1];
      if (isBoundaryChar(ch)) break;
      i--;
    }
    return i;
  }

  void _onSpeakingChanged() {
    final now = _tts.speaking.value;

    if (_wasSpeaking && !now) {
      if (_suppressAutoReset) {
        _suppressAutoReset = false;
      } else if (!_paused) {
        // Natural completion (or stop not initiated as pause/seek). Reset session.
        _resetSession();
      }
    }

    _wasSpeaking = now;
    notifyListeners();
  }

  @override
  void dispose() {
    _tts.speaking.removeListener(_onSpeakingChanged);
    _tts.setProgressListener(null);
    super.dispose();
  }
}
