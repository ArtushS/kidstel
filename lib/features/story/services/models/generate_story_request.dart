class GenerateStoryRequest {
  /// Backward-compatible dispatcher field (server supports both / and /v1 endpoints).
  /// Allowed: "generate" | "continue" | "illustrate".
  final String action;

  /// Optional; server will generate one if absent.
  final String? requestId;

  /// Required for continue/illustrate.
  final String? storyId;

  /// Optional for continue/illustrate.
  final int? chapterIndex;

  // Common story parameters (server allowlists these).
  final String? ageGroup; // "3_5" | "6_8" | "9_12"
  final String? storyLang; // "ru" | "en" | "hy"
  final String? storyLength; // "short" | "medium" | "long"
  final double? creativityLevel; // 0..1
  final bool? imageEnabled;

  final StorySelection? selection;
  final String? idea;

  // Continue only
  final StoryChoice? choice;

  // Illustrate only
  final String? prompt;

  const GenerateStoryRequest({
    required this.action,
    this.requestId,
    this.storyId,
    this.chapterIndex,
    this.ageGroup,
    this.storyLang,
    this.storyLength,
    this.creativityLevel,
    this.imageEnabled,
    this.selection,
    this.idea,
    this.choice,
    this.prompt,
  });

  Map<String, dynamic> toJson() {
    final v = <String, dynamic>{
      'action': action,
      if (requestId != null && requestId!.trim().isNotEmpty)
        'requestId': requestId!.trim(),
      if (storyId != null && storyId!.trim().isNotEmpty)
        'storyId': storyId!.trim(),
      if (chapterIndex != null) 'chapterIndex': chapterIndex,
      if (ageGroup != null) 'ageGroup': ageGroup,
      if (storyLang != null) 'storyLang': storyLang,
      if (storyLength != null) 'storyLength': storyLength,
      if (creativityLevel != null) 'creativityLevel': creativityLevel,
      if (imageEnabled != null) 'image': {'enabled': imageEnabled},
      if (selection != null) 'selection': selection!.toJson(),
    };

    final ideaTrim = idea?.trim();
    if (ideaTrim != null && ideaTrim.isNotEmpty) v['idea'] = ideaTrim;

    if (choice != null) v['choice'] = choice!.toJson();

    final promptTrim = prompt?.trim();
    if (promptTrim != null && promptTrim.isNotEmpty) v['prompt'] = promptTrim;

    return v;
  }
}

class StorySelection {
  final String hero;
  final String location;

  /// Backend contract expects `selection.style` (we map storyType -> style).
  final String style;

  const StorySelection({
    required this.hero,
    required this.location,
    required this.style,
  });

  Map<String, dynamic> toJson() => {
    'hero': hero,
    'location': location,
    'style': style,
  };
}

class StoryChoice {
  final String id;
  final Map<String, dynamic> payload;

  const StoryChoice({
    required this.id,
    this.payload = const <String, dynamic>{},
  });

  Map<String, dynamic> toJson() => {'id': id, 'payload': payload};
}
