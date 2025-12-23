import 'package:flutter/material.dart';
import '../../shared/settings/app_settings.dart';
import '../../shared/settings/settings_scope.dart';
import '../../shared/settings/widgets/settings_section.dart';
import '../../shared/settings/widgets/switch_tile.dart';
import '../../shared/settings/widgets/choice_tile.dart';
import '../../shared/settings/widgets/settings_tile.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const _languages = <String, String>{
    'en': 'English',
    'ru': 'Russian',
    'hy': 'Armenian',
  };

  String _themeLabel(AppThemeMode v) {
    switch (v) {
      case AppThemeMode.system:
        return 'System';
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
    }
  }

  String _fontLabel(FontScale v) {
    switch (v) {
      case FontScale.small:
        return 'Small';
      case FontScale.medium:
        return 'Medium';
      case FontScale.large:
        return 'Large';
    }
  }

  String _ageLabel(AgeGroup v) {
    switch (v) {
      case AgeGroup.age3to5:
        return '3–5';
      case AgeGroup.age6to8:
        return '6–8';
      case AgeGroup.age9to12:
        return '9–12';
    }
  }

  String _lengthLabel(StoryLength v) {
    switch (v) {
      case StoryLength.short:
        return 'Short';
      case StoryLength.medium:
        return 'Medium';
      case StoryLength.long:
        return 'Long';
    }
  }

  String _complexityLabel(StoryComplexity v) {
    switch (v) {
      case StoryComplexity.simple:
        return 'Simple';
      case StoryComplexity.normal:
        return 'Normal';
    }
  }

  String _creativityLabel(CreativityLevel v) {
    switch (v) {
      case CreativityLevel.low:
        return 'Low';
      case CreativityLevel.normal:
        return 'Normal';
      case CreativityLevel.high:
        return 'High';
    }
  }

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
              ...values.map((v) {
                final selected = v == current;
                return RadioListTile<T>(
                  value: v,
                  groupValue: current,
                  title: Text(label(v)),
                  onChanged: (val) => Navigator.of(ctx).pop(val),
                  selected: selected,
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _pickLanguage({
    required BuildContext context,
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
                title: Text(
                  'Language',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              const Divider(height: 1),
              ..._languages.entries.map((e) {
                return RadioListTile<String>(
                  value: e.key,
                  groupValue: current,
                  title: Text(e.value),
                  onChanged: (val) => Navigator.of(ctx).pop(val),
                );
              }),
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
      // init() должен вызываться в app.dart. Но если забыли — покажем лоадер.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final s = controller.settings;
    final langLabel =
        _languages[s.defaultLanguageCode] ?? s.defaultLanguageCode;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SettingsSection(
            title: 'Appearance',
            children: [
              ChoiceTile<AppThemeMode>(
                leading: const Icon(Icons.brightness_6_outlined),
                title: 'Theme',
                valueLabel: _themeLabel(s.themeMode),
                onTap: () async {
                  final picked = await _pickEnum<AppThemeMode>(
                    context: context,
                    title: 'Theme',
                    current: s.themeMode,
                    values: AppThemeMode.values,
                    label: _themeLabel,
                  );
                  if (picked != null) await controller.setThemeMode(picked);
                },
              ),
              ChoiceTile<FontScale>(
                leading: const Icon(Icons.text_fields),
                title: 'Font size',
                valueLabel: _fontLabel(s.fontScale),
                onTap: () async {
                  final picked = await _pickEnum<FontScale>(
                    context: context,
                    title: 'Font size',
                    current: s.fontScale,
                    values: FontScale.values,
                    label: _fontLabel,
                  );
                  if (picked != null) await controller.setFontScale(picked);
                },
              ),
              SwitchTile(
                leading: const Icon(Icons.animation_outlined),
                title: 'Animations',
                subtitle: 'Reduce motion if disabled',
                value: s.animationsEnabled,
                onChanged: (v) => controller.setAnimationsEnabled(v),
              ),
            ],
          ),

          SettingsSection(
            title: 'Story preferences',
            children: [
              ChoiceTile<AgeGroup>(
                leading: const Icon(Icons.cake_outlined),
                title: 'Age group',
                valueLabel: _ageLabel(s.ageGroup),
                onTap: () async {
                  final picked = await _pickEnum<AgeGroup>(
                    context: context,
                    title: 'Age group',
                    current: s.ageGroup,
                    values: AgeGroup.values,
                    label: _ageLabel,
                  );
                  if (picked != null) await controller.setAgeGroup(picked);
                },
              ),
              ChoiceTile<StoryLength>(
                leading: const Icon(Icons.subject_outlined),
                title: 'Story length',
                valueLabel: _lengthLabel(s.storyLength),
                onTap: () async {
                  final picked = await _pickEnum<StoryLength>(
                    context: context,
                    title: 'Story length',
                    current: s.storyLength,
                    values: StoryLength.values,
                    label: _lengthLabel,
                  );
                  if (picked != null) await controller.setStoryLength(picked);
                },
              ),
              ChoiceTile<StoryComplexity>(
                leading: const Icon(Icons.tune_outlined),
                title: 'Complexity',
                valueLabel: _complexityLabel(s.storyComplexity),
                onTap: () async {
                  final picked = await _pickEnum<StoryComplexity>(
                    context: context,
                    title: 'Complexity',
                    current: s.storyComplexity,
                    values: StoryComplexity.values,
                    label: _complexityLabel,
                  );
                  if (picked != null) {
                    await controller.setStoryComplexity(picked);
                  }
                },
              ),
              ChoiceTile<String>(
                leading: const Icon(Icons.language_outlined),
                title: 'Language',
                valueLabel: langLabel,
                onTap: () async {
                  final picked = await _pickLanguage(
                    context: context,
                    current: s.defaultLanguageCode,
                  );
                  if (picked != null) {
                    await controller.setDefaultLanguageCode(picked);
                  }
                },
              ),
              SettingsTile(
                leading: const Icon(Icons.record_voice_over_outlined),
                title: 'Default narration voice',
                subtitle: 'Coming soon',
                trailing: const Icon(Icons.lock_outline),
                onTap: () {},
              ),
            ],
          ),

          SettingsSection(
            title: 'Audio',
            children: [
              SwitchTile(
                leading: const Icon(Icons.spatial_audio_off_outlined),
                title: 'Voice narration',
                value: s.voiceNarrationEnabled,
                onChanged: (v) => controller.setVoiceNarrationEnabled(v),
              ),
              SwitchTile(
                leading: const Icon(Icons.music_note_outlined),
                title: 'Background music',
                value: s.backgroundMusicEnabled,
                onChanged: (v) => controller.setBackgroundMusicEnabled(v),
              ),
              SwitchTile(
                leading: const Icon(Icons.graphic_eq_outlined),
                title: 'Sound effects',
                value: s.soundEffectsEnabled,
                onChanged: (v) => controller.setSoundEffectsEnabled(v),
              ),
              SwitchTile(
                leading: const Icon(Icons.play_circle_outline),
                title: 'Auto-play narration',
                value: s.autoPlayNarration,
                onChanged: (v) => controller.setAutoPlayNarration(v),
              ),
            ],
          ),

          SettingsSection(
            title: 'Parental & Safety',
            children: [
              SwitchTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: 'Safe mode',
                subtitle: 'Restricts sensitive content',
                value: s.safeModeEnabled,
                onChanged: (v) => controller.setSafeModeEnabled(v),
              ),
              SwitchTile(
                leading: const Icon(Icons.nightlight_outlined),
                title: 'Disable scary content',
                value: s.disableScaryContent,
                onChanged: (v) => controller.setDisableScaryContent(v),
              ),
              SwitchTile(
                leading: const Icon(Icons.lock_person_outlined),
                title: 'Require parent confirmation',
                subtitle: 'Before story generation',
                value: s.requireParentConfirmation,
                onChanged: (v) => controller.setRequireParentConfirmation(v),
              ),
            ],
          ),

          SettingsSection(
            title: 'AI & Generation',
            children: [
              SwitchTile(
                leading: const Icon(Icons.image_outlined),
                title: 'Auto-generate illustrations',
                value: s.autoIllustrations,
                onChanged: (v) => controller.setAutoIllustrations(v),
              ),
              ChoiceTile<CreativityLevel>(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: 'Creativity level',
                valueLabel: _creativityLabel(s.creativityLevel),
                onTap: () async {
                  final picked = await _pickEnum<CreativityLevel>(
                    context: context,
                    title: 'Creativity level',
                    current: s.creativityLevel,
                    values: CreativityLevel.values,
                    label: _creativityLabel,
                  );
                  if (picked != null)
                    await controller.setCreativityLevel(picked);
                },
              ),
              SwitchTile(
                leading: const Icon(Icons.save_outlined),
                title: 'Remember preferences',
                value: s.rememberPreferences,
                onChanged: (v) => controller.setRememberPreferences(v),
              ),
            ],
          ),

          SettingsSection(
            title: 'Account',
            children: [
              SettingsTile(
                leading: const Icon(Icons.person_outline),
                title: 'Login status',
                subtitle: 'Guest (placeholder)',
                onTap: () {},
              ),
              SettingsTile(
                leading: const Icon(Icons.restore_outlined),
                title: 'Restore purchases',
                subtitle: 'Placeholder',
                onTap: () {},
              ),
              SettingsTile(
                leading: const Icon(Icons.logout_outlined),
                title: 'Logout',
                subtitle: 'Placeholder',
                onTap: () {},
              ),
            ],
          ),

          SettingsSection(
            title: 'System',
            children: [
              SettingsTile(
                leading: const Icon(Icons.cleaning_services_outlined),
                title: 'Clear cache',
                subtitle: 'Placeholder',
                onTap: () {},
              ),
              SettingsTile(
                leading: const Icon(Icons.restart_alt_outlined),
                title: 'Reset settings',
                subtitle: 'Back to defaults',
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Reset settings?'),
                      content: const Text(
                        'This will restore all settings to default values.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await controller.resetToDefaults();
                  }
                },
              ),
              SettingsTile(
                leading: const Icon(Icons.info_outline),
                title: 'App version',
                subtitle: '0.1.0 (placeholder)',
                onTap: () {},
              ),
              SettingsTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: 'Privacy policy',
                subtitle: 'Placeholder',
                onTap: () {},
              ),
              SettingsTile(
                leading: const Icon(Icons.description_outlined),
                title: 'Terms of service',
                subtitle: 'Placeholder',
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
