class GenerateStoryRequest {
  final String requestId;
  final String action; // "generate" | "continue"
  final String? storyId;

  final StoryInput input;
  final StorySelection selection;

  final StoryContext context;

  const GenerateStoryRequest({
    required this.requestId,
    required this.action,
    required this.storyId,
    required this.input,
    required this.selection,
    required this.context,
  });

  Map<String, dynamic> toJson() => {
    'requestId': requestId,
    'action': action,
    'storyId': storyId,
    'input': input.toJson(),
    'selection': selection.toJson(),
    'context': context.toJson(),
  };
}

class StoryInput {
  final String ageGroup; // "3_5" | "6_8" | "9_12"
  final String storyLang; // "ru" | "en" | "hy"
  final String promptLang; // same
  final String responseLang; // same
  final String storyLength; // "short"|"medium"|"long"
  final String complexity; // "simple"|"normal"
  final double creativityLevel; // 0..1

  final ImageOptions image;

  const StoryInput({
    required this.ageGroup,
    required this.storyLang,
    required this.promptLang,
    required this.responseLang,
    required this.storyLength,
    required this.complexity,
    required this.creativityLevel,
    required this.image,
  });

  Map<String, dynamic> toJson() => {
    'ageGroup': ageGroup,
    'storyLang': storyLang,
    'promptLang': promptLang,
    'responseLang': responseLang,
    'storyLength': storyLength,
    'complexity': complexity,
    'creativityLevel': creativityLevel,
    'image': image.toJson(),
  };
}

class ImageOptions {
  final bool enabled; // must be sent always
  final String mode; // "auto" (future: "paid_only")
  final String? styleHint; // optional
  final String? size; // optional

  const ImageOptions({
    required this.enabled,
    this.mode = 'auto',
    this.styleHint,
    this.size,
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'mode': mode,
    if (styleHint != null) 'styleHint': styleHint,
    if (size != null) 'size': size,
  };
}

class StorySelection {
  final String heroId; // from your pick item id
  final String locationId;
  final String styleId;

  /// Optional free-text idea entered by user
  final String? idea;

  const StorySelection({
    required this.heroId,
    required this.locationId,
    required this.styleId,
    this.idea,
  });

  Map<String, dynamic> toJson() => {
    'heroId': heroId,
    'locationId': locationId,
    'styleId': styleId,
    if (idea != null && idea!.trim().isNotEmpty) 'idea': idea!.trim(),
  };
}

class StoryContext {
  final bool safeMode;
  final String client; // "flutter"
  final String appVersion; // optional or "1.0"
  final String platform; // "android"/"ios"/"desktop" (best-effort)

  const StoryContext({
    required this.safeMode,
    required this.client,
    required this.appVersion,
    required this.platform,
  });

  Map<String, dynamic> toJson() => {
    'safeMode': safeMode,
    'client': client,
    'appVersion': appVersion,
    'platform': platform,
  };
}
