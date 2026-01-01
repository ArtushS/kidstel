import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../models/story_choice.dart';
import '../models/story_chapter.dart';
import '../models/story_session.dart';
import '../models/story_state.dart';
import '../repositories/story_repository.dart';
import '../services/story_service.dart';
import '../services/image_generation_service.dart';
import '../services/models/generate_story_response.dart';
import '../../story_reader/story_reader_args.dart';

class StoryController extends ChangeNotifier {
  final StoryService _storyService;
  final StoryRepository _repository;
  final ImageGenerationService _imageGeneration;

  final bool _interactiveStoriesEnabled;
  final bool _autoIllustrationsEnabled;
  final bool _devIllustrationFallbackEnabled;

  /// DEV/TEST fallback illustration bytes.
  ///
  /// Must be visually non-empty so the reader UI never shows an "empty" box
  /// when illustration generation fails.
  static Future<Uint8List> _buildDevFallbackBytes() async {
    // Keep a 16:9 image so it fits our illustration panel without distortion.
    const w = 640;
    const h = 360;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final rect = ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());

    // Background.
    final bg = ui.Paint()..color = const ui.Color(0xFFECEFF1);
    canvas.drawRect(rect, bg);

    // Border.
    final border = ui.Paint()
      ..color = const ui.Color(0xFF90A4AE)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 12;
    canvas.drawRect(rect.deflate(6), border);

    // Diagonal cross.
    final cross = ui.Paint()
      ..color = const ui.Color(0xFFB0BEC5)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 10;
    canvas.drawLine(const ui.Offset(40, 40), ui.Offset(w - 40, h - 40), cross);
    canvas.drawLine(ui.Offset(w - 40, 40), ui.Offset(40, h - 40), cross);

    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List() ?? Uint8List(0);
  }

  static const int _maxInteractiveSteps = 3;

  StoryState _state = StoryState.empty();
  StoryState get state => _state;

  // Snapshot settings for continue (also persisted in state.session).
  StorySession _session = StorySession.empty();

  Map<String, dynamic>? _lastRequestBody;

  bool _readingStarted = false;
  Timer? _illustrationDebounce;

  StoryController({
    required StoryService storyService,
    required StoryRepository repository,
    required ImageGenerationService imageGenerationService,
    bool interactiveStoriesEnabled = true,
    bool autoIllustrationsEnabled = true,
    bool devIllustrationFallbackEnabled = kDebugMode,
  }) : _storyService = storyService,
       _repository = repository,
       _imageGeneration = imageGenerationService,
       _interactiveStoriesEnabled = interactiveStoriesEnabled,
       _autoIllustrationsEnabled = autoIllustrationsEnabled,
       _devIllustrationFallbackEnabled = devIllustrationFallbackEnabled;

  void _imgLog(
    String message, {
    Map<String, Object?>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;
    final b = StringBuffer('[IMG] $message');
    if (data != null && data.isNotEmpty) {
      for (final e in data.entries) {
        b.write(' ${e.key}=${e.value}');
      }
    }
    debugPrint(b.toString());
    if (error != null) {
      debugPrint('[IMG] error=$error');
    }
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }

  DateTime _now() => DateTime.now().toUtc();

  String _ensureStoryId(String id) {
    final trimmed = id.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return 'local_${_now().microsecondsSinceEpoch}';
  }

  String _genericErrorMessage() => 'Something went wrong. Please try again.';

  String _placeholderTitle() => 'New story';

  bool _isLocalId(String id) => id.trim().startsWith('local_');

  Future<void> saveToLibrary() async {
    // Save best-effort, regardless of finished/unfinished. This supports:
    // - immediate appearance in My Stories
    // - persisting illustrations without a separate "final save" step
    final storyId = _ensureStoryId(_state.storyId);
    final toSave = _state.copyWith(
      storyId: storyId,
      isLoading: false,
      clearError: true,
      lastUpdated: _now(),
    );
    await _repository.upsert(toSave);
  }

  int _stepsUsedFor(List<StoryChapter> chapters) {
    // Steps are the number of interactive continuations after the first chapter.
    return chapters.length <= 1 ? 0 : chapters.length - 1;
  }

  bool _canStillInteractFor(List<StoryChapter> chapters) {
    if (!_session.interactiveEnabled) return false;
    return _stepsUsedFor(chapters) < _maxInteractiveSteps;
  }

  Map<String, dynamic> _buildGenerateBody() {
    final body = <String, dynamic>{
      'action': 'generate',
      'ageGroup': _session.ageGroup,
      'storyLang': _session.storyLang,
      'storyLength': _session.storyLength,
      'creativityLevel': _session.creativityLevel,
      'image': {'enabled': _session.imageEnabled},
      'selection': {
        'hero': _session.hero,
        'location': _session.location,
        // Backend expects selection.style; we store only StoryType in session.
        'style': _session.storyType,
      },
    };

    final idea = _session.idea?.trim();
    if (idea != null && idea.isNotEmpty) {
      body['idea'] = idea;
    }

    return body;
  }

  /// Starts a brand-new story using the current session settings.
  ///
  /// This keeps the user on the StoryReader page.
  Future<void> createNewStoryFromSession() async {
    if (_session.storyLang.trim().isEmpty) {
      _state = _state.copyWith(error: _genericErrorMessage());
      notifyListeners();
      return;
    }

    _readingStarted = false;
    _illustrationDebounce?.cancel();

    final localId = _ensureStoryId('');
    _state = StoryState.empty().copyWith(
      storyId: localId,
      title: _placeholderTitle(),
      locale: _session.storyLang,
      session: _session,
      isLoading: true,
      clearError: true,
      lastUpdated: _now(),
    );
    notifyListeners();

    // Make the new story visible in "My Stories" immediately.
    unawaited(saveToLibrary());

    final body = _buildGenerateBody();
    _lastRequestBody = Map<String, dynamic>.from(body);

    await _runRequest(
      requestBody: body,
      onSuccess: (resp) => _applyAgentResponse(resp, replace: true),
      errorPrefix: null,
    );
  }

  void markReadingStarted() {
    if (_readingStarted) return;
    _readingStarted = true;
    _scheduleIllustrationIfNeeded();
  }

  void _scheduleIllustrationIfNeeded() {
    if (!_autoIllustrationsEnabled) return;
    if (!_session.imageEnabled) return;
    if (_state.chapters.isEmpty) return;

    // Debounce so we don't spam if user scrolls rapidly.
    _illustrationDebounce?.cancel();
    _illustrationDebounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(generateIllustration());
    });
  }

  Future<void> startStory({StoryReaderArgs? args}) async {
    // If we already have chapters and startStory is called again, do nothing.
    if (_state.chapters.isNotEmpty) return;

    if (args == null) {
      _state = _state.copyWith(error: _genericErrorMessage());
      notifyListeners();
      return;
    }

    if (args.restoreStoryId != null && args.restoreStoryId!.trim().isNotEmpty) {
      await restoreStory(args.restoreStoryId!);
      return;
    }

    _session = StorySession(
      ageGroup: args.ageGroup,
      storyLang: args.storyLang,
      storyLength: args.storyLength,
      creativityLevel: args.creativityLevel,
      imageEnabled: args.imageEnabled && _autoIllustrationsEnabled,
      interactiveEnabled: _interactiveStoriesEnabled,
      hero: args.hero,
      location: args.location,
      storyType: args.storyType,
      idea: null,
    );

    final localId = _ensureStoryId('');

    // Update locale/session right away (even before first chapter arrives).
    _state = _state.copyWith(
      storyId: _state.storyId.trim().isEmpty ? localId : _state.storyId,
      title: _state.title.trim().isEmpty ? _placeholderTitle() : _state.title,
      locale: _session.storyLang,
      session: _session,
      lastUpdated: _now(),
    );
    notifyListeners();

    // Ensure it appears in "My Stories" as soon as the user enters the reader.
    unawaited(saveToLibrary());

    final initial = args.initialResponse;
    if (initial != null) {
      _applyAgentResponse(initial, replace: true);
      return;
    }

    // Fallback: generate inside reader.
    final body = _buildGenerateBody();

    _lastRequestBody = Map<String, dynamic>.from(body);

    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    await _runRequest(
      requestBody: body,
      onSuccess: (resp) => _applyAgentResponse(resp, replace: true),
      errorPrefix: null,
    );
  }

  Future<void> continueStory(StoryChoice choice) async {
    if (_state.isLoading) return;

    if (!_session.interactiveEnabled) {
      // Non-interactive mode: story is considered finished and has no choices.
      _state = _state.copyWith(
        isFinished: true,
        currentChoices: const <StoryChoice>[],
        lastUpdated: _now(),
      );
      notifyListeners();
      return;
    }

    if (_stepsUsedFor(_state.chapters) >= _maxInteractiveSteps) {
      _state = _state.copyWith(
        isFinished: true,
        currentChoices: const <StoryChoice>[],
        lastUpdated: _now(),
      );
      notifyListeners();
      return;
    }

    final currentStoryId = _state.storyId;
    final lastChapter = _state.chapters.isNotEmpty
        ? _state.chapters.last
        : null;

    if (currentStoryId.isEmpty || lastChapter == null) {
      _state = _state.copyWith(error: _genericErrorMessage());
      notifyListeners();
      return;
    }

    final body = <String, dynamic>{
      'action': 'continue',
      'storyId': currentStoryId,
      'chapterIndex': lastChapter.chapterIndex,
      'ageGroup': _session.ageGroup,
      'storyLang': _session.storyLang,
      'storyLength': _session.storyLength,
      'creativityLevel': _session.creativityLevel,
      'image': {'enabled': _session.imageEnabled},
      'selection': {
        'hero': _session.hero,
        'location': _session.location,
        // Backend expects selection.style; we store only StoryType in session.
        'style': _session.storyType,
      },
      'choice': {'id': choice.id, 'payload': choice.payload},
    };

    _lastRequestBody = Map<String, dynamic>.from(body);

    _state = _state.copyWith(
      isLoading: true,
      clearError: true,
      lastChoiceId: choice.id,
    );
    notifyListeners();

    await _runRequest(
      requestBody: body,
      onSuccess: (resp) => _appendAgentResponse(resp),
      errorPrefix: null,
    );
  }

  Future<void> retryLast() async {
    final body = _lastRequestBody;
    if (body == null) return;

    if (_state.isLoading) return;
    _state = _state.copyWith(isLoading: true, clearError: true);
    notifyListeners();

    final action = body['action']?.toString();

    await _runRequest(
      requestBody: body,
      onSuccess: (resp) {
        if (action == 'generate') {
          _applyAgentResponse(resp, replace: true);
        } else {
          _appendAgentResponse(resp);
        }
      },
      errorPrefix: null,
    );
  }

  Future<void> _runRequest({
    required Map<String, dynamic> requestBody,
    required void Function(GenerateStoryResponse resp) onSuccess,
    required String? errorPrefix,
  }) async {
    try {
      final json = await _storyService.callAgentJson(requestBody);
      final resp = GenerateStoryResponse.fromJson(json);
      onSuccess(resp);
    } catch (e) {
      debugPrint('Story request failed: $e');
      _state = _state.copyWith(
        isLoading: false,
        error: errorPrefix == null
            ? _genericErrorMessage()
            : '$errorPrefix${_genericErrorMessage()}',
        lastUpdated: _now(),
      );
      notifyListeners();
    }
  }

  void _applyAgentResponse(
    GenerateStoryResponse resp, {
    required bool replace,
  }) {
    final prevId = _state.storyId;
    final chapter = StoryChapter.fromAgentResponse(resp);

    final nextChapters = replace
        ? <StoryChapter>[chapter]
        : [..._state.chapters, chapter];

    final storyId = _ensureStoryId(resp.storyId);
    final title = resp.title.trim().isNotEmpty ? resp.title : _state.title;

    final interactiveAllowed = _canStillInteractFor(nextChapters);
    final choices = interactiveAllowed
        ? chapter.choices
        : const <StoryChoice>[];

    final isFinished =
        !interactiveAllowed || (choices.isEmpty && nextChapters.isNotEmpty);

    _state = _state.copyWith(
      storyId: storyId,
      title: title,
      chapters: nextChapters,
      currentChoices: choices,
      isFinished: isFinished,
      illustrationStatus: IllustrationStatus.idle,
      illustrationUrl: null,
      illustrationPrompt: null,
      isLoading: false,
      clearError: true,
      lastUpdated: _now(),
      locale: _session.storyLang,
      session: _session,
    );

    notifyListeners();

    // If we initially saved with a local_* id, remove it once we have a server id.
    if (_isLocalId(prevId) && prevId.trim().isNotEmpty && prevId != storyId) {
      unawaited(_repository.delete(prevId));
    }

    unawaited(saveToLibrary());

    if (_readingStarted) {
      _scheduleIllustrationIfNeeded();
    }
  }

  void _appendAgentResponse(GenerateStoryResponse resp) {
    final prevId = _state.storyId;
    final chapter = StoryChapter.fromAgentResponse(resp);

    final chapters = [..._state.chapters];

    // Avoid duplicates if backend returns same chapterIndex.
    if (chapters.isNotEmpty &&
        chapters.last.chapterIndex == chapter.chapterIndex) {
      chapters[chapters.length - 1] = chapter;
    } else {
      chapters.add(chapter);
    }

    final storyId = _ensureStoryId(resp.storyId);
    final title = resp.title.trim().isNotEmpty ? resp.title : _state.title;

    final interactiveAllowed = _canStillInteractFor(chapters);
    final choices = interactiveAllowed
        ? chapter.choices
        : const <StoryChoice>[];
    final isFinished =
        !interactiveAllowed || (choices.isEmpty && chapters.isNotEmpty);

    _state = _state.copyWith(
      storyId: storyId,
      title: title,
      chapters: chapters,
      currentChoices: choices,
      isFinished: isFinished,
      illustrationStatus: IllustrationStatus.idle,
      illustrationUrl: null,
      illustrationPrompt: null,
      isLoading: false,
      clearError: true,
      lastUpdated: _now(),
      locale: _session.storyLang,
      session: _session,
    );

    notifyListeners();

    if (_isLocalId(prevId) && prevId.trim().isNotEmpty && prevId != storyId) {
      unawaited(_repository.delete(prevId));
    }

    unawaited(saveToLibrary());

    if (_readingStarted) {
      _scheduleIllustrationIfNeeded();
    }
  }

  /// Generates (or re-generates) the illustration for the current chapter.
  ///
  /// This should typically be triggered automatically after reading begins.
  Future<void> generateIllustration({bool force = false}) async {
    if (!_autoIllustrationsEnabled) {
      _imgLog('skip: auto illustrations disabled');
      return;
    }
    if (!_session.imageEnabled) {
      _imgLog('skip: session image disabled');
      return;
    }
    if (_state.chapters.isEmpty) {
      _imgLog('skip: no chapters');
      return;
    }

    final status = _state.illustrationStatus;
    if (!force &&
        (status == IllustrationStatus.loading ||
            status == IllustrationStatus.ready)) {
      _imgLog(
        'skip: already in progress/ready',
        data: {'force': force, 'status': status.name},
      );
      return;
    }

    final last = _state.chapters.last;
    final existingUrl = last.imageUrl;
    final prompt = _buildIllustrationPrompt(last);

    _imgLog(
      'start',
      data: {
        'force': force,
        'storyId': _state.storyId,
        'chapterIndex': last.chapterIndex,
        'promptLen': prompt.length,
        'hasExistingUrl': (existingUrl ?? '').trim().isNotEmpty,
      },
    );

    if (!force && existingUrl != null && existingUrl.trim().isNotEmpty) {
      final v = existingUrl.trim();
      _state = _state.copyWith(
        illustrationStatus: IllustrationStatus.ready,
        illustrationUrl: v,
        illustrationPrompt: prompt,
        lastUpdated: _now(),
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      illustrationStatus: IllustrationStatus.loading,
      illustrationUrl: null,
      illustrationBytes: null,
      illustrationPrompt: prompt,
      lastUpdated: _now(),
    );
    notifyListeners();

    try {
      final result = await _imageGeneration.generateImage(story: _state);

      final url = (result.url ?? '').trim();
      final bytes = result.bytes;

      _imgLog(
        'success',
        data: {
          'chapterIndex': last.chapterIndex,
          'hasUrl': url.isNotEmpty,
          'bytesLen': bytes?.length ?? 0,
          if (url.isNotEmpty)
            'urlPrefix': url.substring(0, url.length.clamp(0, 32)),
        },
      );

      if (bytes != null && bytes.isNotEmpty) {
        _state = _state.copyWith(
          illustrationStatus: IllustrationStatus.ready,
          illustrationUrl: null,
          illustrationBytes: bytes,
          lastUpdated: _now(),
        );
        notifyListeners();
        return;
      }

      if (url.isEmpty) {
        throw FormatException(
          'Image generation returned neither url nor bytes',
        );
      }

      // Persist URL into the last chapter (for restore).
      final chapters = [..._state.chapters];
      final lastChapter = chapters.last;
      chapters[chapters.length - 1] = StoryChapter(
        chapterIndex: lastChapter.chapterIndex,
        title: lastChapter.title,
        text: lastChapter.text,
        progress: lastChapter.progress,
        imageUrl: url,
        choices: lastChapter.choices,
      );

      _state = _state.copyWith(
        chapters: chapters,
        illustrationStatus: IllustrationStatus.ready,
        illustrationUrl: url,
        illustrationBytes: null,
        lastUpdated: _now(),
      );
      notifyListeners();

      // Persist updated story with the illustration.
      unawaited(saveToLibrary());
    } catch (e, st) {
      _imgLog(
        'failure',
        data: {
          'storyId': _state.storyId,
          'chapterIndex': last.chapterIndex,
          'fallbackEnabled': _devIllustrationFallbackEnabled,
        },
        error: e,
        stackTrace: st,
      );

      if (_devIllustrationFallbackEnabled) {
        final bytes = await _buildDevFallbackBytes();

        // Keep status=error so the user still has a visible "Try again" action,
        // while we still show a deterministic image in DEV/TEST.
        _state = _state.copyWith(
          illustrationStatus: IllustrationStatus.error,
          illustrationUrl: null,
          illustrationBytes: bytes,
          lastUpdated: _now(),
        );
        notifyListeners();

        unawaited(saveToLibrary());
        return;
      }

      _state = _state.copyWith(
        illustrationStatus: IllustrationStatus.error,
        illustrationUrl: null,
        illustrationBytes: null,
        lastUpdated: _now(),
      );
      notifyListeners();
    }
  }

  // Backward-compatible name used by older UI code.
  Future<void> generateImage() => generateIllustration(force: true);

  String _buildIllustrationPrompt(StoryChapter chapter) {
    final title = chapter.title.trim();
    final text = chapter.text.trim();
    final snippet = text.length > 200 ? '${text.substring(0, 200)}…' : text;
    return [
      if (title.isNotEmpty) title,
      if (snippet.isNotEmpty) snippet,
    ].join('\n');
  }

  Future<void> saveStory({required bool manual}) async {
    if (_state.chapters.isEmpty) return;

    // Manual save only for finished stories; autosave only for unfinished.
    if (manual && !_state.isFinished) return;
    if (!manual && _state.isFinished) return;

    final storyId = _ensureStoryId(_state.storyId);
    final toSave = _state.copyWith(
      storyId: storyId,
      isLoading: false,
      clearError: true,
      lastUpdated: _now(),
    );

    await _repository.upsert(toSave);
  }

  Future<void> autoSaveIfNeeded() => saveStory(manual: false);

  Future<void> restoreStory(String storyId) async {
    final loaded = await _repository.getById(storyId);
    if (loaded == null) {
      _state = _state.copyWith(error: 'Story not found.');
      notifyListeners();
      return;
    }

    _session = loaded.session;
    _state = loaded.copyWith(isLoading: false, clearError: true);

    notifyListeners();
  }

  @override
  void dispose() {
    _illustrationDebounce?.cancel();
    // Best-effort autosave for unfinished stories.
    if (!_state.isFinished && _state.chapters.isNotEmpty) {
      unawaited(saveStory(manual: false));
    }
    super.dispose();
  }
}
