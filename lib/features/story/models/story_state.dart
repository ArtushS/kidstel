import 'story_chapter.dart';
import 'story_choice.dart';
import 'story_image_state.dart';
import 'story_session.dart';

enum IllustrationStatus { idle, loading, ready, error }

IllustrationStatus _illustrationStatusFromJson(Object? value) {
  final v = value?.toString().toLowerCase().trim();
  switch (v) {
    case 'loading':
      return IllustrationStatus.loading;
    case 'ready':
      return IllustrationStatus.ready;
    case 'error':
      return IllustrationStatus.error;
    case 'idle':
    default:
      return IllustrationStatus.idle;
  }
}

String _illustrationStatusToJson(IllustrationStatus status) {
  switch (status) {
    case IllustrationStatus.idle:
      return 'idle';
    case IllustrationStatus.loading:
      return 'loading';
    case IllustrationStatus.ready:
      return 'ready';
    case IllustrationStatus.error:
      return 'error';
  }
}

class StoryState {
  final String storyId;
  final String title;
  final List<StoryChapter> chapters;

  /// Current interactive options (usually from the last chapter).
  final List<StoryChoice> currentChoices;

  /// Illustration lifecycle for the current chapter.
  final IllustrationStatus illustrationStatus;

  /// URL to show when [illustrationStatus] is [IllustrationStatus.ready].
  final String? illustrationUrl;

  /// Prompt used to generate the current illustration (optional; for debugging).
  final String? illustrationPrompt;

  final bool isFinished;
  final DateTime lastUpdated;
  final String locale;

  /// Needed to continue story after restore.
  final StorySession session;

  final bool isLoading;
  final String? error;
  final String? lastChoiceId;

  const StoryState({
    required this.storyId,
    required this.title,
    required this.chapters,
    required this.currentChoices,
    required this.illustrationStatus,
    required this.illustrationUrl,
    required this.illustrationPrompt,
    required this.isFinished,
    required this.lastUpdated,
    required this.locale,
    required this.session,
    required this.isLoading,
    required this.error,
    required this.lastChoiceId,
  });

  factory StoryState.empty() {
    return StoryState(
      storyId: '',
      title: '',
      chapters: <StoryChapter>[],
      currentChoices: <StoryChoice>[],
      illustrationStatus: IllustrationStatus.idle,
      illustrationUrl: null,
      illustrationPrompt: null,
      isFinished: false,
      lastUpdated: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      locale: '',
      session: StorySession.empty(),
      isLoading: false,
      error: null,
      lastChoiceId: null,
    );
  }

  StoryState copyWith({
    String? storyId,
    String? title,
    List<StoryChapter>? chapters,
    List<StoryChoice>? currentChoices,
    IllustrationStatus? illustrationStatus,
    String? illustrationUrl,
    String? illustrationPrompt,
    bool? isFinished,
    DateTime? lastUpdated,
    String? locale,
    StorySession? session,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? lastChoiceId,
  }) {
    return StoryState(
      storyId: storyId ?? this.storyId,
      title: title ?? this.title,
      chapters: chapters ?? this.chapters,
      currentChoices: currentChoices ?? this.currentChoices,
      illustrationStatus: illustrationStatus ?? this.illustrationStatus,
      illustrationUrl: illustrationUrl ?? this.illustrationUrl,
      illustrationPrompt: illustrationPrompt ?? this.illustrationPrompt,
      isFinished: isFinished ?? this.isFinished,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      locale: locale ?? this.locale,
      session: session ?? this.session,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastChoiceId: lastChoiceId ?? this.lastChoiceId,
    );
  }

  Map<String, dynamic> toJson() => {
    'storyId': storyId,
    'title': title,
    'chapters': chapters.map((e) => e.toJson()).toList(growable: false),
    'currentChoices': currentChoices
        .map((e) => e.toJson())
        .toList(growable: false),
    'illustrationStatus': _illustrationStatusToJson(illustrationStatus),
    'illustrationUrl': illustrationUrl,
    'illustrationPrompt': illustrationPrompt,
    'isFinished': isFinished,
    'lastUpdated': lastUpdated.toIso8601String(),
    'locale': locale,
    'session': session.toJson(),
  };

  factory StoryState.fromJson(Map<String, dynamic> json) {
    // Backward-compat: previous versions stored nested imageState.
    final legacyImageState = (json['imageState'] is Map)
        ? StoryImageState.fromJson(
            Map<String, dynamic>.from(json['imageState'] as Map),
          )
        : null;

    final status = json.containsKey('illustrationStatus')
        ? _illustrationStatusFromJson(json['illustrationStatus'])
        : switch (legacyImageState?.status) {
            StoryImageStatus.none => IllustrationStatus.idle,
            StoryImageStatus.loading => IllustrationStatus.loading,
            StoryImageStatus.ready => IllustrationStatus.ready,
            StoryImageStatus.error => IllustrationStatus.error,
            null => IllustrationStatus.idle,
          };

    return StoryState(
      storyId: (json['storyId'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      chapters: (json['chapters'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => StoryChapter.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      currentChoices: (json['currentChoices'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => StoryChoice.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      illustrationStatus: status,
      illustrationUrl:
          (json['illustrationUrl'] as String?) ?? legacyImageState?.url,
      illustrationPrompt: json['illustrationPrompt'] as String?,
      isFinished: (json['isFinished'] ?? false) as bool,
      lastUpdated:
          DateTime.tryParse((json['lastUpdated'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      locale: (json['locale'] ?? '') as String,
      session: (json['session'] is Map)
          ? StorySession.fromJson(
              Map<String, dynamic>.from(json['session'] as Map),
            )
          : StorySession.empty(),
      // Runtime-only fields are not persisted.
      isLoading: false,
      error: null,
      lastChoiceId: null,
    );
  }
}
