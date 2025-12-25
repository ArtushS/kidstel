import '../story/services/models/generate_story_response.dart';

/// Data-only arguments to open [StoryReaderPage].
///
/// IMPORTANT: this must not include services (no StoryService here).
class StoryReaderArgs {
  final GenerateStoryResponse? initialResponse;

  final String ageGroup;
  final String storyLang;
  final String storyLength;
  final double creativityLevel;
  final bool imageEnabled;
  final String hero;
  final String location;
  final String style;

  const StoryReaderArgs({
    this.initialResponse,
    this.ageGroup = '',
    this.storyLang = '',
    this.storyLength = '',
    this.creativityLevel = 0.5,
    this.imageEnabled = false,
    this.hero = '',
    this.location = '',
    this.style = '',
  });
}
