import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  /// Optional field used to name the main hero. Empty string is allowed;
  /// null means "not set".
  final String? heroName;

  final bool voiceNarrationEnabled;
  final bool backgroundMusicEnabled;
  final bool soundEffectsEnabled;
  final bool autoPlayNarration;

  // TTS (voice narration) details
  final double ttsVolume; // 0..1
  final double ttsRate; // speech rate
  final double ttsPitch; // pitch ("intensity")
  final String? ttsVoiceJson; // nullable; stores {name, locale}

  final bool safeModeEnabled;
  final bool disableScaryContent;
  final bool requireParentConfirmation;

  final bool autoIllustrations;

  /// DEV/TEST-only behavior: when enabled, illustration generation failures
  /// should fall back to a deterministic placeholder image.
  ///
  /// Default: enabled in debug builds.
  final bool devIllustrationFallbackEnabled;
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
    required this.heroName,
    required this.voiceNarrationEnabled,
    required this.backgroundMusicEnabled,
    required this.soundEffectsEnabled,
    required this.autoPlayNarration,
    required this.ttsVolume,
    required this.ttsRate,
    required this.ttsPitch,
    required this.ttsVoiceJson,
    required this.safeModeEnabled,
    required this.disableScaryContent,
    required this.requireParentConfirmation,
    required this.autoIllustrations,
    required this.devIllustrationFallbackEnabled,
    required this.interactiveStoriesEnabled,
    required this.creativityLevel,
    required this.rememberPreferences,
  });

  Map<String, String>? get ttsVoice {
    final raw = ttsVoiceJson;
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final m = Map<String, dynamic>.from(decoded);
        final name = m['name']?.toString();
        final locale = m['locale']?.toString();
        final n = name?.trim() ?? '';
        final l = locale?.trim() ?? '';
        if (n.isNotEmpty && l.isNotEmpty) {
          return {'name': n, 'locale': l};
        }
      }
    } catch (_) {
      // ignore
    }
    return null;
  }

  String? encodeTtsVoice(Map<String, String>? voice) {
    if (voice == null) return null;
    final name = (voice['name'] ?? '').trim();
    final locale = (voice['locale'] ?? '').trim();
    if (name.isEmpty || locale.isEmpty) return null;
    return jsonEncode({'name': name, 'locale': locale});
  }

  factory AppSettings.defaults() => AppSettings(
    themeMode: ThemeMode.system,
    fontScale: FontScale.medium,
    animationsEnabled: true,
    ageGroup: AgeGroup.age3to5,
    storyLength: StoryLength.medium,
    storyComplexity: StoryComplexity.normal,
    defaultLanguageCode: 'en',
    heroName: null,
    voiceNarrationEnabled: true,
    backgroundMusicEnabled: false,
    soundEffectsEnabled: true,
    autoPlayNarration: false,
    ttsVolume: 1.0,
    ttsRate: 0.6,
    ttsPitch: 1.0,
    ttsVoiceJson: null,
    safeModeEnabled: true,
    disableScaryContent: true,
    requireParentConfirmation: true,
    autoIllustrations: false,
    devIllustrationFallbackEnabled: const bool.fromEnvironment(
      'DEV_ILLUSTRATION_FALLBACK',
      defaultValue: kDebugMode,
    ),
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
    String? heroName,
    bool? voiceNarrationEnabled,
    bool? backgroundMusicEnabled,
    bool? soundEffectsEnabled,
    bool? autoPlayNarration,
    double? ttsVolume,
    double? ttsRate,
    double? ttsPitch,
    String? ttsVoiceJson,
    bool? safeModeEnabled,
    bool? disableScaryContent,
    bool? requireParentConfirmation,
    bool? autoIllustrations,
    bool? devIllustrationFallbackEnabled,
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
      heroName: heroName ?? this.heroName,
      voiceNarrationEnabled:
          voiceNarrationEnabled ?? this.voiceNarrationEnabled,
      backgroundMusicEnabled:
          backgroundMusicEnabled ?? this.backgroundMusicEnabled,
      soundEffectsEnabled: soundEffectsEnabled ?? this.soundEffectsEnabled,
      autoPlayNarration: autoPlayNarration ?? this.autoPlayNarration,
      ttsVolume: ttsVolume ?? this.ttsVolume,
      ttsRate: ttsRate ?? this.ttsRate,
      ttsPitch: ttsPitch ?? this.ttsPitch,
      ttsVoiceJson: ttsVoiceJson ?? this.ttsVoiceJson,
      safeModeEnabled: safeModeEnabled ?? this.safeModeEnabled,
      disableScaryContent: disableScaryContent ?? this.disableScaryContent,
      requireParentConfirmation:
          requireParentConfirmation ?? this.requireParentConfirmation,
      autoIllustrations: autoIllustrations ?? this.autoIllustrations,
      devIllustrationFallbackEnabled:
          devIllustrationFallbackEnabled ?? this.devIllustrationFallbackEnabled,
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
    'heroName': heroName,
    'voiceNarrationEnabled': voiceNarrationEnabled,
    'backgroundMusicEnabled': backgroundMusicEnabled,
    'soundEffectsEnabled': soundEffectsEnabled,
    'autoPlayNarration': autoPlayNarration,
    'ttsVolume': ttsVolume,
    'ttsRate': ttsRate,
    'ttsPitch': ttsPitch,
    'ttsVoiceJson': ttsVoiceJson,
    'safeModeEnabled': safeModeEnabled,
    'disableScaryContent': disableScaryContent,
    'requireParentConfirmation': requireParentConfirmation,
    'autoIllustrations': autoIllustrations,
    'devIllustrationFallbackEnabled': devIllustrationFallbackEnabled,
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
      heroName: (() {
        // Migration: older versions stored this setting under "childName".
        final raw = json['heroName'] ?? json['childName'];
        if (raw == null) return null;
        return raw.toString();
      })(),
      voiceNarrationEnabled: (json['voiceNarrationEnabled'] ?? true) as bool,
      backgroundMusicEnabled: (json['backgroundMusicEnabled'] ?? false) as bool,
      soundEffectsEnabled: (json['soundEffectsEnabled'] ?? true) as bool,
      autoPlayNarration: (json['autoPlayNarration'] ?? false) as bool,
      ttsVolume: ((json['ttsVolume'] ?? 1.0) as num).toDouble().clamp(0.0, 1.0),
      ttsRate: ((json['ttsRate'] ?? 0.6) as num).toDouble().clamp(0.1, 1.0),
      ttsPitch: ((json['ttsPitch'] ?? 1.0) as num).toDouble().clamp(0.5, 2.0),
      ttsVoiceJson: (() {
        final raw = json['ttsVoiceJson'];
        final s = raw?.toString().trim() ?? '';
        return s.isEmpty ? null : s;
      })(),
      safeModeEnabled: (json['safeModeEnabled'] ?? true) as bool,
      disableScaryContent: (json['disableScaryContent'] ?? true) as bool,
      requireParentConfirmation:
          (json['requireParentConfirmation'] ?? true) as bool,
      autoIllustrations: (json['autoIllustrations'] ?? true) as bool,
      devIllustrationFallbackEnabled:
          (json['devIllustrationFallbackEnabled'] ??
                  const bool.fromEnvironment(
                    'DEV_ILLUSTRATION_FALLBACK',
                    defaultValue: kDebugMode,
                  ))
              as bool,
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
