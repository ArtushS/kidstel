import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../l10n/app_localizations.dart';

import '../../shared/settings/settings_scope.dart';
import '../story/services/story_service.dart';
import '../story/services/models/generate_story_response.dart';

class StorySetupPage extends StatefulWidget {
  const StorySetupPage({super.key});

  @override
  State<StorySetupPage> createState() => _StorySetupPageState();
}

class _StorySetupPageState extends State<StorySetupPage> {
  static const String _agentEndpoint = String.fromEnvironment(
    'STORY_AGENT_URL',
    defaultValue: 'https://llm-generateitem-fjnopublia-uc.a.run.app',
  );

  final _ideaCtrl = TextEditingController();
  final _ideaFocus = FocusNode();

  bool _isGenerating = false;

  Future<void> _warmUpIcons() async {
    final heroes = _getHeroes(context);
    final locations = _getLocations(context);

    final paths = <String>[
      ...heroes
          .where((e) => e.storagePath.isNotEmpty)
          .map((e) => e.storagePath),
      ...locations
          .where((e) => e.storagePath.isNotEmpty)
          .map((e) => e.storagePath),
    ];

    for (final p in paths) {
      try {
        final url = await FirebaseStorage.instance.ref(p).getDownloadURL();
        if (!mounted) return;
        await precacheImage(CachedNetworkImageProvider(url), context);
      } catch (_) {
        // ignore: network/config issues
      }
    }
  }

  bool _isIdeaMode = false;
  bool _isListening = false;

  List<_PickItem> _getHeroes(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return [
      _PickItem(
        id: 'hero_bear',
        title: t.heroBear,
        storagePath: 'heroes_icons/hero_bear.png',
      ),
      _PickItem(
        id: 'hero_cat',
        title: t.heroCat,
        storagePath: 'heroes_icons/hero_cat.png',
      ),
      _PickItem(
        id: 'hero_fox',
        title: t.heroFox,
        storagePath: 'heroes_icons/hero_fox.png',
      ),
      _PickItem(
        id: 'hero_rabbit',
        title: t.heroRabbit,
        storagePath: 'heroes_icons/hero_rabbit.png',
      ),
      _PickItem(
        id: 'hero_dice',
        title: t.heroDice,
        storagePath: 'heroes_icons/hero_dice.png',
      ),
      _PickItem(id: 'hero_random', title: t.heroRandom, storagePath: ''),
    ];
  }

  List<_PickItem> _getLocations(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return [
      _PickItem(
        id: 'castel',
        title: t.locationCastle,
        storagePath: 'location_icons/castel.png',
      ),
      _PickItem(
        id: 'cozy',
        title: t.locationCozyCottage,
        storagePath: 'location_icons/cozy_cottage_nest.png',
      ),
      _PickItem(
        id: 'island',
        title: t.locationFloatingIsland,
        storagePath: 'location_icons/floating_island_i.png',
      ),
      _PickItem(
        id: 'snow_castel',
        title: t.locationSnowCastle,
        storagePath: 'location_icons/snhow_castel.png',
      ),
      _PickItem(
        id: 'underwater',
        title: t.locationUnderwater,
        storagePath: 'location_icons/underwater_kingdom_i.png',
      ),
      _PickItem(id: 'loc_random', title: t.locationRandom, storagePath: ''),
    ];
  }

  List<_PickItem> _getTypes(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return [
      _PickItem(id: 'type_1', title: t.typeFriendly, storagePath: ''),
      _PickItem(id: 'type_2', title: t.typeAdventure, storagePath: ''),
      _PickItem(id: 'type_3', title: t.typeMagic, storagePath: ''),
      _PickItem(id: 'type_4', title: t.typeFunny, storagePath: ''),
      _PickItem(id: 'type_5', title: t.typeRomantic, storagePath: ''),
    ];
  }

  int _heroIndex = 0;
  int _locIndex = 0;
  int _typeIndex = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _warmUpIcons();
    });

    // Idea mode depends ONLY on (listening OR hasText)
    void recompute() {
      final hasText = _ideaCtrl.text.trim().isNotEmpty;
      if (!mounted) return;
      setState(() => _isIdeaMode = _isListening || hasText);
    }

    _ideaFocus.addListener(recompute);
    _ideaCtrl.addListener(recompute);
  }

  @override
  void dispose() {
    _ideaCtrl.dispose();
    _ideaFocus.dispose();
    super.dispose();
  }

  Future<void> _toggleVoiceInput() async {
    // MVP placeholder
    setState(() {
      _isListening = !_isListening;
      _isIdeaMode = _isListening || _ideaCtrl.text.trim().isNotEmpty;
    });

    if (_isListening) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;

      if (_ideaCtrl.text.trim().isEmpty) {
        _ideaCtrl.text =
            'A story about a little dragon who wants to be friends...';
        _ideaCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _ideaCtrl.text.length),
        );
      }

      setState(() {
        _isListening = false;
        _isIdeaMode = _ideaCtrl.text.trim().isNotEmpty;
      });
    }
  }

  void _toggleDarkMode() {
    final settings = SettingsScope.of(context);

    // If system -> make dark on tap for predictable behavior
    final current = settings.settings.themeMode;
    final next = (current == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
    settings.setThemeMode(next);
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
                // TODO: account page later
                // context.push('/account');
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

  String _mapComplexity(dynamic v) {
    final s = (v ?? '').toString().toLowerCase();

    if (s.contains('simple')) return 'simple';
    if (s.contains('normal')) return 'normal';

    // RU labels
    if (s.contains('прост')) return 'simple';
    if (s.contains('норм')) return 'normal';

    return 'normal';
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

    debugPrint('Generate pressed: entering _onGenerate()');
    debugPrint('Agent URL = $_agentEndpoint');

    final t = AppLocalizations.of(context)!;
    final idea = _ideaCtrl.text.trim();

    final heroes = _getHeroes(context);
    final locations = _getLocations(context);
    final types = _getTypes(context);

    final rawHero = heroes[_heroIndex];
    final rawLoc = locations[_locIndex];
    final rawType = types[_typeIndex];

    final hero = _resolveRandomIfNeeded(rawHero, heroes);
    final loc = _resolveRandomIfNeeded(rawLoc, locations);
    final type = rawType;

    final settings = SettingsScope.of(context).settings;

    final body = <String, dynamic>{
      'action': 'generate',
      'ageGroup': _mapAgeGroup(settings.ageGroup),
      'storyLang': settings.defaultLanguageCode,
      'storyLength': _mapStoryLength(settings.storyLength),
      'creativityLevel': _mapCreativity(settings.creativityLevel),
      'image': {'enabled': settings.autoIllustrations},
      'selection': {
        'hero': hero.title,
        'location': loc.title,
        'style': type.title,
      },
    };

    if (idea.isNotEmpty) {
      body['idea'] = idea;
    }

    final service = StoryService(endpointUrl: _agentEndpoint);

    setState(() => _isGenerating = true);

    try {
      final json = await service.callAgentJson(body);
      final resp = GenerateStoryResponse.fromJson(json);

      if (!mounted) return;

      // Pass settings to StoryReaderPage via extra
      context.push(
        '/story-reader',
        extra: {
          'response': resp,
          'ageGroup': _mapAgeGroup(settings.ageGroup),
          'lang': settings.defaultLanguageCode,
          'length': _mapStoryLength(settings.storyLength),
          'creativity': _mapCreativity(settings.creativityLevel),
          'imageEnabled': settings.autoIllustrations,
          'hero': hero.title,
          'location': loc.title,
          'style': type.title,
        },
      );
    } catch (e) {
      if (!mounted) return;

      final title = 'Generation failed';
      final msg = e.toString();

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
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

    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white70 : Colors.black54;

    final heroes = _getHeroes(context);
    final locations = _getLocations(context);
    final types = _getTypes(context);

    final hero = heroes[_heroIndex];
    final loc = locations[_locIndex];
    final type = types[_typeIndex];

    return Scaffold(
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
                      isListening: _isListening,
                      onMicTap: _toggleVoiceInput,
                      isDark: isDark,
                      hintText: t.typeYourIdea,
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _isIdeaMode
                          ? Padding(
                              key: const ValueKey('idea-msg'),
                              padding: const EdgeInsets.symmetric(vertical: 8),
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
                    ),
                    const SizedBox(height: 18),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: _isIdeaMode ? 0.35 : 1,
                      child: IgnorePointer(
                        ignoring: _isIdeaMode,
                        child: Column(
                          children: [
                            _CarouselSection(
                              title: t.hero,
                              subtitle: t.swipeToChoose,
                              height: 240,
                              items: heroes,
                              initialPage: _heroIndex,
                              onPageChanged: (i) =>
                                  setState(() => _heroIndex = i),
                              isDark: isDark,
                            ),
                            const SizedBox(height: 16),
                            _CarouselSection(
                              title: t.location,
                              subtitle: t.swipeToChoose,
                              height: 240,
                              items: locations,
                              initialPage: _locIndex,
                              onPageChanged: (i) =>
                                  setState(() => _locIndex = i),
                              isDark: isDark,
                            ),
                            const SizedBox(height: 16),
                            _CarouselSection(
                              title: t.storyType,
                              subtitle: t.swipeToChoose,
                              height: 240,
                              items: types,
                              initialPage: _typeIndex,
                              onPageChanged: (i) =>
                                  setState(() => _typeIndex = i),
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 90),
                  ],
                ),
              ),
            ),
            _BottomBar(
              enabled: _canGenerate(context) && !_isGenerating,
              onGenerate: () => _onGenerate(context),
              label: _isGenerating ? 'Generating...' : t.generate,
            ),
          ],
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
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
    return Text(
      text,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color),
    );
  }
}

class _IdeaField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isListening;
  final VoidCallback onMicTap;
  final bool isDark;
  final String hintText;

  const _IdeaField({
    required this.controller,
    required this.focusNode,
    required this.isListening,
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
            icon: Icon(
              isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
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
  final int initialPage;
  final ValueChanged<int> onPageChanged;
  final bool isDark;

  const _CarouselSection({
    required this.title,
    required this.subtitle,
    required this.height,
    required this.items,
    required this.initialPage,
    required this.onPageChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final controller = PageController(
      viewportFraction: 0.70,
      initialPage: initialPage,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 10),
            Text(
              subtitle,
              style: TextStyle(
                color: (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          ],
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
                child: _PickCard(item: items[index], isDark: isDark),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StorageImage extends StatelessWidget {
  final String storagePath;
  final double size;
  final bool isDark;
  final IconData fallbackIcon;

  const _StorageImage({
    required this.storagePath,
    required this.size,
    required this.isDark,
    required this.fallbackIcon,
  });

  static final Map<String, Future<String>> _urlFutures = {};

  Future<String> _getUrl() {
    return _urlFutures.putIfAbsent(storagePath, () {
      return FirebaseStorage.instance.ref(storagePath).getDownloadURL();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.45);

    if (storagePath.isEmpty) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: bg,
        ),
        child: Icon(fallbackIcon, size: size * 0.50),
      );
    }

    return FutureBuilder<String>(
      future: _getUrl(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: bg,
            ),
            child: const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: size,
            height: size,
            child: CachedNetworkImage(
              imageUrl: snap.data!,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: bg),
              errorWidget: (_, __, ___) => Container(
                color: bg,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
        );
      },
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
            final double imageSize = (c.maxHeight * 0.65).clamp(120.0, 160.0);

            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: random
                        ? Container(
                            width: imageSize,
                            height: imageSize,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.white.withValues(alpha: 0.45),
                            ),
                            child: Icon(
                              Icons.casino_rounded,
                              size: imageSize * 0.55,
                            ),
                          )
                        : _StorageImage(
                            storagePath: item.storagePath,
                            size: imageSize,
                            isDark: isDark,
                            fallbackIcon: Icons.auto_awesome,
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
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
  final String storagePath;

  const _PickItem({
    required this.id,
    required this.title,
    required this.storagePath,
  });

  bool get isRandom =>
      id.endsWith('_random') || id == 'hero_random' || id == 'loc_random';
}
