// lib/features/settings/settings_page.dart
//
// Fixes:
// - Flutter 3.32+: remove deprecated Radio/RadiolistTile groupValue/onChanged usage
//   by using RadioGroup (groupValue + onChanged live on RadioGroup).
// - Match your current architecture: SettingsScope.of(context) -> SettingsController
//   and current values live in controller.settings (AppSettings).
// - ChoiceTile now requires valueLabel.

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/settings/app_settings.dart';
import '../../shared/settings/settings_scope.dart';
import '../../shared/settings/widgets/choice_tile.dart';
import '../../shared/settings/widgets/settings_section.dart';
import '../../shared/settings/widgets/switch_tile.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = KidsLocalizations.of(context);
    assert(
      t != null,
      'KidsLocalizations is null. Check localizationsDelegates/supportedLocales.',
    );
    final l10n = t!;

    final controller = SettingsScope.of(context);
    final s = controller.settings;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          SettingsSection(
            title: l10n.appearance,
            children: [
              ChoiceTile(
                title: l10n.theme,
                valueLabel: _themeModeLabel(s.themeMode),
                onTap: () => _showThemeSheet(context, controller, s.themeMode),
              ),
              ChoiceTile(
                title: l10n.fontSize,
                valueLabel: _fontScaleLabel(s.fontScale),
                onTap: () =>
                    _showFontSizeSheet(context, controller, s.fontScale),
              ),
              SwitchTile(
                title: l10n.animations,
                value: s.animationsEnabled,
                onChanged: controller.setAnimationsEnabled,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SettingsSection(
            title: l10n.storyPreferences,
            children: [
              ChoiceTile(
                title: l10n.language,
                valueLabel: _languageLabel(s.defaultLanguageCode),
                onTap: () => _showLanguageSheet(
                  context,
                  controller,
                  s.defaultLanguageCode,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================
  // Bottom sheets (RadioGroup)
  // =========================

  void _showThemeSheet(
    BuildContext context,
    dynamic controller,
    ThemeMode current,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: RadioGroup<ThemeMode>(
            groupValue: current,
            onChanged: (val) {
              if (val == null) return;
              controller.setThemeMode(val);
              Navigator.pop(ctx);
            },
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ThemeTile(mode: ThemeMode.system),
                _ThemeTile(mode: ThemeMode.light),
                _ThemeTile(mode: ThemeMode.dark),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFontSizeSheet(
    BuildContext context,
    dynamic controller,
    FontScale current,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: RadioGroup<FontScale>(
            groupValue: current,
            onChanged: (val) {
              if (val == null) return;
              controller.setFontScale(val);
              Navigator.pop(ctx);
            },
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FontTile(scale: FontScale.small),
                _FontTile(scale: FontScale.medium),
                _FontTile(scale: FontScale.large),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLanguageSheet(
    BuildContext context,
    dynamic controller,
    String current,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: RadioGroup<String>(
            groupValue: current,
            onChanged: (val) {
              if (val == null) return;
              controller.setDefaultLanguageCode(val);
              Navigator.pop(ctx);
            },
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LangTile(code: 'en'),
                _LangTile(code: 'ru'),
                _LangTile(code: 'hy'),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===== Labels for ChoiceTile =====

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  String _fontScaleLabel(FontScale scale) {
    switch (scale) {
      case FontScale.small:
        return 'Small';
      case FontScale.medium:
        return 'Medium';
      case FontScale.large:
        return 'Large';
    }
  }

  String _languageLabel(String code) {
    switch (code) {
      case 'en':
        return 'English';
      case 'ru':
        return 'Русский';
      case 'hy':
        return 'Հայերեն';
      default:
        return code;
    }
  }
}

// =========================
// Radio tiles (NO groupValue / onChanged here)
// RadioGroup ancestor manages selection and change callback.
// =========================

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.mode});

  final ThemeMode mode;

  @override
  Widget build(BuildContext context) {
    final title = switch (mode) {
      ThemeMode.system => 'System',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };

    return RadioListTile<ThemeMode>(value: mode, title: Text(title));
  }
}

class _FontTile extends StatelessWidget {
  const _FontTile({required this.scale});

  final FontScale scale;

  @override
  Widget build(BuildContext context) {
    final title = switch (scale) {
      FontScale.small => 'Small',
      FontScale.medium => 'Medium',
      FontScale.large => 'Large',
    };

    return RadioListTile<FontScale>(value: scale, title: Text(title));
  }
}

class _LangTile extends StatelessWidget {
  const _LangTile({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final title = switch (code) {
      'en' => 'English',
      'ru' => 'Русский',
      'hy' => 'Հայերեն',
      _ => code,
    };

    return RadioListTile<String>(value: code, title: Text(title));
  }
}
