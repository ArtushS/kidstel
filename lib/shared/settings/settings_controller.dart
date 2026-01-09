import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'settings_repository.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({required SettingsRepository repository})
    : _repository = repository;

  final SettingsRepository _repository;

  AppSettings _settings = AppSettings.defaults();
  AppSettings get settings => _settings;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> init() async {
    _settings = await _repository.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _update(AppSettings next) async {
    _settings = next;
    notifyListeners();
    await _repository.save(_settings);
  }

  // Appearance
  Future<void> setThemeMode(ThemeMode mode) =>
      _update(_settings.copyWith(themeMode: mode));

  Future<void> setFontScale(FontScale scale) =>
      _update(_settings.copyWith(fontScale: scale));

  Future<void> setAnimationsEnabled(bool value) =>
      _update(_settings.copyWith(animationsEnabled: value));

  // Story preferences
  Future<void> setAgeGroup(AgeGroup value) =>
      _update(_settings.copyWith(ageGroup: value));

  Future<void> setStoryLength(StoryLength value) =>
      _update(_settings.copyWith(storyLength: value));

  Future<void> setStoryComplexity(StoryComplexity value) =>
      _update(_settings.copyWith(storyComplexity: value));

  Future<void> setDefaultLanguageCode(String code) =>
      _update(_settings.copyWith(defaultLanguageCode: code));

  Future<void> setOnboardingCompleted(bool value) =>
      _update(_settings.copyWith(onboardingCompleted: value));

  Future<void> setHeroName(String? value) =>
      _update(_settings.copyWith(heroName: value));

  Future<void> setInteractiveStoriesEnabled(bool value) =>
      _update(_settings.copyWith(interactiveStoriesEnabled: value));

  // Family
  Future<void> setFamilyEnabled(bool value) =>
      _update(_settings.copyWith(familyEnabled: value));

  Future<void> setGrandfatherName(String? value) =>
      _update(_settings.copyWith(grandfatherName: value));

  Future<void> setGrandmotherName(String? value) =>
      _update(_settings.copyWith(grandmotherName: value));

  Future<void> setFatherName(String? value) =>
      _update(_settings.copyWith(fatherName: value));

  Future<void> setMotherName(String? value) =>
      _update(_settings.copyWith(motherName: value));

  Future<void> setBrothers(List<String> value) =>
      _update(_settings.copyWith(brothers: value));

  Future<void> setSisters(List<String> value) =>
      _update(_settings.copyWith(sisters: value));

  // Audio
  Future<void> setVoiceNarrationEnabled(bool value) =>
      _update(_settings.copyWith(voiceNarrationEnabled: value));

  Future<void> setTtsVolume(double value) =>
      _update(_settings.copyWith(ttsVolume: value.clamp(0.0, 1.0)));

  Future<void> setTtsRate(double value) =>
      _update(_settings.copyWith(ttsRate: value.clamp(0.1, 1.0)));

  Future<void> setTtsPitch(double value) =>
      _update(_settings.copyWith(ttsPitch: value.clamp(0.5, 2.0)));

  Future<void> setTtsVoice(Map<String, String>? voice) {
    final encoded = _settings.encodeTtsVoice(voice);
    return _update(_settings.copyWith(ttsVoiceJson: encoded));
  }

  Future<void> setBackgroundMusicEnabled(bool value) =>
      _update(_settings.copyWith(backgroundMusicEnabled: value));

  Future<void> setSoundEffectsEnabled(bool value) =>
      _update(_settings.copyWith(soundEffectsEnabled: value));

  Future<void> setAutoPlayNarration(bool value) =>
      _update(_settings.copyWith(autoPlayNarration: value));

  // Parental / Safety
  Future<void> setSafeModeEnabled(bool value) =>
      _update(_settings.copyWith(safeModeEnabled: value));

  Future<void> setDisableScaryContent(bool value) =>
      _update(_settings.copyWith(disableScaryContent: value));

  Future<void> setRequireParentConfirmation(bool value) =>
      _update(_settings.copyWith(requireParentConfirmation: value));

  // AI & Generation
  Future<void> setAutoIllustrations(bool value) =>
      _update(_settings.copyWith(autoIllustrations: value));

  Future<void> setCreativityLevel(CreativityLevel value) =>
      _update(_settings.copyWith(creativityLevel: value));

  Future<void> setRememberPreferences(bool value) =>
      _update(_settings.copyWith(rememberPreferences: value));

  // System
  Future<void> resetToDefaults() async {
    await _repository.reset();
    _settings = await _repository.load();
    notifyListeners();
  }
}
