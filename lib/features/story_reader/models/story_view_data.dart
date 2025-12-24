import 'story_choice_view_data.dart';

class StoryViewData {
  final String storyId;
  final String title;

  /// For now this is a single image for the chapter/cover.
  /// Later: can become per-chapter images.
  final String? coverImageUrl;

  /// 0-based chapter index
  final int chapterIndex;

  /// 0..1 progress (can be derived from chapters later)
  final double progress;

  /// Chapter text
  final String text;

  /// Choices for branching
  final List<StoryChoiceViewData> choices;

  /// True if the story ended (no choices)
  final bool isFinal;

  const StoryViewData({
    required this.storyId,
    required this.title,
    required this.coverImageUrl,
    required this.chapterIndex,
    required this.progress,
    required this.text,
    required this.choices,
    required this.isFinal,
  });
}
