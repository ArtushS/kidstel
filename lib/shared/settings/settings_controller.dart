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

  Future<void> setInteractiveStoriesEnabled(bool value) =>
      _update(_settings.copyWith(interactiveStoriesEnabled: value));

  // Audio
  Future<void> setVoiceNarrationEnabled(bool value) =>
      _update(_settings.copyWith(voiceNarrationEnabled: value));

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
