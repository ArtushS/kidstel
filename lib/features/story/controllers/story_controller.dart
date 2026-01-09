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
  bool _autoIllustrationsEnabled;
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

  // Illustration polling (single-flight per storyId/chapterIndex).
  Timer? _illustrationPollTimer;
  String? _illustrationPollKey;
  DateTime? _illustrationPollStartedAt;
  int _illustrationPollAttempt = 0;
  bool _illustrationAttemptInFlight = false;
  bool _illustrationUserInitiated = false;

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

  void setAutoIllustrationsEnabled(bool enabled) {
    if (_autoIllustrationsEnabled == enabled) return;
    _autoIllustrationsEnabled = enabled;

    _imgLog('auto illustrations setting changed', data: {'enabled': enabled});

    if (!enabled) {
      _cancelIllustrationPolling(reason: 'settings_off');
      _state = _state.copyWith(
        illustrationStatus: IllustrationStatus.idle,
        illustrationUrl: null,
        illustrationBytes: null,
        lastUpdated: _now(),
      );
      notifyListeners();
      return;
    }

    _maybeStartIllustrationPolling(reason: 'settings_on');
  }

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

  String _urlKind(String? url) {
    final s = (url ?? '').trim();
    if (s.isEmpty) return 'none';
    final lower = s.toLowerCase();
    if (lower.startsWith('https://')) return 'https';
    if (lower.startsWith('http://')) return 'http';
    if (lower.startsWith('gs://')) return 'gs';
    if (lower.startsWith('storage://')) return 'storage';
    if (lower.contains('://')) return 'other';
    return 'path';
  }

  void _agentImageMetaLog({
    required String stage,
    GenerateStoryResponse? resp,
    StoryChapter? chapter,
  }) {
    if (!kDebugMode) return;

    if (resp != null) {
      final img = resp.image;
      final url = img?.url;
      final base64 = img?.base64;
      debugPrint(
        '[StoryController] $stage respHasImage=${img != null} '
        'hasUrl=${(url ?? '').trim().isNotEmpty} urlKind=${_urlKind(url)} '
        'hasBase64=${(base64 ?? '').trim().isNotEmpty} base64Len=${(base64 ?? '').trim().length}',
      );
      return;
    }

    if (chapter != null) {
      final url = chapter.imageUrl;
      final base64 = chapter.imageBase64;
      debugPrint(
        '[StoryController] $stage chapterHasUrl=${(url ?? '').trim().isNotEmpty} '
        'urlKind=${_urlKind(url)} chapterHasBase64=${(base64 ?? '').trim().isNotEmpty} '
        'base64Len=${(base64 ?? '').trim().length}',
      );
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

    final family = _session.family;
    if (family != null) {
      body['familyEnabled'] = family.enabled;
      body['family'] = family.toJson();
    }

    final idea = _session.idea?.trim();
    if (idea != null && idea.isNotEmpty) {
      body['idea'] = idea;
    }

    return body;
  }

  bool _shouldSkipGenerateRequest(Map<String, dynamic> body) {
    final storyId = (body['storyId'] ?? '').toString().trim();
    final idea = (body['idea'] ?? '').toString().trim();
    final prompt = (body['prompt'] ?? '').toString().trim();
    // Client contract: do not send empty generate requests.
    return storyId.isEmpty && idea.isEmpty && prompt.isEmpty;
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

    final body = _buildGenerateBody();
    if (_shouldSkipGenerateRequest(body)) {
      debugPrint('[StoryController] Skip generate: no input');
      return;
    }

    _readingStarted = false;
    _cancelIllustrationPolling(reason: 'new_story');

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
  }

  String _pollKeyFor(String storyId, int chapterIndex) =>
      '${storyId.trim()}:$chapterIndex';

  Duration _pollDelayForAttempt(int attempt) {
    // Backoff: 2s, 3s, 5s, 8s, 13s, 21s, then cap at 30s.
    const seq = <int>[2, 3, 5, 8, 13, 21];
    if (attempt <= 0) return const Duration(seconds: 2);
    if (attempt < seq.length) return Duration(seconds: seq[attempt]);
    return const Duration(seconds: 30);
  }

  void _cancelIllustrationPolling({required String reason}) {
    final prevKey = _illustrationPollKey;
    final prevAttempt = _illustrationPollAttempt;
    _illustrationPollTimer?.cancel();
    _illustrationPollTimer = null;
    _illustrationPollKey = null;
    _illustrationPollStartedAt = null;
    _illustrationPollAttempt = 0;
    _illustrationAttemptInFlight = false;
    _illustrationUserInitiated = false;
    _imgLog(
      'cancelled',
      data: {
        'reason': reason,
        if (prevKey != null) 'key': prevKey,
        'attempt': prevAttempt,
      },
    );
  }

  void _maybeStartIllustrationPolling({required String reason}) {
    // IMPORTANT: Illustration generation must be user-initiated.
    // We keep this hook for compatibility with old call sites, but it no-ops.
    _imgLog(
      'auto illustration suppressed',
      data: {
        'reason': reason,
        'storyId': _state.storyId,
        'hasChapters': _state.chapters.isNotEmpty,
      },
    );
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

    _cancelIllustrationPolling(reason: 'start_story');

    _session = StorySession(
      ageGroup: args.ageGroup,
      storyLang: args.storyLang,
      storyLength: args.storyLength,
      creativityLevel: args.creativityLevel,
      // Per-story intent. Global toggle is tracked separately.
      imageEnabled: args.imageEnabled,
      interactiveEnabled: _interactiveStoriesEnabled,
      hero: args.hero,
      location: args.location,
      locationImage: args.locationImage,
      storyType: args.storyType,
      storyTypeImage: args.storyTypeImage,
      idea: null,
      family: args.family,
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

    if (_shouldSkipGenerateRequest(body)) {
      debugPrint('[StoryController] Skip generate: no input');
      return;
    }

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
      'choice': {
        'id': choice.id,
        'label': choice.label,
        'payload': choice.payload,
      },
    };

    final family = _session.family;
    if (family != null) {
      body['familyEnabled'] = family.enabled;
      body['family'] = family.toJson();
    }

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
      _agentImageMetaLog(stage: 'after-parse', resp: resp);
      onSuccess(resp);
    } catch (e) {
      debugPrint('Story request failed: $e');

      final userMsg =
          (e is StoryServiceDailyLimitException ||
              e is StoryServiceCooldownException)
          ? e.toString()
          : null;

      _state = _state.copyWith(
        isLoading: false,
        error:
            userMsg ??
            (errorPrefix == null
                ? _genericErrorMessage()
                : '$errorPrefix${_genericErrorMessage()}'),
        lastUpdated: _now(),
      );
      notifyListeners();
    }
  }

  void _applyAgentResponse(
    GenerateStoryResponse resp, {
    required bool replace,
  }) {
    _cancelIllustrationPolling(reason: 'chapter_changed');
    final prevId = _state.storyId;
    final chapter = StoryChapter.fromAgentResponse(resp);
    _agentImageMetaLog(stage: 'after-chapter-map', chapter: chapter);

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

    _maybeStartIllustrationPolling(reason: 'new_chapter');
  }

  void _appendAgentResponse(GenerateStoryResponse resp) {
    _cancelIllustrationPolling(reason: 'chapter_changed');
    final prevId = _state.storyId;
    final chapter = StoryChapter.fromAgentResponse(resp);
    _agentImageMetaLog(stage: 'after-chapter-map', chapter: chapter);

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

    _maybeStartIllustrationPolling(reason: 'continued_chapter');
  }

  /// Generates (or re-generates) the illustration for the current chapter.
  ///
  /// This should typically be triggered automatically after reading begins.
  Future<void> generateIllustration({bool force = false}) async {
    final userInitiated = force;
    if (!userInitiated && !_illustrationUserInitiated) {
      _imgLog('skip: illustration not user-initiated');
      return;
    }

    // If user explicitly asked for an image, allow it regardless of the
    // global toggle and remember the per-story intent.
    if (userInitiated && !_session.imageEnabled) {
      _session = StorySession(
        ageGroup: _session.ageGroup,
        storyLang: _session.storyLang,
        storyLength: _session.storyLength,
        creativityLevel: _session.creativityLevel,
        imageEnabled: true,
        interactiveEnabled: _session.interactiveEnabled,
        hero: _session.hero,
        location: _session.location,
        locationImage: _session.locationImage,
        storyType: _session.storyType,
        storyTypeImage: _session.storyTypeImage,
        idea: _session.idea,
        family: _session.family,
      );
      _state = _state.copyWith(session: _session, lastUpdated: _now());
      notifyListeners();
    }

    if (userInitiated) {
      _illustrationUserInitiated = true;
    }
    if (_state.chapters.isEmpty) {
      _imgLog('skip: no chapters');
      return;
    }

    final last = _state.chapters.last;
    final storyId = _state.storyId.trim();
    final pollKey = _pollKeyFor(storyId, last.chapterIndex);

    if (force) {
      _cancelIllustrationPolling(reason: 'force_retry');
      _illustrationUserInitiated = true;
    }

    if (_illustrationAttemptInFlight) {
      _imgLog(
        'skip: attempt already in flight',
        data: {
          'storyId': storyId,
          'chapterIndex': last.chapterIndex,
          'force': force,
        },
      );
      return;
    }

    // Reset polling state if target changed.
    if (_illustrationPollKey != null && _illustrationPollKey != pollKey) {
      _cancelIllustrationPolling(reason: 'target_changed');
    }

    // If we're already ready and not forcing, do nothing.
    if (!force && _state.illustrationStatus == IllustrationStatus.ready) {
      return;
    }

    _illustrationPollKey ??= pollKey;
    _illustrationPollStartedAt ??= _now();

    final existingUrl = (last.imageUrl ?? '').trim();
    final prompt = _buildIllustrationPrompt(last);

    _imgLog(
      'poll start',
      data: {
        'force': force,
        'storyId': storyId,
        'chapterIndex': last.chapterIndex,
        'promptLen': prompt.length,
        'hasExistingUrl': existingUrl.isNotEmpty,
        'attempt': _illustrationPollAttempt,
      },
    );

    // If a URL is already persisted on the chapter, treat it as ready.
    if (!force && existingUrl.isNotEmpty) {
      _cancelIllustrationPolling(reason: 'existing_url');
      _state = _state.copyWith(
        illustrationStatus: IllustrationStatus.ready,
        illustrationUrl: existingUrl,
        illustrationPrompt: prompt,
        lastUpdated: _now(),
      );
      notifyListeners();
      return;
    }

    // Always show loading during polling.
    _state = _state.copyWith(
      illustrationStatus: IllustrationStatus.loading,
      illustrationUrl: null,
      illustrationBytes: null,
      illustrationPrompt: prompt,
      lastUpdated: _now(),
    );
    notifyListeners();

    const maxElapsed = Duration(seconds: 90);
    const maxAttempts = 12;

    try {
      _illustrationAttemptInFlight = true;
      final result = await _imageGeneration.generateImage(story: _state);
      _illustrationAttemptInFlight = false;

      final url = (result.url ?? '').trim();
      final bytes = result.bytes;

      if (bytes != null && bytes.isNotEmpty) {
        _imgLog(
          'success -> stop',
          data: {
            'chapterIndex': last.chapterIndex,
            'hasUrl': false,
            'bytesLen': bytes.length,
          },
        );

        _cancelIllustrationPolling(reason: 'success');
        _state = _state.copyWith(
          illustrationStatus: IllustrationStatus.ready,
          illustrationUrl: null,
          illustrationBytes: bytes,
          lastUpdated: _now(),
        );
        notifyListeners();
        return;
      }

      if (url.isNotEmpty) {
        _imgLog(
          'success -> stop',
          data: {
            'chapterIndex': last.chapterIndex,
            'hasUrl': true,
            'bytesLen': 0,
            'urlPrefix': url.substring(0, url.length.clamp(0, 32)),
          },
        );

        _cancelIllustrationPolling(reason: 'success');

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
        unawaited(saveToLibrary());
        return;
      }

      // Empty result: keep loading and poll again.
      _imgLog(
        'empty result -> schedule next',
        data: {
          'storyId': storyId,
          'chapterIndex': last.chapterIndex,
          'attempt': _illustrationPollAttempt,
        },
      );

      final startedAt = _illustrationPollStartedAt ?? _now();
      final elapsed = _now().difference(startedAt);
      if (elapsed >= maxElapsed || _illustrationPollAttempt >= maxAttempts) {
        _imgLog(
          'polling timeout',
          data: {
            'storyId': storyId,
            'chapterIndex': last.chapterIndex,
            'attempt': _illustrationPollAttempt,
            'elapsedMs': elapsed.inMilliseconds,
          },
        );
        _cancelIllustrationPolling(reason: 'timeout');
        _state = _state.copyWith(
          illustrationStatus: IllustrationStatus.error,
          illustrationUrl: null,
          illustrationBytes: null,
          lastUpdated: _now(),
        );
        notifyListeners();
        return;
      }

      final delay = _pollDelayForAttempt(_illustrationPollAttempt);
      _illustrationPollAttempt += 1;
      _imgLog(
        'poll scheduled',
        data: {
          'storyId': storyId,
          'chapterIndex': last.chapterIndex,
          'attempt': _illustrationPollAttempt,
          'delayMs': delay.inMilliseconds,
        },
      );

      _illustrationPollTimer?.cancel();
      _illustrationPollTimer = Timer(delay, () {
        if (!_illustrationUserInitiated) return;
        // Only continue if we are still on the same chapter.
        if (_state.chapters.isEmpty) return;
        final curLast = _state.chapters.last;
        final curKey = _pollKeyFor(_state.storyId, curLast.chapterIndex);
        if (curKey != pollKey) return;
        unawaited(generateIllustration(force: false));
      });
    } catch (e, st) {
      _illustrationAttemptInFlight = false;
      _imgLog(
        'failure',
        data: {
          'storyId': storyId,
          'chapterIndex': last.chapterIndex,
          'attempt': _illustrationPollAttempt,
        },
        error: e,
        stackTrace: st,
      );

      final startedAt = _illustrationPollStartedAt ?? _now();
      final elapsed = _now().difference(startedAt);
      if (elapsed < maxElapsed && _illustrationPollAttempt < maxAttempts) {
        final delay = _pollDelayForAttempt(_illustrationPollAttempt);
        _illustrationPollAttempt += 1;
        _imgLog(
          'poll scheduled after failure',
          data: {
            'storyId': storyId,
            'chapterIndex': last.chapterIndex,
            'attempt': _illustrationPollAttempt,
            'delayMs': delay.inMilliseconds,
          },
        );
        _illustrationPollTimer?.cancel();
        _illustrationPollTimer = Timer(delay, () {
          if (!_illustrationUserInitiated) return;
          unawaited(generateIllustration(force: false));
        });
        return;
      }

      _cancelIllustrationPolling(reason: 'final_failure');

      // Final failure: keep retry UX; optional dev placeholder.
      Uint8List? bytes;
      try {
        if (_devIllustrationFallbackEnabled) {
          bytes = await _buildDevFallbackBytes();
        }
      } catch (_) {
        bytes = null;
      }

      _state = _state.copyWith(
        illustrationStatus: IllustrationStatus.error,
        illustrationUrl: null,
        illustrationBytes: bytes,
        lastUpdated: _now(),
      );
      notifyListeners();
      unawaited(saveToLibrary());
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
    _cancelIllustrationPolling(reason: 'dispose');
    // Best-effort autosave for unfinished stories.
    if (!_state.isFinished && _state.chapters.isNotEmpty) {
      unawaited(saveStory(manual: false));
    }
    super.dispose();
  }
}
