import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/extensions/theme_mode_extension.dart';
import '../../shared/settings/app_settings.dart';
import '../../shared/settings/settings_scope.dart';
import '../../shared/settings/widgets/choice_tile.dart';
import '../../shared/settings/widgets/settings_section.dart';
import '../../shared/settings/widgets/settings_tile.dart';
import '../../shared/settings/widgets/switch_tile.dart';
import '../../shared/voice/voice_input_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const _languages = <String, String>{
    'en': 'English',
    'ru': 'Русский',
    'hy': 'Հայերեն',
  };

  String _themeLabel(BuildContext context, ThemeMode v) => v.localized(context);

  String _fontLabel(BuildContext context, FontScale v) => v.localized(context);

  String _ageLabel(BuildContext context, AgeGroup v) => v.localized(context);

  String _lengthLabel(BuildContext context, StoryLength v) =>
      v.localized(context);

  String _complexityLabel(BuildContext context, StoryComplexity v) =>
      v.localized(context);

  String _creativityLabel(BuildContext context, CreativityLevel v) =>
      v.localized(context);

  Future<T?> _pickEnum<T>({
    required BuildContext context,
    required String title,
    required T current,
    required List<T> values,
    required String Function(T) label,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
              ),
              const Divider(height: 1),
              RadioGroup<T>(
                groupValue: current,
                onChanged: (val) {
                  if (val == null) return;
                  Navigator.of(ctx).pop(val);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final v in values)
                      RadioListTile<T>(value: v, title: Text(label(v))),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _pickLanguage({
    required BuildContext context,
    required String title,
    required String current,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
              ),
              const Divider(height: 1),
              RadioGroup<String>(
                groupValue: current,
                onChanged: (val) {
                  if (val == null) return;
                  Navigator.of(ctx).pop(val);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final e in _languages.entries)
                      RadioListTile<String>(value: e.key, title: Text(e.value)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = SettingsScope.of(context);

    if (!controller.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final s = controller.settings;
    final langLabel =
        _languages[s.defaultLanguageCode] ?? s.defaultLanguageCode;

    final t = AppLocalizations.of(context);

    // Fallback на случай, если локализация ещё не подхватилась (редко, но безопасно)
    final titleSettings = t?.settings ?? 'Settings';
    final titleAppearance = t?.appearance ?? 'Appearance';
    final titleTheme = t?.theme ?? 'Theme';
    final titleFontSize = t?.fontSize ?? 'Font size';
    final titleAnimations = t?.animations ?? 'Animations';
    final titleStoryPrefs = t?.storyPreferences ?? 'Story preferences';
    final titleLanguage = t?.language ?? 'Language';

    return Scaffold(
      appBar: AppBar(title: Text(titleSettings)),
      body: ListView(
        children: [
          SettingsSection(
            title: titleAppearance,
            children: [
              ChoiceTile<ThemeMode>(
                leading: const Icon(Icons.brightness_6_outlined),
                title: titleTheme,
                valueLabel: _themeLabel(context, s.themeMode),
                onTap: () async {
                  final picked = await _pickEnum<ThemeMode>(
                    context: context,
                    title: titleTheme,
                    current: s.themeMode,
                    values: ThemeMode.values,
                    label: (v) => _themeLabel(context, v),
                  );
                  if (picked != null) {
                    await controller.setThemeMode(picked);
                  }
                },
              ),
              ChoiceTile<FontScale>(
                leading: const Icon(Icons.text_fields),
                title: titleFontSize,
                valueLabel: _fontLabel(context, s.fontScale),
                onTap: () async {
                  final picked = await _pickEnum<FontScale>(
                    context: context,
                    title: titleFontSize,
                    current: s.fontScale,
                    values: FontScale.values,
                    label: (v) => _fontLabel(context, v),
                  );
                  if (picked != null) {
                    await controller.setFontScale(picked);
                  }
                },
              ),
              SwitchTile(
                leading: const Icon(Icons.animation_outlined),
                title: titleAnimations,
                subtitle: t?.reduceMotion ?? 'Reduce motion if disabled',
                value: s.animationsEnabled,
                onChanged: controller.setAnimationsEnabled,
              ),
            ],
          ),

          SettingsSection(
            title: titleStoryPrefs,
            children: [
              ChoiceTile<AgeGroup>(
                leading: const Icon(Icons.cake_outlined),
                title: t?.ageGroup ?? 'Age group',
                valueLabel: _ageLabel(context, s.ageGroup),
                onTap: () async {
                  final picked = await _pickEnum<AgeGroup>(
                    context: context,
                    title: t?.ageGroup ?? 'Age group',
                    current: s.ageGroup,
                    values: AgeGroup.values,
                    label: (v) => _ageLabel(context, v),
                  );
                  if (picked != null) {
                    await controller.setAgeGroup(picked);
                  }
                },
              ),
              ChoiceTile<StoryLength>(
                leading: const Icon(Icons.subject_outlined),
                title: t?.storyLength ?? 'Story length',
                valueLabel: _lengthLabel(context, s.storyLength),
                onTap: () async {
                  final picked = await _pickEnum<StoryLength>(
                    context: context,
                    title: t?.storyLength ?? 'Story length',
                    current: s.storyLength,
                    values: StoryLength.values,
                    label: (v) => _lengthLabel(context, v),
                  );
                  if (picked != null) {
                    await controller.setStoryLength(picked);
                  }
                },
              ),
              ChoiceTile<StoryComplexity>(
                leading: const Icon(Icons.tune_outlined),
                title: t?.complexity ?? 'Complexity',
                valueLabel: _complexityLabel(context, s.storyComplexity),
                onTap: () async {
                  final picked = await _pickEnum<StoryComplexity>(
                    context: context,
                    title: t?.complexity ?? 'Complexity',
                    current: s.storyComplexity,
                    values: StoryComplexity.values,
                    label: (v) => _complexityLabel(context, v),
                  );
                  if (picked != null) {
                    await controller.setStoryComplexity(picked);
                  }
                },
              ),
              ChoiceTile<String>(
                leading: const Icon(Icons.language_outlined),
                title: titleLanguage,
                valueLabel: langLabel,
                onTap: () async {
                  // Capture dependencies before any async gaps.
                  VoiceInputController? voice;
                  try {
                    voice = context.read<VoiceInputController>();
                  } catch (_) {
                    voice = null;
                  }

                  final picked = await _pickLanguage(
                    context: context,
                    title: titleLanguage,
                    current: s.defaultLanguageCode,
                  );
                  if (picked != null) {
                    await controller.setDefaultLanguageCode(picked);

                    // Keep STT language in sync with UI language.
                    // If VoiceInputController isn't in scope, ignore safely.
                    await voice?.setDesiredAppLang(picked);
                  }
                },
              ),
              SettingsTile(
                leading: const Icon(Icons.mic_none_rounded),
                title: t?.voiceHelpTitle ?? 'Voice input help',
                subtitle:
                    t?.voiceHelpSubtitle ?? 'Armenian voice input & languages',
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  context.push('/voice-help');
                },
              ),
              SettingsTile(
                leading: const Icon(Icons.record_voice_over_outlined),
                title: t?.defaultNarrationVoice ?? 'Default narration voice',
                subtitle: t?.comingSoon ?? 'Coming soon',
                trailing: const Icon(Icons.lock_outline),
                onTap: () {},
              ),
            ],
          ),

          SettingsSection(
            title: t?.audio ?? 'Audio',
            children: [
              SwitchTile(
                leading: const Icon(Icons.spatial_audio_off_outlined),
                title: t?.voiceNarration ?? 'Voice narration',
                value: s.voiceNarrationEnabled,
                onChanged: controller.setVoiceNarrationEnabled,
              ),
              SwitchTile(
                leading: const Icon(Icons.music_note_outlined),
                title: t?.backgroundMusic ?? 'Background music',
                value: s.backgroundMusicEnabled,
                onChanged: controller.setBackgroundMusicEnabled,
              ),
              SwitchTile(
                leading: const Icon(Icons.graphic_eq_outlined),
                title: t?.soundEffects ?? 'Sound effects',
                value: s.soundEffectsEnabled,
                onChanged: controller.setSoundEffectsEnabled,
              ),
              SwitchTile(
                leading: const Icon(Icons.play_circle_outline),
                title: t?.autoPlayNarration ?? 'Auto-play narration',
                value: s.autoPlayNarration,
                onChanged: controller.setAutoPlayNarration,
              ),
            ],
          ),

          SettingsSection(
            title: t?.parentalSafety ?? 'Parental & Safety',
            children: [
              SwitchTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: t?.safeMode ?? 'Safe mode',
                subtitle:
                    t?.restrictsSensitiveContent ??
                    'Restricts sensitive content',
                value: s.safeModeEnabled,
                onChanged: controller.setSafeModeEnabled,
              ),
              SwitchTile(
                leading: const Icon(Icons.nightlight_outlined),
                title: t?.disableScaryContent ?? 'Disable scary content',
                value: s.disableScaryContent,
                onChanged: controller.setDisableScaryContent,
              ),
              SwitchTile(
                leading: const Icon(Icons.lock_person_outlined),
                title:
                    t?.requireParentConfirmation ??
                    'Require parent confirmation',
                subtitle: t?.beforeStoryGeneration ?? 'Before story generation',
                value: s.requireParentConfirmation,
                onChanged: controller.setRequireParentConfirmation,
              ),
            ],
          ),

          SettingsSection(
            title: t?.aiGeneration ?? 'AI & Generation',
            children: [
              SwitchTile(
                leading: const Icon(Icons.image_outlined),
                title:
                    t?.autoGenerateIllustrations ??
                    'Auto-generate illustrations',
                value: s.autoIllustrations,
                onChanged: controller.setAutoIllustrations,
              ),
              ChoiceTile<CreativityLevel>(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: t?.creativityLevel ?? 'Creativity level',
                valueLabel: _creativityLabel(context, s.creativityLevel),
                onTap: () async {
                  final picked = await _pickEnum<CreativityLevel>(
                    context: context,
                    title: t?.creativityLevel ?? 'Creativity level',
                    current: s.creativityLevel,
                    values: CreativityLevel.values,
                    label: (v) => _creativityLabel(context, v),
                  );
                  if (picked != null) {
                    await controller.setCreativityLevel(picked);
                  }
                },
              ),
              SwitchTile(
                leading: const Icon(Icons.save_outlined),
                title: t?.rememberPreferences ?? 'Remember preferences',
                value: s.rememberPreferences,
                onChanged: controller.setRememberPreferences,
              ),
            ],
          ),

          SettingsSection(
            title: t?.system ?? 'System',
            children: [
              SettingsTile(
                leading: const Icon(Icons.restart_alt_outlined),
                title: t?.resetSettings ?? 'Reset settings',
                subtitle: t?.backToDefaults ?? 'Back to defaults',
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(
                        t?.resetSettingsQuestion ?? 'Reset settings?',
                      ),
                      content: Text(
                        t?.restoreDefaultsMessage ??
                            'This will restore all settings to default values.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(t?.cancel ?? 'Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(t?.reset ?? 'Reset'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await controller.resetToDefaults();
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
