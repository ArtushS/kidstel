import '../../story/services/models/generate_story_response.dart';
import 'story_choice.dart';

class StoryChapter {
  final int chapterIndex;
  final String title;
  final String text;
  final double progress;
  final String? imageUrl;
  final List<StoryChoice> choices;

  const StoryChapter({
    required this.chapterIndex,
    required this.title,
    required this.text,
    required this.progress,
    required this.imageUrl,
    required this.choices,
  });

  bool get isFinal => choices.isEmpty;

  static StoryChapter fromAgentResponse(GenerateStoryResponse resp) {
    final mappedChoices = resp.choices
        .where((c) => c.label.trim().isNotEmpty)
        .map((c) => StoryChoice(id: c.id, label: c.label, payload: c.payload))
        .toList(growable: false);

    return StoryChapter(
      chapterIndex: resp.chapterIndex,
      title: resp.title,
      text: resp.text,
      progress: resp.progress.clamp(0.0, 1.0),
      imageUrl: resp.image?.url,
      choices: mappedChoices,
    );
  }

  Map<String, dynamic> toJson() => {
    'chapterIndex': chapterIndex,
    'title': title,
    'text': text,
    'progress': progress,
    'imageUrl': imageUrl,
    'choices': choices.map((e) => e.toJson()).toList(growable: false),
  };

  factory StoryChapter.fromJson(Map<String, dynamic> json) {
    return StoryChapter(
      chapterIndex: (json['chapterIndex'] ?? 0) as int,
      title: (json['title'] ?? '') as String,
      text: (json['text'] ?? '') as String,
      progress: (json['progress'] ?? 0.0).toDouble(),
      imageUrl: json['imageUrl'] as String?,
      choices: (json['choices'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => StoryChoice.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
    );
  }
}
