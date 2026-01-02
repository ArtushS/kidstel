class GenerateStoryResponse {
  final String requestId;
  final String storyId;
  final int chapterIndex;
  final double progress;
  final String title;
  final String text;

  final GeneratedImage? image;
  final List<StoryChoiceDto> choices;

  const GenerateStoryResponse({
    required this.requestId,
    required this.storyId,
    required this.chapterIndex,
    required this.progress,
    required this.title,
    required this.text,
    required this.image,
    required this.choices,
  });

  factory GenerateStoryResponse.fromJson(Map<String, dynamic> json) {
    final chapterRaw = json['chapterIndex'];
    final progressRaw = json['progress'];

    final chapterIndex = (chapterRaw is num)
        ? chapterRaw.toInt()
        : int.tryParse(chapterRaw?.toString() ?? '') ?? 0;

    final progress = (progressRaw is num)
        ? progressRaw.toDouble()
        : double.tryParse(progressRaw?.toString() ?? '') ?? 0.0;

    return GenerateStoryResponse(
      requestId: (json['requestId'] ?? '') as String,
      storyId: (json['storyId'] ?? '') as String,
      chapterIndex: chapterIndex,
      progress: progress,
      title: (json['title'] ?? '') as String,
      text: (json['text'] ?? '') as String,
      image: (json['image'] is Map)
          ? GeneratedImage.fromJson(
              Map<String, dynamic>.from(json['image'] as Map),
            )
          : null,
      choices: (json['choices'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => StoryChoiceDto.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class GeneratedImage {
  final bool enabled;
  final String? url;

  /// Optional inline image payload.
  /// May be a raw base64 string or a data URI like `data:image/png;base64,...`.
  final String? base64;

  /// Optional MIME type hint (e.g. `image/png`).
  final String? mimeType;

  /// Optional flags used by some backends.
  /// If present and true, UI may choose to show a placeholder.
  final bool? disabled;
  final String? reason;

  const GeneratedImage({
    required this.enabled,
    required this.url,
    this.base64,
    this.mimeType,
    this.disabled,
    this.reason,
  });

  factory GeneratedImage.fromJson(Map<String, dynamic> json) {
    final rawEnabled = json['enabled'];
    final enabled = rawEnabled is bool
        ? rawEnabled
        : (rawEnabled?.toString().toLowerCase().trim() == 'true');

    return GeneratedImage(
      enabled: enabled,
      url: json['url']?.toString(),
      base64: json['base64']?.toString(),
      mimeType: json['mimeType']?.toString(),
      disabled: json['disabled'] is bool ? (json['disabled'] as bool) : null,
      reason: json['reason']?.toString(),
    );
  }
}

class StoryChoiceDto {
  final String id;
  final String label;
  final Map<String, dynamic> payload;

  const StoryChoiceDto({
    required this.id,
    required this.label,
    required this.payload,
  });

  factory StoryChoiceDto.fromJson(Map<String, dynamic> json) {
    return StoryChoiceDto(
      id: (json['id'] ?? '') as String,
      label: (json['label'] ?? '') as String,
      payload: (json['payload'] is Map<String, dynamic>)
          ? (json['payload'] as Map<String, dynamic>)
          : <String, dynamic>{},
    );
  }
}
