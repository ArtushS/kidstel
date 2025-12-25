import 'story_choice_view_data.dart';

class StoryViewData {
  final String storyId;
  final String title;

  final String? coverImageUrl;

  final int chapterIndex;
  final double progress;

  final String text;
  final List<StoryChoiceViewData> choices;

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
