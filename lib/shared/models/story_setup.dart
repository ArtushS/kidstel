class StorySetup {
  final String service;
  final String ageGroup;
  final String storyLang;
  final String storyLength;
  final double creativityLevel;
  final bool imageEnabled;
  final String hero;
  final String location;
  final String style;

  /// User idea (typed or dictated)
  final String? idea;

  const StorySetup({
    required this.service,
    required this.ageGroup,
    required this.storyLang,
    required this.storyLength,
    required this.creativityLevel,
    required this.imageEnabled,
    required this.hero,
    required this.location,
    required this.style,
    this.idea,
  });
}
