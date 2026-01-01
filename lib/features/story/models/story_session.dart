class StorySession {
  final String ageGroup;
  final String storyLang;
  final String storyLength;
  final double creativityLevel;
  final bool imageEnabled;
  final bool interactiveEnabled;
  final String hero;
  final String location;
  final String storyType;
  final String? idea;

  const StorySession({
    required this.ageGroup,
    required this.storyLang,
    required this.storyLength,
    required this.creativityLevel,
    required this.imageEnabled,
    required this.interactiveEnabled,
    required this.hero,
    required this.location,
    required this.storyType,
    required this.idea,
  });

  factory StorySession.empty() {
    return const StorySession(
      ageGroup: '',
      storyLang: '',
      storyLength: '',
      creativityLevel: 0.5,
      imageEnabled: false,
      interactiveEnabled: true,
      hero: '',
      location: '',
      storyType: '',
      idea: null,
    );
  }

  Map<String, dynamic> toJson() => {
    'ageGroup': ageGroup,
    'storyLang': storyLang,
    'storyLength': storyLength,
    'creativityLevel': creativityLevel,
    'imageEnabled': imageEnabled,
    'interactiveEnabled': interactiveEnabled,
    'hero': hero,
    'location': location,
    'storyType': storyType,
    'idea': idea,
  };

  factory StorySession.fromJson(Map<String, dynamic> json) {
    return StorySession(
      ageGroup: (json['ageGroup'] ?? '') as String,
      storyLang: (json['storyLang'] ?? '') as String,
      storyLength: (json['storyLength'] ?? '') as String,
      creativityLevel: (json['creativityLevel'] ?? 0.5).toDouble(),
      imageEnabled: (json['imageEnabled'] ?? false) as bool,
      interactiveEnabled: (json['interactiveEnabled'] ?? true) as bool,
      hero: (json['hero'] ?? '') as String,
      location: (json['location'] ?? '') as String,
      // Accept legacy key 'style' for persisted sessions created before
      // StoryType was introduced.
      storyType: (json['storyType'] ?? json['style'] ?? '') as String,
      idea: json['idea'] as String?,
    );
  }
}
