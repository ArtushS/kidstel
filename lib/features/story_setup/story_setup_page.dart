// lib/features/story_setup/story_setup_page.dart

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kidsdom/l10n/app_localizations.dart';

class StorySetupPage extends StatefulWidget {
  const StorySetupPage({super.key});

  @override
  State<StorySetupPage> createState() => _StorySetupPageState();
}

class _StorySetupPageState extends State<StorySetupPage> {
  // Mock data (later: Firestore / Storage + AI)
  final List<_PickItem> _heroes = const [
    _PickItem(
      id: 'hero_girl',
      titleKey: _TitleKey.heroGirl,
      imageUrl:
          'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=1200&q=80',
    ),
    _PickItem(
      id: 'hero_boy',
      titleKey: _TitleKey.heroBoy,
      imageUrl:
          'https://images.unsplash.com/photo-1519340333755-c8929bdf0d27?auto=format&fit=crop&w=1200&q=80',
    ),
    _PickItem(
      id: 'hero_robot',
      titleKey: _TitleKey.heroRobot,
      imageUrl:
          'https://images.unsplash.com/photo-1520975869018-bf09f96c2e7d?auto=format&fit=crop&w=1200&q=80',
    ),
  ];

  final List<_PickItem> _locations = const [
    _PickItem(
      id: 'loc_forest',
      titleKey: _TitleKey.locForest,
      imageUrl:
          'https://images.unsplash.com/photo-1501785888041-af3ef285b470?auto=format&fit=crop&w=1200&q=80',
    ),
    _PickItem(
      id: 'loc_city',
      titleKey: _TitleKey.locCity,
      imageUrl:
          'https://images.unsplash.com/photo-1467269204594-9661b134dd2b?auto=format&fit=crop&w=1200&q=80',
    ),
    _PickItem(
      id: 'loc_space',
      titleKey: _TitleKey.locSpace,
      imageUrl:
          'https://images.unsplash.com/photo-1446776811953-b23d57bd21aa?auto=format&fit=crop&w=1200&q=80',
    ),
  ];

  final List<_PickItem> _types = const [
    _PickItem(
      id: 'type_adventure',
      titleKey: _TitleKey.typeAdventure,
      imageUrl:
          'https://images.unsplash.com/photo-1520975661595-6453be3f7070?auto=format&fit=crop&w=1200&q=80',
    ),
    _PickItem(
      id: 'type_kindness',
      titleKey: _TitleKey.typeKindness,
      imageUrl:
          'https://images.unsplash.com/photo-1520975958225-45c3c42b48b9?auto=format&fit=crop&w=1200&q=80',
    ),
    _PickItem(
      id: 'type_funny',
      titleKey: _TitleKey.typeFunny,
      imageUrl:
          'https://images.unsplash.com/photo-1520975693410-001f4c94b57d?auto=format&fit=crop&w=1200&q=80',
    ),
  ];

  int _heroIndex = 0;
  int _locationIndex = 0;
  int _typeIndex = 0;

  bool _warmingUp = false;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_warmUpCache());
    });
  }

  Future<void> _warmUpCache() async {
    if (!mounted) return;

    setState(() => _warmingUp = true);
    try {
      final urls = <String>{
        ..._heroes.map((e) => e.imageUrl),
        ..._locations.map((e) => e.imageUrl),
        ..._types.map((e) => e.imageUrl),
      }.toList();

      for (final url in urls) {
        if (!mounted) break;
        await precacheImage(CachedNetworkImageProvider(url), context);
      }
    } catch (_) {
      // warm-up must never break UI
    } finally {
      // IMPORTANT: no "return" inside finally
      if (mounted) {
        setState(() => _warmingUp = false);
      }
    }
  }

  Future<void> _generateMockStory() async {
    if (!mounted) return;

    setState(() => _generating = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 700));

      final payload = <String, dynamic>{
        'heroId': _heroes[_heroIndex].id,
        'locationId': _locations[_locationIndex].id,
        'typeId': _types[_typeIndex].id,
      };

      if (!mounted) return;
      context.push('/reader', extra: payload);
    } finally {
      // IMPORTANT: no "return" inside finally
      if (mounted) {
        setState(() => _generating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = KidsLocalizations.of(context);
    assert(
      l10n != null,
      'KidsLocalizations is null. Check localizationsDelegates/supportedLocales.',
    );
    final t = l10n!;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.createNewStory),
        actions: [
          IconButton(
            tooltip: t.settings,
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (_warmingUp) ...[
              _InfoBanner(
                icon: Icons.cloud_download_outlined,
                text: t.loadingAssets,
              ),
              const SizedBox(height: 12),
            ],
            _SectionHeader(
              title: t.hero,
              subtitle: t.swipeToChoose,
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 10),
            _Carousel(
              items: _heroes,
              index: _heroIndex,
              onChanged: (i) => setState(() => _heroIndex = i),
              titleBuilder: (item) => _titleFor(t, item.titleKey),
            ),
            const SizedBox(height: 18),
            _SectionHeader(
              title: t.location,
              subtitle: t.swipeToChoose,
              icon: Icons.place_outlined,
            ),
            const SizedBox(height: 10),
            _Carousel(
              items: _locations,
              index: _locationIndex,
              onChanged: (i) => setState(() => _locationIndex = i),
              titleBuilder: (item) => _titleFor(t, item.titleKey),
            ),
            const SizedBox(height: 18),
            _SectionHeader(
              title: t.storyType,
              subtitle: t.swipeToChoose,
              icon: Icons.auto_stories_outlined,
            ),
            const SizedBox(height: 10),
            _Carousel(
              items: _types,
              index: _typeIndex,
              onChanged: (i) => setState(() => _typeIndex = i),
              titleBuilder: (item) => _titleFor(t, item.titleKey),
            ),
            const SizedBox(height: 20),
            _InfoBanner(
              icon: Icons.info_outline_rounded,
              text: t.storyWillBeGenerated,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _generating ? null : _generateMockStory,
                icon: _generating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(_generating ? t.generating : t.generateStory),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              t.previewHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _titleFor(KidsLocalizations t, _TitleKey key) {
    switch (key) {
      case _TitleKey.heroGirl:
        return t.heroGirl;
      case _TitleKey.heroBoy:
        return t.heroBoy;
      case _TitleKey.heroRobot:
        return t.heroRobot;
      case _TitleKey.locForest:
        return t.locationForest;
      case _TitleKey.locCity:
        return t.locationCity;
      case _TitleKey.locSpace:
        return t.locationSpace;
      case _TitleKey.typeAdventure:
        return t.typeAdventure;
      case _TitleKey.typeKindness:
        return t.typeKindness;
      case _TitleKey.typeFunny:
        return t.typeFunny;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(subtitle, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _Carousel extends StatelessWidget {
  const _Carousel({
    required this.items,
    required this.index,
    required this.onChanged,
    required this.titleBuilder,
  });

  final List<_PickItem> items;
  final int index;
  final ValueChanged<int> onChanged;
  final String Function(_PickItem) titleBuilder;

  @override
  Widget build(BuildContext context) {
    final controller = PageController(
      viewportFraction: 0.86,
      initialPage: index,
    );

    return SizedBox(
      height: 190,
      child: PageView.builder(
        controller: controller,
        onPageChanged: onChanged,
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          return AnimatedPadding(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.only(
              left: i == 0 ? 0 : 8,
              right: i == items.length - 1 ? 0 : 8,
              top: i == index ? 0 : 10,
              bottom: i == index ? 0 : 10,
            ),
            child: _CardItem(
              imageUrl: item.imageUrl,
              title: titleBuilder(item),
              selected: i == index,
            ),
          );
        },
      ),
    );
  }
}

class _CardItem extends StatelessWidget {
  const _CardItem({
    required this.imageUrl,
    required this.title,
    required this.selected,
  });

  final String imageUrl;
  final String title;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: selected ? 1.5 : 0.4,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 120),
            placeholder: (context, _) => Container(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.0),
                  Colors.black.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (selected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

enum _TitleKey {
  heroGirl,
  heroBoy,
  heroRobot,
  locForest,
  locCity,
  locSpace,
  typeAdventure,
  typeKindness,
  typeFunny,
}

class _PickItem {
  const _PickItem({
    required this.id,
    required this.titleKey,
    required this.imageUrl,
  });

  final String id;
  final _TitleKey titleKey;
  final String imageUrl;
}
