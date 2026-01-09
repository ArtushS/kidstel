class StorySetup {
  final String service;
  final String ageGroup;
  final String storyLang;
  final String storyLength;
  final double creativityLevel;
  final bool imageEnabled;
  final String hero;
  final String location;
  final String? locationImage;
  final String storyType;
  final String? storyTypeImage;
  final bool familyEnabled;
  final Map<String, dynamic>? family;

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
    required this.locationImage,
    required this.storyType,
    required this.storyTypeImage,
    required this.familyEnabled,
    required this.family,
    this.idea,
  });
}
