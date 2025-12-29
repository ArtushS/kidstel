import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../story/models/story_state.dart';
import '../story/repositories/story_repository.dart';
import 'premade_stories.dart';

class MyStoriesPage extends StatefulWidget {
  const MyStoriesPage({super.key});

  @override
  State<MyStoriesPage> createState() => _MyStoriesPageState();
}

class _MyStoriesPageState extends State<MyStoriesPage> {
  late Future<void> _load;
  List<_StoryItem> _userStories = const [];
  List<_StoryItem> _premadeStories = const [];

  bool _isPremadeId(String id) => id.trim().startsWith('premade_');

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  void initState() {
    super.initState();
    _load = _reload();
  }

  Future<void> _reload() async {
    final repo = context.read<StoryRepository>();
    final stories = await repo.listAll();

    final savedById = <String, StoryState>{
      for (final s in stories) s.storyId: s,
    };

    final user = stories
        .where((s) => s.storyId.trim().isNotEmpty)
        .where((s) => !_isPremadeId(s.storyId))
        .map(_StoryItem.fromState)
        .toList(growable: false);

    final premade = premadeStories
        .map((p) {
          final saved = savedById[p.id];
          if (saved != null) {
            return _StoryItem.fromState(saved, forcedTitle: p.title);
          }

          return _StoryItem(
            id: p.id,
            title: p.title,
            preview: p.description,
            isFinished: true,
            progress: 1.0,
            updated: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            chapterCount: 1,
            thumbnailSource: null,
            isPremade: true,
          );
        })
        .toList(growable: false);

    setState(() {
      _userStories = user;
      _premadeStories = premade;
    });
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.myStories),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
        ),
        body: FutureBuilder<void>(
          future: _load,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final hasAny =
                _userStories.isNotEmpty || _premadeStories.isNotEmpty;
            if (!hasAny) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(t.noStoryYet),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                children: [
                  if (_userStories.isNotEmpty) ...[
                    _SectionHeader(title: t.myStories),
                    const SizedBox(height: 8),
                    for (final s in _userStories) ...[
                      _StoryEntry(
                        item: s,
                        dateLabel: _formatDate(s.updated),
                        onTap: () => context.push(
                          '/story-reader',
                          extra: <String, dynamic>{'storyId': s.id},
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 14),
                  ],
                  _SectionHeader(title: 'Ready-made stories'),
                  const SizedBox(height: 8),
                  for (final s in _premadeStories) ...[
                    _StoryEntry(
                      item: s,
                      dateLabel: s.updated.year <= 1971
                          ? null
                          : _formatDate(s.updated),
                      onTap: () => context.push(
                        '/story-reader',
                        extra: <String, dynamic>{
                          'response': premadeStories
                              .firstWhere((p) => p.id == s.id)
                              .initial,
                          'lang': premadeStories
                              .firstWhere((p) => p.id == s.id)
                              .lang,
                          'ageGroup': '3_5',
                          'length': 'short',
                          'creativity': 0.5,
                          'imageEnabled': true,
                          'hero': '',
                          'location': '',
                          'style': '',
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StoryItem {
  final String id;
  final String title;
  final bool isFinished;
  final double progress;
  final DateTime updated;
  final int chapterCount;
  final String preview;
  final String? thumbnailSource;
  final bool isPremade;

  const _StoryItem({
    required this.id,
    required this.title,
    required this.isFinished,
    required this.progress,
    required this.updated,
    required this.chapterCount,
    required this.preview,
    required this.thumbnailSource,
    required this.isPremade,
  });

  factory _StoryItem.fromState(StoryState s, {String? forcedTitle}) {
    final last = s.chapters.isNotEmpty ? s.chapters.last : null;
    final title = (forcedTitle ?? s.title).trim();
    final fallbackTitle = s.storyId.trim().isEmpty ? 'Story' : s.storyId;
    final previewText = (last?.text ?? '').trim();
    final preview = previewText.isNotEmpty
        ? previewText
        : ' '; // keep ListTile layout stable

    final thumb = s.illustrationUrl?.trim().isNotEmpty == true
        ? s.illustrationUrl!.trim()
        : last?.imageUrl?.trim();

    return _StoryItem(
      id: s.storyId,
      title: title.isEmpty ? fallbackTitle : title,
      isFinished: s.isFinished,
      progress: last?.progress ?? 0.0,
      updated: s.lastUpdated,
      chapterCount: s.chapters.length,
      preview: preview,
      thumbnailSource: (thumb != null && thumb.trim().isNotEmpty)
          ? thumb.trim()
          : null,
      isPremade: s.storyId.trim().startsWith('premade_'),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StoryEntry extends StatelessWidget {
  final _StoryItem item;
  final String? dateLabel;
  final VoidCallback onTap;

  const _StoryEntry({
    required this.item,
    required this.dateLabel,
    required this.onTap,
  });

  String _statusLabel() {
    if (item.chapterCount == 0) return 'Ready';
    if (!item.isFinished) return 'Continue';
    return 'Read Again';
  }

  Color _statusBg(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (item.chapterCount == 0) return cs.surfaceContainerHighest;
    if (!item.isFinished) return cs.primaryContainer;
    return cs.secondaryContainer;
  }

  Color _statusFg(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (item.chapterCount == 0) return cs.onSurfaceVariant;
    if (!item.isFinished) return cs.onPrimaryContainer;
    return cs.onSecondaryContainer;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String previewOneLine(String s) {
      final oneLine = s.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (oneLine.isEmpty) return '';
      return oneLine.length <= 90 ? oneLine : '${oneLine.substring(0, 90)}…';
    }

    return Card(
      child: ListTile(
        leading: _StoryThumbnail(
          source: item.thumbnailSource,
          isPremade: item.isPremade,
        ),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.preview.trim().isNotEmpty)
              Text(
                previewOneLine(item.preview),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (dateLabel != null) ...[
              const SizedBox(height: 2),
              Text(
                dateLabel!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _statusBg(context),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _statusLabel(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: _statusFg(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _StoryThumbnail extends StatelessWidget {
  final String? source;
  final bool isPremade;

  const _StoryThumbnail({required this.source, required this.isPremade});

  bool _isHttpUrl(String s) =>
      s.startsWith('http://') || s.startsWith('https://');
  bool _isGsUrl(String s) => s.startsWith('gs://');

  Future<String> _resolve(String s) async {
    final v = s.trim();
    if (v.isEmpty) return '';
    if (_isHttpUrl(v)) return v;

    final storage = FirebaseStorage.instance;
    if (_isGsUrl(v)) {
      return storage.refFromURL(v).getDownloadURL();
    }

    return storage.ref(v).getDownloadURL();
  }

  @override
  Widget build(BuildContext context) {
    final s = (source ?? '').trim();
    final size = 44.0;

    if (s.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: size,
          height: size,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            isPremade ? Icons.auto_stories_outlined : Icons.menu_book_outlined,
            size: 22,
          ),
        ),
      );
    }

    return FutureBuilder<String>(
      future: _resolve(s),
      builder: (context, snap) {
        final url = (snap.data ?? '').trim();
        if (snap.connectionState == ConnectionState.waiting) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: size,
              height: size,
              color: Colors.black12,
              child: const Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          );
        }

        if (url.isEmpty || snap.hasError) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: size,
              height: size,
              color: Colors.black12,
              child: const Icon(Icons.image_not_supported_outlined, size: 20),
            ),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: size,
            height: size,
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (context, _) => Container(color: Colors.black12),
              errorWidget: (context, url, error) => Container(
                color: Colors.black12,
                child: const Icon(Icons.broken_image_outlined, size: 20),
              ),
            ),
          ),
        );
      },
    );
  }
}
