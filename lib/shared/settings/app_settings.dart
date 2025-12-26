import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

enum FontScale { small, medium, large }

extension FontScaleExtension on FontScale {
  String localized(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    switch (this) {
      case FontScale.small:
        return t.fontSmall;
      case FontScale.medium:
        return t.fontMedium;
      case FontScale.large:
        return t.fontLarge;
    }
  }
}

enum AgeGroup { age3to5, age6to8, age9to12 }

extension AgeGroupExtension on AgeGroup {
  String localized(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    switch (this) {
      case AgeGroup.age3to5:
        return t.age3to5;
      case AgeGroup.age6to8:
        return t.age6to8;
      case AgeGroup.age9to12:
        return t.age9to12;
    }
  }
}

enum StoryLength { short, medium, long }

extension StoryLengthExtension on StoryLength {
  String localized(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    switch (this) {
      case StoryLength.short:
        return t.storyShort;
      case StoryLength.medium:
        return t.storyMedium;
      case StoryLength.long:
        return t.storyLong;
    }
  }
}

enum StoryComplexity { simple, normal }

extension StoryComplexityExtension on StoryComplexity {
  String localized(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    switch (this) {
      case StoryComplexity.simple:
        return t.complexitySimple;
      case StoryComplexity.normal:
        return t.complexityNormal;
    }
  }
}

enum CreativityLevel { low, normal, high }

extension CreativityLevelExtension on CreativityLevel {
  String localized(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    switch (this) {
      case CreativityLevel.low:
        return t.creativityLow;
      case CreativityLevel.normal:
        return t.creativityNormal;
      case CreativityLevel.high:
        return t.creativityHigh;
    }
  }
}

@immutable
class AppSettings {
  // NOTE: пока храним ThemeMode напрямую, чтобы не зависеть от твоего ThemeController API.
  final ThemeMode themeMode;

  final FontScale fontScale;
  final bool animationsEnabled;

  final AgeGroup ageGroup;
  final StoryLength storyLength;
  final StoryComplexity storyComplexity;
  final String defaultLanguageCode;

  final bool voiceNarrationEnabled;
  final bool backgroundMusicEnabled;
  final bool soundEffectsEnabled;
  final bool autoPlayNarration;

  final bool safeModeEnabled;
  final bool disableScaryContent;
  final bool requireParentConfirmation;

  final bool autoIllustrations;
  final bool interactiveStoriesEnabled;
  final CreativityLevel creativityLevel;
  final bool rememberPreferences;

  const AppSettings({
    required this.themeMode,
    required this.fontScale,
    required this.animationsEnabled,
    required this.ageGroup,
    required this.storyLength,
    required this.storyComplexity,
    required this.defaultLanguageCode,
    required this.voiceNarrationEnabled,
    required this.backgroundMusicEnabled,
    required this.soundEffectsEnabled,
    required this.autoPlayNarration,
    required this.safeModeEnabled,
    required this.disableScaryContent,
    required this.requireParentConfirmation,
    required this.autoIllustrations,
    required this.interactiveStoriesEnabled,
    required this.creativityLevel,
    required this.rememberPreferences,
  });

  factory AppSettings.defaults() => const AppSettings(
    themeMode: ThemeMode.system,
    fontScale: FontScale.medium,
    animationsEnabled: true,
    ageGroup: AgeGroup.age3to5,
    storyLength: StoryLength.medium,
    storyComplexity: StoryComplexity.normal,
    defaultLanguageCode: 'en',
    voiceNarrationEnabled: true,
    backgroundMusicEnabled: false,
    soundEffectsEnabled: true,
    autoPlayNarration: false,
    safeModeEnabled: true,
    disableScaryContent: true,
    requireParentConfirmation: true,
    autoIllustrations: true,
    interactiveStoriesEnabled: true,
    creativityLevel: CreativityLevel.normal,
    rememberPreferences: true,
  );

  AppSettings copyWith({
    ThemeMode? themeMode,
    FontScale? fontScale,
    bool? animationsEnabled,
    AgeGroup? ageGroup,
    StoryLength? storyLength,
    StoryComplexity? storyComplexity,
    String? defaultLanguageCode,
    bool? voiceNarrationEnabled,
    bool? backgroundMusicEnabled,
    bool? soundEffectsEnabled,
    bool? autoPlayNarration,
    bool? safeModeEnabled,
    bool? disableScaryContent,
    bool? requireParentConfirmation,
    bool? autoIllustrations,
    bool? interactiveStoriesEnabled,
    CreativityLevel? creativityLevel,
    bool? rememberPreferences,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      fontScale: fontScale ?? this.fontScale,
      animationsEnabled: animationsEnabled ?? this.animationsEnabled,
      ageGroup: ageGroup ?? this.ageGroup,
      storyLength: storyLength ?? this.storyLength,
      storyComplexity: storyComplexity ?? this.storyComplexity,
      defaultLanguageCode: defaultLanguageCode ?? this.defaultLanguageCode,
      voiceNarrationEnabled:
          voiceNarrationEnabled ?? this.voiceNarrationEnabled,
      backgroundMusicEnabled:
          backgroundMusicEnabled ?? this.backgroundMusicEnabled,
      soundEffectsEnabled: soundEffectsEnabled ?? this.soundEffectsEnabled,
      autoPlayNarration: autoPlayNarration ?? this.autoPlayNarration,
      safeModeEnabled: safeModeEnabled ?? this.safeModeEnabled,
      disableScaryContent: disableScaryContent ?? this.disableScaryContent,
      requireParentConfirmation:
          requireParentConfirmation ?? this.requireParentConfirmation,
      autoIllustrations: autoIllustrations ?? this.autoIllustrations,
      interactiveStoriesEnabled:
          interactiveStoriesEnabled ?? this.interactiveStoriesEnabled,
      creativityLevel: creativityLevel ?? this.creativityLevel,
      rememberPreferences: rememberPreferences ?? this.rememberPreferences,
    );
  }

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode.name,
    'fontScale': fontScale.name,
    'animationsEnabled': animationsEnabled,
    'ageGroup': ageGroup.name,
    'storyLength': storyLength.name,
    'storyComplexity': storyComplexity.name,
    'defaultLanguageCode': defaultLanguageCode,
    'voiceNarrationEnabled': voiceNarrationEnabled,
    'backgroundMusicEnabled': backgroundMusicEnabled,
    'soundEffectsEnabled': soundEffectsEnabled,
    'autoPlayNarration': autoPlayNarration,
    'safeModeEnabled': safeModeEnabled,
    'disableScaryContent': disableScaryContent,
    'requireParentConfirmation': requireParentConfirmation,
    'autoIllustrations': autoIllustrations,
    'interactiveStoriesEnabled': interactiveStoriesEnabled,
    'creativityLevel': creativityLevel.name,
    'rememberPreferences': rememberPreferences,
  };

  static T _enumByNameOr<T extends Enum>(
    List<T> values,
    Object? raw,
    T fallback,
  ) {
    final name = raw?.toString();
    if (name == null) return fallback;
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeMode: _enumByNameOr(
        ThemeMode.values,
        json['themeMode'],
        ThemeMode.system,
      ),
      fontScale: _enumByNameOr(
        FontScale.values,
        json['fontScale'],
        FontScale.medium,
      ),
      animationsEnabled: (json['animationsEnabled'] ?? true) as bool,
      ageGroup: _enumByNameOr(
        AgeGroup.values,
        json['ageGroup'],
        AgeGroup.age3to5,
      ),
      storyLength: _enumByNameOr(
        StoryLength.values,
        json['storyLength'],
        StoryLength.medium,
      ),
      storyComplexity: _enumByNameOr(
        StoryComplexity.values,
        json['storyComplexity'],
        StoryComplexity.normal,
      ),
      defaultLanguageCode: (json['defaultLanguageCode'] ?? 'en') as String,
      voiceNarrationEnabled: (json['voiceNarrationEnabled'] ?? true) as bool,
      backgroundMusicEnabled: (json['backgroundMusicEnabled'] ?? false) as bool,
      soundEffectsEnabled: (json['soundEffectsEnabled'] ?? true) as bool,
      autoPlayNarration: (json['autoPlayNarration'] ?? false) as bool,
      safeModeEnabled: (json['safeModeEnabled'] ?? true) as bool,
      disableScaryContent: (json['disableScaryContent'] ?? true) as bool,
      requireParentConfirmation:
          (json['requireParentConfirmation'] ?? true) as bool,
      autoIllustrations: (json['autoIllustrations'] ?? true) as bool,
      interactiveStoriesEnabled:
          (json['interactiveStoriesEnabled'] ?? true) as bool,
      creativityLevel: _enumByNameOr(
        CreativityLevel.values,
        json['creativityLevel'],
        CreativityLevel.normal,
      ),
      rememberPreferences: (json['rememberPreferences'] ?? true) as bool,
    );
  }
}
