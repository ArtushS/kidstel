import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/ui/ui_constants.dart';
import '../../shared/voice/voice_input_controller.dart';
import '../../shared/voice/open_system_settings.dart';

import '../../shared/settings/settings_scope.dart';
import '../../shared/models/story_setup.dart';
import '../../shared/models/story_setup_catalog_item.dart';
import '../../shared/widgets/network_icon.dart';
import '../../services/story_setup_catalog_repository.dart';
import '../story/services/story_service.dart';
import '../story/services/models/generate_story_response.dart';

class StorySetupPage extends StatefulWidget {
  const StorySetupPage({super.key});

  @override
  State<StorySetupPage> createState() => _StorySetupPageState();
}

class _StorySetupPageState extends State<StorySetupPage> {
  // IMPORTANT: must be HTTPS. Replace with your own hosted asset if needed.
  // This is a public CDN URL (Twemoji). For production, prefer hosting the
  // dice icon in your own Firebase Storage and using its https download URL.
  static const String _diceIconUrl =
      'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f3b2.png';

  final _ideaCtrl = TextEditingController();
  final _ideaFocus = FocusNode();

  // Keep page stable while typing/dictating: avoid full-page rebuilds.
  final ValueNotifier<bool> _listeningVN = ValueNotifier(false);
  final ValueNotifier<bool> _ideaModeVN = ValueNotifier(false);
  // Debug-only locale tracking (kept for internal diagnostics; not shown in UI).
  // ignore: unused_field
  final ValueNotifier<String> _activeLocaleVN = ValueNotifier('');

  bool _isGenerating = false;

  final _catalogRepo = StorySetupCatalogRepository();

  String? _lastCatalogLocaleTag;

  List<StorySetupCatalogItem> _heroCatalog = const <StorySetupCatalogItem>[];
  List<StorySetupCatalogItem> _locationCatalog =
      const <StorySetupCatalogItem>[];
  List<StorySetupCatalogItem> _typeCatalog = const <StorySetupCatalogItem>[];

  Future<void> _loadCatalogs(Locale locale) async {
    try {
      if (kDebugMode) {
        debugPrint(
          '[StorySetupPage] loading catalogs for locale=${locale.toLanguageTag()}…',
        );
      }

      final heroes = await _catalogRepo.loadHeroes(locale: locale);
      final locations = await _catalogRepo.loadLocations(locale: locale);
      final types = await _catalogRepo.loadTypes(locale: locale);

      if (kDebugMode) {
        debugPrint(
          '[StorySetupPage] catalogs loaded: heroes=${heroes.length} locations=${locations.length} types=${types.length}',
        );
      }

      if (kDebugMode && heroes.isEmpty && locations.isEmpty && types.isEmpty) {
        debugPrint(
          '[StorySetupPage] catalogs are empty in Firestore; using built-in fallback items (Storage paths) so carousels are usable.',
        );
      }

      if (!mounted) return;
      setState(() {
        _heroCatalog = heroes;
        _locationCatalog = locations;
        _typeCatalog = types;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[StorySetupPage] catalog load FAILED: $e');
      }
    }
  }

  Future<void> _warmUpIcons() async {
    // Intentionally empty: we avoid eager icon prefetching.
    // - prevents early Storage reads (403/AppCheck)
    // - avoids surfacing decode errors during warm-up
  }

  VoiceInputController? _voice;
  String? _lastAppLangCode;
  String? _lastShownVoiceWarning;
  bool _prevListening = false;
  bool _skipNextAutoCommit = false;

  List<_PickItem> _getHeroes(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    final heroName = SettingsScope.of(context).settings.heroName?.trim() ?? '';
    final boyTitle = heroName.isNotEmpty ? heroName : t.heroBoy;

    final out = <_PickItem>[
      _PickItem(id: 'hero_random', title: t.heroRandom, iconUrl: _diceIconUrl),
    ];

    if (_heroCatalog.isNotEmpty) {
      out.addAll(
        _heroCatalog.map(
          (e) => _PickItem(id: e.id, title: e.name, iconUrl: e.iconUrl),
        ),
      );
      return out;
    }

    // Built-in fallback (works even when Firestore is not seeded).
    out.addAll([
      _PickItem(
        id: 'hero_boy',
        title: boyTitle,
        iconUrl: 'heroes_icons/boy.png',
      ),
      _PickItem(
        id: 'hero_girl',
        title: t.heroGirl,
        iconUrl: 'heroes_icons/girl.png',
      ),
      _PickItem(
        id: 'hero_dog',
        title: t.heroDog,
        iconUrl: 'heroes_icons/dog.png',
      ),
      _PickItem(
        id: 'hero_cat',
        title: t.heroCat,
        iconUrl: 'heroes_icons/cat.png',
      ),
      _PickItem(
        id: 'hero_bear',
        title: t.heroBear,
        iconUrl: 'heroes_icons/bear.png',
      ),
      _PickItem(
        id: 'hero_fox',
        title: t.heroFox,
        iconUrl: 'heroes_icons/fox.png',
      ),
      _PickItem(
        id: 'hero_rabbit',
        title: t.heroRabbit,
        iconUrl: 'heroes_icons/rabbit.png',
      ),
    ]);

    return out;
  }

  List<_PickItem> _getLocations(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    final out = <_PickItem>[
      _PickItem(
        id: 'loc_random',
        title: t.randomLocationLabel,
        iconUrl: _diceIconUrl,
      ),
    ];

    if (_locationCatalog.isNotEmpty) {
      out.addAll(
        _locationCatalog.map(
          (e) => _PickItem(id: e.id, title: e.name, iconUrl: e.iconUrl),
        ),
      );
      return out;
    }

    // Built-in fallback (best-effort mapping to known Storage icons).
    out.addAll([
      _PickItem(
        id: 'loc_castle',
        title: t.locationCastle,
        iconUrl: 'location_icons/palace.png',
      ),
      _PickItem(
        id: 'loc_cozy',
        title: t.locationCozyCottage,
        iconUrl: 'location_icons/forest.png',
      ),
      _PickItem(
        id: 'loc_island',
        title: t.locationFloatingIsland,
        iconUrl: 'location_icons/space.png',
      ),
      _PickItem(
        id: 'loc_snow_castle',
        title: t.locationSnowCastle,
        iconUrl: 'location_icons/snow_castle.png',
      ),
      _PickItem(
        id: 'loc_underwater',
        title: t.locationUnderwater,
        iconUrl: 'location_icons/space.png',
      ),
    ]);

    return out;
  }

  List<_PickItem> _getTypes(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    final out = <_PickItem>[
      _PickItem(
        id: 'type_random',
        // No dedicated i18n key for "random type" yet.
        title: t.randomStyleLabel,
        iconUrl: _diceIconUrl,
      ),
    ];

    if (_typeCatalog.isNotEmpty) {
      out.addAll(
        _typeCatalog.map(
          (e) => _PickItem(id: e.id, title: e.name, iconUrl: e.iconUrl),
        ),
      );
      return out;
    }

    // Built-in fallback.
    out.addAll([
      _PickItem(
        id: 'type_friendly',
        title: t.typeFriendly,
        iconUrl: 'styl_icons/friendship.png',
      ),
      _PickItem(
        id: 'type_adventure',
        title: t.typeAdventure,
        iconUrl: 'styl_icons/compas.png',
      ),
      _PickItem(
        id: 'type_magic',
        title: t.typeMagic,
        iconUrl: 'styl_icons/magic.png',
      ),
      _PickItem(
        id: 'type_funny',
        title: t.typeFunny,
        iconUrl: 'styl_icons/funny.png',
      ),
      _PickItem(
        id: 'type_romantic',
        title: t.typeRomantic,
        iconUrl: 'styl_icons/friendship.png',
      ),
    ]);

    return out;
  }

  int _heroIndex = 0;
  int _locIndex = 0;
  int _typeIndex = 0;

  late final PageController _heroController;
  late final PageController _locController;
  late final PageController _typeController;

  @override
  void initState() {
    super.initState();

    _heroController = PageController(
      viewportFraction: kCarouselViewportFraction,
      initialPage: _heroIndex,
    );
    _locController = PageController(
      viewportFraction: kCarouselViewportFraction,
      initialPage: _locIndex,
    );
    _typeController = PageController(
      viewportFraction: kCarouselViewportFraction,
      initialPage: _typeIndex,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _warmUpIcons();
    });

    // Idea mode depends ONLY on (listening OR hasText) without setState.
    void recomputeIdeaMode() {
      final hasText = _ideaCtrl.text.trim().isNotEmpty;
      _ideaModeVN.value = _listeningVN.value || hasText;
    }

    _ideaCtrl.addListener(recomputeIdeaMode);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Reload story-setup catalogs when locale changes (titles are localized).
    final locale = Localizations.localeOf(context);
    final tag = locale.toLanguageTag();
    if (_lastCatalogLocaleTag != tag) {
      _lastCatalogLocaleTag = tag;
      // Non-blocking.
      _loadCatalogs(locale);
    }

    final appLang = SettingsScope.of(context).settings.defaultLanguageCode;
    final next = context.read<VoiceInputController>();
    if (!identical(_voice, next)) {
      _voice?.removeListener(_onVoiceChanged);
      _voice = next;
      _voice!.addListener(_onVoiceChanged);
      // Sync immediately.
      _onVoiceChanged();
    }

    // Keep STT language in sync with app UI language.
    // If user switches UI language while listening, controller will cancel.
    // Next mic start will use the resolved locale for the new language.
    if (_lastAppLangCode == null || _lastAppLangCode != appLang) {
      if (kDebugMode) {
        debugPrint('STT: app language changed $_lastAppLangCode -> $appLang');
      }
      _voice?.setDesiredAppLang(appLang);
    }

    _lastAppLangCode = appLang;
  }

  @override
  void dispose() {
    _heroController.dispose();
    _locController.dispose();
    _typeController.dispose();
    _voice?.removeListener(_onVoiceChanged);
    _voice?.cancel();
    _ideaCtrl.dispose();
    _ideaFocus.dispose();
    _listeningVN.dispose();
    _ideaModeVN.dispose();
    _activeLocaleVN.dispose();
    super.dispose();
  }

  void _onVoiceChanged() {
    if (!mounted) return;
    final voice = _voice;
    if (voice == null) return;

    // Only react to listening transitions (avoid per-partial updates).
    final nowListening = voice.isListening;
    if (_prevListening != nowListening) {
      _listeningVN.value = nowListening;

      // Auto-stop commit: when listening ends, insert best available text into the field.
      if (_prevListening && !nowListening) {
        if (_skipNextAutoCommit) {
          _skipNextAutoCommit = false;
        } else {
          // Allow a tiny grace period for late final results.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_voice?.isListening == false) {
              _commitFinalTextIntoIdeaField();
            }
          });
        }
      }

      _prevListening = nowListening;

      // Keep idea mode updated without rebuilding the full page.
      final hasText = _ideaCtrl.text.trim().isNotEmpty;
      _ideaModeVN.value = nowListening || hasText;
    }

    final nextLocale = voice.activeLocaleId;
    if (_activeLocaleVN.value != nextLocale) {
      _activeLocaleVN.value = nextLocale;
    }
  }

  void _insertIntoIdeaAtCursor(String insert) {
    if (insert.isEmpty) return;

    final text = _ideaCtrl.text;
    final sel = _ideaCtrl.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;

    final before = text.substring(0, start);
    final after = text.substring(end);
    final newText = before + insert + after;

    _ideaCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: (before + insert).length),
    );

    FocusScope.of(context).requestFocus(_ideaFocus);
  }

  void _commitFinalTextIntoIdeaField() {
    final voice = _voice;
    if (voice == null) return;

    final recognized = voice.consumeBestResult().trim();
    if (kDebugMode) {
      final head = recognized.characters.take(18).toString();
      debugPrint('STT commit: len=${recognized.length} head="$head"');
    }
    if (recognized.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.sttNoResults),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    _insertIntoIdeaAtCursor(recognized);
  }

  void _toggleDarkMode() {
    final settings = SettingsScope.of(context);

    // If system -> make dark on tap for predictable behavior
    final current = settings.settings.themeMode;
    final next = (current == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
    settings.setThemeMode(next);
  }

  Future<void> _showArmenianVoiceHelpDialog() async {
    final t = AppLocalizations.of(context)!;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(t.voiceNotAvailable),
          content: Text(
            '${t.voiceNotAvailableHyMessage}\n\n${t.voiceHelpSteps}',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final ok = await openAppSettings();
                if (!ctx.mounted) return;
                if (!ok) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(t.openSettingsManually)),
                  );
                }
              },
              child: Text(t.openSettings),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(t.ok),
            ),
          ],
        );
      },
    );
  }

  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: Text(AppLocalizations.of(context)!.account),
              onTap: () {
                Navigator.pop(context);
                context.push('/account');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(AppLocalizations.of(context)!.settings),
              onTap: () {
                Navigator.pop(context);
                context.push('/settings'); // push, not go
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _canGenerate(BuildContext context) {
    final hasIdea = _ideaCtrl.text.trim().isNotEmpty;
    final heroes = _getHeroes(context);
    final locations = _getLocations(context);
    final types = _getTypes(context);
    final hasPicks =
        heroes.isNotEmpty && locations.isNotEmpty && types.isNotEmpty;
    return hasIdea || hasPicks;
  }

  _PickItem _resolveRandomIfNeeded(_PickItem picked, List<_PickItem> list) {
    if (!picked.isRandom) return picked;

    final pool = list.where((e) => !e.isRandom).toList(growable: false);
    if (pool.isEmpty) return picked;

    final r = Random();
    return pool[r.nextInt(pool.length)];
  }

  String _mapAgeGroup(dynamic v) {
    final s = (v ?? '').toString().toLowerCase();

    // supports: "3-5", "3_5", "age3to5", etc.
    if (s.contains('3') && (s.contains('5') || s.contains('5'))) return '3_5';
    if (s.contains('6') && s.contains('8')) return '6_8';
    if (s.contains('9') && s.contains('12')) return '9_12';

    // default
    return '3_5';
  }

  String _mapStoryLength(dynamic v) {
    final s = (v ?? '').toString().toLowerCase();

    if (s.contains('short')) return 'short';
    if (s.contains('medium')) return 'medium';
    if (s.contains('long')) return 'long';

    // RU labels (if stored as strings)
    if (s.contains('корот')) return 'short';
    if (s.contains('сред')) return 'medium';
    if (s.contains('длин')) return 'long';

    return 'medium';
  }

  double _mapCreativity(dynamic v) {
    final s = (v ?? '').toString().toLowerCase();

    if (s.contains('low')) return 0.35;
    if (s.contains('normal')) return 0.65;
    if (s.contains('high')) return 0.9;

    // RU labels
    if (s.contains('низ')) return 0.35;
    if (s.contains('норм')) return 0.65;
    if (s.contains('выс')) return 0.9;

    // If stored as number (0..1 or 1..10)
    final n = double.tryParse(s);
    if (n != null) {
      if (n <= 1.0) return n.clamp(0.0, 1.0);
      // assume 1..10
      return (n / 10.0).clamp(0.0, 1.0);
    }

    return 0.65;
  }

  Future<void> _onGenerate(BuildContext context) async {
    if (!_canGenerate(context)) return;

    // IMPORTANT: send only the editable TextField content (never preview/buffer).
    final ideaText = _ideaCtrl.text.trim();

    final heroes = _getHeroes(context);
    final locations = _getLocations(context);
    final types = _getTypes(context);

    final rawHero = heroes[_heroIndex];
    final rawLoc = locations[_locIndex];
    final rawType = types[_typeIndex];

    final hero = _resolveRandomIfNeeded(rawHero, heroes);
    final loc = _resolveRandomIfNeeded(rawLoc, locations);
    final type = _resolveRandomIfNeeded(rawType, types);

    final settings = SettingsScope.of(context).settings;

    // Data-only setup object (for passing around / persistence later).
    // IMPORTANT: no service instances are passed through navigation.
    final setup = StorySetup(
      service: 'cloud-run',
      ageGroup: _mapAgeGroup(settings.ageGroup),
      storyLang: settings.defaultLanguageCode,
      storyLength: _mapStoryLength(settings.storyLength),
      creativityLevel: _mapCreativity(settings.creativityLevel),
      imageEnabled: settings.autoIllustrations,
      hero: hero.title,
      location: loc.title,
      storyType: type.title,
      idea: ideaText.isNotEmpty ? ideaText : null,
    );

    final body = <String, dynamic>{
      'action': 'generate',
      'ageGroup': setup.ageGroup,
      'storyLang': setup.storyLang,
      'storyLength': setup.storyLength,
      'creativityLevel': setup.creativityLevel,
      'image': {'enabled': setup.imageEnabled},
      'selection': {
        'hero': setup.hero,
        'location': setup.location,
        // Backend contract currently expects selection.style.
        // We map storyType -> style to avoid breaking the server while keeping
        // only ONE type selector in the UI.
        'style': setup.storyType,
      },
    };

    final idea = setup.idea?.trim();
    if (idea != null && idea.isNotEmpty) {
      body['idea'] = idea;
    }

    final service = context.read<StoryService>();

    setState(() => _isGenerating = true);

    try {
      final json = await service.callAgentJson(body);
      final resp = GenerateStoryResponse.fromJson(json);

      if (!context.mounted) return;

      // Pass settings to StoryReaderPage via extra
      context.push(
        '/story-reader',
        extra: {
          'response': resp,
          // Keep existing keys for compatibility with router parsing.
          'ageGroup': setup.ageGroup,
          'lang': setup.storyLang,
          'length': setup.storyLength,
          'creativity': setup.creativityLevel,
          'imageEnabled': setup.imageEnabled,
          'hero': setup.hero,
          'location': setup.location,
          'storyType': setup.storyType,
          // Bonus: pass the full data-only setup (including idea) for later use.
          'setup': setup,
        },
      );
    } catch (e) {
      if (!context.mounted) return;

      final title = AppLocalizations.of(context)!.generationFailedTitle;
      final msg = e.toString();

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.ok),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/'); // Home
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = AppLocalizations.of(context)!;

    // Avoid watching VoiceInputController in build: it would rebuild the whole page
    // on every partial result. We update only small UI parts via ValueNotifiers.
    final voice = context.read<VoiceInputController>();

    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white70 : Colors.black54;

    final heroes = _getHeroes(context);
    final locations = _getLocations(context);
    final types = _getTypes(context);

    // Defensive: catalogs can refresh asynchronously.
    _heroIndex = _heroIndex.clamp(0, max(0, heroes.length - 1));
    _locIndex = _locIndex.clamp(0, max(0, locations.length - 1));
    _typeIndex = _typeIndex.clamp(0, max(0, types.length - 1));

    final hero = heroes[_heroIndex];
    final loc = locations[_locIndex];
    final type = types[_typeIndex];

    // NOTE: we intentionally do NOT auto-jump away from the Random card.
    // Users must be able to come back to Random after picking a concrete item.
    // The actual random resolution happens on Generate via _resolveRandomIfNeeded.

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                title: t.createNewStory,
                onBack: _handleBack,
                onMenu: _openMenu,
                onToggleDark: _toggleDarkMode,
                isDark: isDark,
                titleColor: textPrimary,
                iconColor: textPrimary,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(t.describeYourIdea, color: textPrimary),
                      const SizedBox(height: 10),
                      _IdeaField(
                        controller: _ideaCtrl,
                        focusNode: _ideaFocus,
                        isListeningListenable: _listeningVN,
                        onMicTap: () async {
                          final langCode = SettingsScope.of(
                            context,
                          ).settings.defaultLanguageCode;

                          if (!voice.isListening) {
                            // Always start using app UI language (EN/RU/HY).
                            await voice.startForAppLang(appLangCode: langCode);
                            if (!context.mounted) return;

                            // If we fell back to system locale for RU/HY, show a short help.
                            final warn = voice.warning?.trim();
                            if (warn != null &&
                                warn.isNotEmpty &&
                                warn != _lastShownVoiceWarning) {
                              _lastShownVoiceWarning = warn;
                              final t = AppLocalizations.of(context)!;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(warn),
                                  duration: const Duration(seconds: 6),
                                  action: SnackBarAction(
                                    label: t.openSettings,
                                    onPressed: () {
                                      openAppSettings();
                                    },
                                  ),
                                ),
                              );
                              voice.clearWarning();
                            }

                            if (kDebugMode) {
                              final active = voice.activeLocaleId.toLowerCase();
                              if (langCode == 'ru' &&
                                  !active.startsWith('ru')) {
                                debugPrint(
                                  'STT debug: appLang=ru but activeLocale=${voice.activeLocaleId}',
                                );
                              }
                              if (langCode == 'hy' &&
                                  !active.startsWith('hy')) {
                                debugPrint(
                                  'STT debug: appLang=hy but activeLocale=${voice.activeLocaleId}',
                                );
                              }
                            }

                            final err = voice.error;
                            if (err != null && err.trim().isNotEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(err),
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                            return;
                          }

                          // Manual stop: stop listening and insert recognized text at cursor.
                          _skipNextAutoCommit = true;
                          await voice.stop();
                          _commitFinalTextIntoIdeaField();
                        },
                        isDark: isDark,
                        hintText: t.typeYourIdea,
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            t.ttsSystemLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: textSecondary),
                          ),
                        ),
                      ),

                      // Inline help link near the mic (Armenian UI only).
                      if (SettingsScope.of(
                            context,
                          ).settings.defaultLanguageCode ==
                          'hy')
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showArmenianVoiceHelpDialog,
                            child: Text(
                              t.voiceHelpWhatIsThis,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      ValueListenableBuilder<bool>(
                        valueListenable: _ideaModeVN,
                        builder: (context, isIdeaMode, _) {
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: isIdeaMode
                                ? Padding(
                                    key: const ValueKey('idea-msg'),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      t.storyGeneratedFromIdea,
                                      style: TextStyle(
                                        color: textSecondary,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  )
                                : _SelectedChips(
                                    key: const ValueKey('chips'),
                                    hero: hero,
                                    loc: loc,
                                    type: type,
                                    isDark: isDark,
                                  ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      ValueListenableBuilder<bool>(
                        valueListenable: _ideaModeVN,
                        child: Column(
                          children: [
                            _CarouselSection(
                              title: t.hero,
                              subtitle: t.swipeToChoose,
                              height: 240,
                              items: heroes,
                              controller: _heroController,
                              onPageChanged: (i) {
                                setState(() => _heroIndex = i);
                              },
                              isDark: isDark,
                            ),
                            const SizedBox(height: 16),
                            _CarouselSection(
                              title: t.location,
                              subtitle: t.swipeToChoose,
                              height: 240,
                              items: locations,
                              controller: _locController,
                              onPageChanged: (i) {
                                setState(() => _locIndex = i);
                              },
                              isDark: isDark,
                            ),
                            const SizedBox(height: 16),
                            _CarouselSection(
                              title: t.storyType,
                              subtitle: t.swipeToChoose,
                              height: 240,
                              items: types,
                              controller: _typeController,
                              onPageChanged: (i) {
                                setState(() => _typeIndex = i);
                              },
                              isDark: isDark,
                            ),
                          ],
                        ),
                        builder: (context, isIdeaMode, child) {
                          return AnimatedOpacity(
                            duration: const Duration(milliseconds: 180),
                            opacity: isIdeaMode ? 0.35 : 1,
                            child: IgnorePointer(
                              ignoring: isIdeaMode,
                              child: child,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 90),
                    ],
                  ),
                ),
              ),
              _BottomBar(
                enabled: _canGenerate(context) && !_isGenerating,
                onGenerate: () => _onGenerate(context),
                label: _isGenerating ? t.generating : t.generate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------------- UI building blocks ---------------- */

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onMenu;
  final VoidCallback onToggleDark;
  final bool isDark;
  final String title;
  final Color titleColor;
  final Color iconColor;

  const _TopBar({
    required this.onBack,
    required this.onMenu,
    required this.onToggleDark,
    required this.isDark,
    required this.title,
    required this.titleColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: iconColor),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: (theme.textTheme.titleMedium ?? const TextStyle())
                  .copyWith(fontWeight: FontWeight.w600, color: titleColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context)!.toggleDarkMode,
            onPressed: onToggleDark,
            icon: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: iconColor,
            ),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context)!.menu,
            onPressed: onMenu,
            icon: Icon(Icons.menu_rounded, color: iconColor),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionTitle(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: (theme.textTheme.titleSmall ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}

class _IdeaField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueListenable<bool> isListeningListenable;
  final VoidCallback onMicTap;
  final bool isDark;
  final String hintText;

  const _IdeaField({
    required this.controller,
    required this.focusNode,
    required this.isListeningListenable,
    required this.onMicTap,
    required this.isDark,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF6F0E6);
    final shadowDark = isDark
        ? Colors.black.withValues(alpha: 0.6)
        : const Color(0xFFD8CFC2);
    final shadowLight = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFFFFFFF);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: shadowLight,
            offset: const Offset(-6, -6),
            blurRadius: 12,
          ),
          BoxShadow(
            color: shadowDark,
            offset: const Offset(6, 6),
            blurRadius: 12,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context)!.voiceInput,
            onPressed: onMicTap,
            icon: ValueListenableBuilder<bool>(
              valueListenable: isListeningListenable,
              builder: (context, listening, _) {
                return Icon(
                  listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final bool enabled;
  final VoidCallback onGenerate;
  final String label;

  const _BottomBar({
    required this.enabled,
    required this.onGenerate,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton.icon(
            onPressed: enabled ? onGenerate : null,
            icon: const Icon(Icons.auto_awesome),
            label: Text(
              label,
              style: (theme.textTheme.labelLarge ?? const TextStyle()).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedChips extends StatelessWidget {
  final _PickItem hero;
  final _PickItem loc;
  final _PickItem type;
  final bool isDark;

  const _SelectedChips({
    super.key,
    required this.hero,
    required this.loc,
    required this.type,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MiniChip(icon: '🧸', text: hero.title, isDark: isDark),
        _MiniChip(icon: '📍', text: loc.title, isDark: isDark),
        _MiniChip(icon: '✨', text: type.title, isDark: isDark),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String icon;
  final String text;
  final bool isDark;

  const _MiniChip({
    required this.icon,
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.35),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: theme.textTheme.titleSmall),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (theme.textTheme.labelLarge ?? const TextStyle()).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CarouselSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final double height;
  final List<_PickItem> items;
  final PageController controller;
  final ValueChanged<int> onPageChanged;
  final bool isDark;

  const _CarouselSection({
    required this.title,
    required this.subtitle,
    required this.height,
    required this.items,
    required this.controller,
    required this.onPageChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // PageController is owned by the parent state so we can programmatically
    // jump/animate when user selects the Random (dice) card.

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // i18n-safe header: Armenian strings can be long. Keep layout stable by
        // avoiding a tight Row that can overflow.
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (theme.textTheme.titleSmall ?? const TextStyle()).copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: (isDark ? Colors.white70 : Colors.black54)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: height,
          child: PageView.builder(
            controller: controller,
            itemCount: items.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: controller,
                builder: (context, child) {
                  double t = 1.0;
                  if (controller.position.haveDimensions) {
                    final page =
                        controller.page ?? controller.initialPage.toDouble();
                    t = (1 - ((page - index).abs() * 0.18)).clamp(0.84, 1.0);
                  }
                  return Transform.scale(scale: t, child: child);
                },
                child: Center(
                  child: SizedBox(
                    // Fixed item width (universal rule for horizontal carousels)
                    // so long localized text cannot change layout.
                    width: kCarouselItemWidth,
                    child: _PickCard(item: items[index], isDark: isDark),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PickCard extends StatelessWidget {
  final _PickItem item;
  final bool isDark;

  const _PickCard({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF6F0E6);
    final shadowDark = isDark
        ? Colors.black.withValues(alpha: 0.6)
        : const Color(0xFFD8CFC2);
    final shadowLight = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFFFFFFF);

    final bool random = item.isRandom;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: random
              ? (isDark ? const Color(0xFF232323) : const Color(0xFFF2E9DA))
              : bg,
          borderRadius: BorderRadius.circular(22),
          border: random
              ? Border.all(
                  color: (isDark
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.black.withValues(alpha: 0.10)),
                  width: 1.2,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: shadowLight,
              offset: const Offset(-6, -6),
              blurRadius: 12,
            ),
            BoxShadow(
              color: shadowDark,
              offset: const Offset(6, 6),
              blurRadius: 12,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: LayoutBuilder(
          builder: (context, c) {
            // Defensive sizing: the card may be inside a horizontal PageView with a
            // fixed width. Keep the image square within available constraints.
            final maxSquare = min(c.maxWidth, c.maxHeight);
            final double imageSize = (maxSquare * 0.90)
                .clamp(56.0, maxSquare)
                .toDouble();

            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: item.id == 'loc_random'
                        ? Container(
                            width: imageSize,
                            height: imageSize,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.white.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                size: (imageSize * 0.55).clamp(22.0, 56.0),
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.92)
                                    : Colors.black.withValues(alpha: 0.75),
                              ),
                            ),
                          )
                        : NetworkIcon(
                            item.iconUrl,
                            size: imageSize,
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.white.withValues(alpha: 0.45),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PickItem {
  final String id;
  final String title;
  final String iconUrl;

  const _PickItem({
    required this.id,
    required this.title,
    required this.iconUrl,
  });

  bool get isRandom => id.endsWith('_random');
}
