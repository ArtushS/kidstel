import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/extensions/theme_mode_extension.dart';
import '../../shared/settings/app_settings.dart';
import '../../shared/settings/settings_controller.dart';
import '../../shared/settings/settings_scope.dart';
import '../../shared/settings/widgets/choice_tile.dart';
import '../../shared/settings/widgets/settings_section.dart';
import '../../shared/settings/widgets/settings_tile.dart';
import '../../shared/settings/widgets/switch_tile.dart';
import '../../shared/tts/open_tts_settings.dart';
import '../../shared/tts/tts_service.dart';
import '../../shared/voice/voice_input_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

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
            mainAxisSize: MainAxisSize.max,
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(titleSettings),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _handleBack(context),
          ),
        ),
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
                SwitchTile(
                  leading: const Icon(Icons.interests_outlined),
                  title: t?.interactiveStories ?? 'Enable interactive stories',
                  subtitle:
                      t?.interactiveStoriesSubtitle ??
                      'Show choices (up to 3 steps) to continue the story',
                  value: s.interactiveStoriesEnabled,
                  onChanged: controller.setInteractiveStoriesEnabled,
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
                      t?.voiceHelpSubtitle ??
                      'Armenian voice input & languages',
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
                _VoiceNarrationDetails(settings: s, controller: controller),
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
                  subtitle:
                      t?.beforeStoryGeneration ?? 'Before story generation',
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
      ),
    );
  }
}

class _VoiceNarrationDetails extends StatefulWidget {
  final AppSettings settings;
  final SettingsController controller;

  const _VoiceNarrationDetails({
    required this.settings,
    required this.controller,
  });

  @override
  State<_VoiceNarrationDetails> createState() => _VoiceNarrationDetailsState();
}

class _VoiceNarrationDetailsState extends State<_VoiceNarrationDetails> {
  Future<List<Map<String, String>>>? _voicesFuture;
  bool _onlyCurrentLanguage = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Lazy-load voices once (best-effort). If plugin isn't available, list is empty.
    _voicesFuture ??= context.read<TtsService>().listVoices();
  }

  String _voiceLabel(Map<String, String>? v) {
    if (v == null) return 'System default';
    final name = (v['name'] ?? '').trim();
    final locale = (v['locale'] ?? '').trim();
    if (name.isEmpty && locale.isEmpty) return 'System default';
    if (locale.isEmpty) return name;
    if (name.isEmpty) return locale;
    return '$name ($locale)';
  }

  String? _normalizeLocale(String? locale) {
    final raw = locale?.trim();
    if (raw == null || raw.isEmpty) return null;
    switch (raw.toLowerCase()) {
      case 'ru':
        return 'ru-RU';
      case 'en':
        return 'en-US';
      case 'hy':
        return 'hy-AM';
      default:
        return raw;
    }
  }

  String _testPhrase(String langCode) {
    switch (langCode.toLowerCase()) {
      case 'ru':
        return 'Привет! Это проверка голоса.';
      case 'hy':
        return 'Բարև։ Սա ձայնի ստուգում է։';
      case 'en':
      default:
        return 'Hello! This is a voice test.';
    }
  }

  Future<void> _pickVoice(BuildContext context) async {
    final t = AppLocalizations.of(context);
    final s = widget.settings;

    final picked = await showModalBottomSheet<Map<String, String>?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  ListTile(
                    title: Text(
                      t?.defaultNarrationVoice ?? 'Narrator voice',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Only current language'),
                    subtitle: Text(
                      _onlyCurrentLanguage
                          ? 'Showing voices for ${s.defaultLanguageCode.toUpperCase()}'
                          : 'Showing all voices',
                    ),
                    value: _onlyCurrentLanguage,
                    onChanged: (v) {
                      setState(() => _onlyCurrentLanguage = v);
                      setModalState(() {});
                    },
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: FutureBuilder<List<Map<String, String>>>(
                      future: _voicesFuture,
                      builder: (context, snap) {
                        final all = (snap.data ?? const [])
                            .where(
                              (v) =>
                                  (v['name'] ?? '').trim().isNotEmpty &&
                                  (v['locale'] ?? '').trim().isNotEmpty,
                            )
                            .toList(growable: false);

                        final filter =
                            _normalizeLocale(s.defaultLanguageCode) ??
                            s.defaultLanguageCode;
                        final base = filter.toLowerCase().split('-').first;

                        final voices = _onlyCurrentLanguage
                            ? all
                                  .where((v) {
                                    final l = (v['locale'] ?? '').toLowerCase();
                                    return l == base || l.startsWith('$base-');
                                  })
                                  .toList(growable: false)
                            : all;

                        voices.sort((a, b) {
                          final al = (a['locale'] ?? '').compareTo(
                            b['locale'] ?? '',
                          );
                          if (al != 0) return al;
                          return (a['name'] ?? '').compareTo(b['name'] ?? '');
                        });

                        return ListView(
                          children: [
                            ListTile(
                              leading: const Icon(
                                Icons.settings_suggest_outlined,
                              ),
                              title: Text(t?.system ?? 'System'),
                              subtitle: const Text('System default'),
                              onTap: () => Navigator.of(ctx).pop(null),
                            ),
                            const Divider(height: 1),
                            if (snap.connectionState == ConnectionState.waiting)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (snap.hasError)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'Failed to load voices',
                                  style: Theme.of(ctx).textTheme.bodyMedium,
                                ),
                              )
                            else if (voices.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  _onlyCurrentLanguage
                                      ? 'No voices found for this language'
                                      : 'No voices found on this device',
                                  style: Theme.of(ctx).textTheme.bodyMedium,
                                ),
                              )
                            else
                              for (final v in voices)
                                ListTile(
                                  title: Text(v['name'] ?? ''),
                                  subtitle: Text(v['locale'] ?? ''),
                                  onTap: () => Navigator.of(ctx).pop(v),
                                ),
                            const SizedBox(height: 8),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;
    await widget.controller.setTtsVoice(picked);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    if (!s.voiceNarrationEnabled) return const SizedBox.shrink();

    final t = AppLocalizations.of(context);
    final tts = context.read<TtsService>();

    final currentVoice = s.ttsVoice;

    return Column(
      children: [
        SettingsTile(
          leading: const Icon(Icons.record_voice_over_outlined),
          title: t?.defaultNarrationVoice ?? 'Narrator voice',
          subtitle: _voiceLabel(currentVoice),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _pickVoice(context),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Volume: ${s.ttsVolume.toStringAsFixed(2)}'),
              Slider(
                value: s.ttsVolume,
                min: 0.0,
                max: 1.0,
                divisions: 20,
                onChanged: (v) => widget.controller.setTtsVolume(v),
              ),
              const SizedBox(height: 8),
              Text('Speed: ${s.ttsRate.toStringAsFixed(2)}'),
              Slider(
                value: s.ttsRate.clamp(0.1, 1.0),
                min: 0.1,
                max: 1.0,
                divisions: 18,
                onChanged: (v) => widget.controller.setTtsRate(v),
              ),
              const SizedBox(height: 8),
              Text('Intensity: ${s.ttsPitch.toStringAsFixed(2)}'),
              Slider(
                value: s.ttsPitch.clamp(0.5, 2.0),
                min: 0.5,
                max: 2.0,
                divisions: 15,
                onChanged: (v) => widget.controller.setTtsPitch(v),
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<bool>(
                valueListenable: tts.speakingListenable,
                builder: (context, speaking, _) {
                  return FilledButton.icon(
                    onPressed: () async {
                      if (speaking) {
                        await tts.stop();
                        return;
                      }
                      await tts.speak(
                        text: _testPhrase(s.defaultLanguageCode),
                        // Use UI language as a best-effort default for the test.
                        locale: s.defaultLanguageCode,
                        voice: currentVoice,
                        volume: s.ttsVolume,
                        rate: s.ttsRate,
                        pitch: s.ttsPitch,
                      );
                    },
                    icon: Icon(speaking ? Icons.stop : Icons.volume_up),
                    label: Text(speaking ? 'Stop' : 'Test voice'),
                  );
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final ok = await openTtsSettings();
                  if (!context.mounted) return;
                  if (!ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          t?.openSettingsManually ??
                              'Open system settings manually to manage voices.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.settings_outlined),
                label: Text('Open TTS settings'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
