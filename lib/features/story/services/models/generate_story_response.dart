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
    return GenerateStoryResponse(
      requestId: (json['requestId'] ?? '') as String,
      storyId: (json['storyId'] ?? '') as String,
      chapterIndex: (json['chapterIndex'] ?? 0) as int,
      progress: (json['progress'] ?? 0.0).toDouble(),
      title: (json['title'] ?? '') as String,
      text: (json['text'] ?? '') as String,
      image: (json['image'] is Map<String, dynamic>)
          ? GeneratedImage.fromJson(json['image'] as Map<String, dynamic>)
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

  const GeneratedImage({required this.enabled, required this.url});

  factory GeneratedImage.fromJson(Map<String, dynamic> json) {
    return GeneratedImage(
      enabled: (json['enabled'] ?? false) as bool,
      url: json['url'] as String?,
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
