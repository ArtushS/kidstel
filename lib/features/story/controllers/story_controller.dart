import 'dart:async';

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
  }) : _storyService = storyService,
       _repository = repository,
       _imageGeneration = imageGenerationService,
       _interactiveStoriesEnabled = interactiveStoriesEnabled,
       _autoIllustrationsEnabled = autoIllustrationsEnabled;

  DateTime _now() => DateTime.now().toUtc();

  String _ensureStoryId(String id) {
    final trimmed = id.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return 'local_${_now().microsecondsSinceEpoch}';
  }

  String _genericErrorMessage() => 'Something went wrong. Please try again.';

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
        'style': _session.style,
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

    _state = StoryState.empty().copyWith(
      locale: _session.storyLang,
      session: _session,
      isLoading: true,
      clearError: true,
      lastUpdated: _now(),
    );
    notifyListeners();

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
      style: args.style,
      idea: null,
    );

    // Update locale/session right away (even before first chapter arrives).
    _state = _state.copyWith(
      locale: _session.storyLang,
      session: _session,
      lastUpdated: _now(),
    );
    notifyListeners();

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
        'style': _session.style,
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

    if (_readingStarted) {
      _scheduleIllustrationIfNeeded();
    }
  }

  void _appendAgentResponse(GenerateStoryResponse resp) {
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

    if (_readingStarted) {
      _scheduleIllustrationIfNeeded();
    }
  }

  /// Generates (or re-generates) the illustration for the current chapter.
  ///
  /// This should typically be triggered automatically after reading begins.
  Future<void> generateIllustration({bool force = false}) async {
    if (!_autoIllustrationsEnabled) return;
    if (!_session.imageEnabled) return;
    if (_state.chapters.isEmpty) return;

    final status = _state.illustrationStatus;
    if (!force &&
        (status == IllustrationStatus.loading ||
            status == IllustrationStatus.ready)) {
      return;
    }

    final last = _state.chapters.last;
    final existingUrl = last.imageUrl;
    final prompt = _buildIllustrationPrompt(last);

    if (existingUrl != null && existingUrl.trim().isNotEmpty) {
      _state = _state.copyWith(
        illustrationStatus: IllustrationStatus.ready,
        illustrationUrl: existingUrl,
        illustrationPrompt: prompt,
        lastUpdated: _now(),
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      illustrationStatus: IllustrationStatus.loading,
      illustrationUrl: null,
      illustrationPrompt: prompt,
      lastUpdated: _now(),
    );
    notifyListeners();

    try {
      final url = await _imageGeneration.generateImage(story: _state);

      // Persist URL into the last chapter (for restore).
      final chapters = [..._state.chapters];
      final last = chapters.last;
      chapters[chapters.length - 1] = StoryChapter(
        chapterIndex: last.chapterIndex,
        title: last.title,
        text: last.text,
        progress: last.progress,
        imageUrl: url,
        choices: last.choices,
      );

      _state = _state.copyWith(
        chapters: chapters,
        illustrationStatus: IllustrationStatus.ready,
        illustrationUrl: url,
        lastUpdated: _now(),
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Illustration generation failed: $e');
      _state = _state.copyWith(
        illustrationStatus: IllustrationStatus.error,
        illustrationUrl: null,
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
