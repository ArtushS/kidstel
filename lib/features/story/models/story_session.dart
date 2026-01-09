import '../../../shared/models/family_profile.dart';

class StorySession {
  final String ageGroup;
  final String storyLang;
  final String storyLength;
  final double creativityLevel;
  final bool imageEnabled;
  final bool interactiveEnabled;
  final String hero;
  final String location;
  final String? locationImage;
  final String storyType;
  final String? storyTypeImage;
  final String? idea;
  final FamilyProfile? family;

  const StorySession({
    required this.ageGroup,
    required this.storyLang,
    required this.storyLength,
    required this.creativityLevel,
    required this.imageEnabled,
    required this.interactiveEnabled,
    required this.hero,
    required this.location,
    required this.locationImage,
    required this.storyType,
    required this.storyTypeImage,
    required this.idea,
    required this.family,
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
      locationImage: null,
      storyType: '',
      storyTypeImage: null,
      idea: null,
      family: null,
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
    'locationImage': locationImage,
    'storyType': storyType,
    'storyTypeImage': storyTypeImage,
    'idea': idea,
    'family': family?.toJson(),
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
      locationImage: json['locationImage']?.toString(),
      // Accept legacy key 'style' for persisted sessions created before
      // StoryType was introduced.
      storyType: (json['storyType'] ?? json['style'] ?? '') as String,
      storyTypeImage: json['storyTypeImage']?.toString(),
      idea: json['idea'] as String?,
      family: (json['family'] is Map)
          ? FamilyProfile.fromJson(
              Map<String, dynamic>.from(json['family'] as Map),
            )
          : null,
    );
  }
}
