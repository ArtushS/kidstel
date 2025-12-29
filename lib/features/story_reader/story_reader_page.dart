import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/settings/settings_scope.dart';
import '../../shared/tts/tts_service.dart';
import '../story/controllers/narration_controller.dart';
import '../story/controllers/story_controller.dart';
import '../story/models/story_chapter.dart';
import '../story/models/story_state.dart';
import 'story_reader_args.dart';

class StoryReaderPage extends StatelessWidget {
  final StoryReaderArgs? args;

  const StoryReaderPage({super.key, this.args});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final a = args;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<StoryController>(
          create: (ctx) {
            final settings = SettingsScope.read(ctx).settings;
            return StoryController(
              storyService: ctx.read(),
              repository: ctx.read(),
              imageGenerationService: ctx.read(),
              interactiveStoriesEnabled: settings.interactiveStoriesEnabled,
              autoIllustrationsEnabled: settings.autoIllustrations,
            )..startStory(args: a);
          },
        ),
        ChangeNotifierProvider<NarrationController>(
          create: (ctx) => NarrationController(tts: ctx.read<TtsService>()),
        ),
      ],
      child: Builder(
        builder: (context) {
          final storyController = context.read<StoryController>();
          final narration = context.read<NarrationController>();

          return PopScope(
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) return;
              unawaited(narration.stop());
              unawaited(storyController.autoSaveIfNeeded());
            },
            child: Scaffold(
              appBar: AppBar(
                leading: const BackButton(),
                title: Text(l10n.story),
                actions: const [_SpeakStopButtons(), SizedBox(width: 12)],
              ),
              body: const SafeArea(child: _StoryReaderBody()),
            ),
          );
        },
      ),
    );
  }
}

class _StoryReaderBody extends StatelessWidget {
  const _StoryReaderBody();

  @override
  Widget build(BuildContext context) {
    final story = context.watch<StoryController>().state;
    final narration = context.watch<NarrationController>();
    final l10n = AppLocalizations.of(context)!;

    final chapters = story.chapters;
    final last = chapters.isNotEmpty ? chapters.last : null;
    final title = story.title.trim().isNotEmpty ? story.title : l10n.story;

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (n) {
            // Trigger auto-illustrations only after the user actually begins reading.
            if (n is ScrollStartNotification || n is UserScrollNotification) {
              context.read<StoryController>().markReadingStarted();
            }
            return false;
          },
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    softWrap: true,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _ErrorBanner(error: story.error),
                ),
              ),

              if (chapters.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: story.isLoading
                          ? const CircularProgressIndicator()
                          : Text(l10n.noStoryYet),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverList.separated(
                    itemCount: chapters.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _ChapterCard(
                        chapter: chapters[index],
                        ordinal: index + 1,
                      );
                    },
                  ),
                ),

              if (last != null) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: _NarrationPanel(last: last),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(child: _ImagePanel(last: last)),
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!story.isFinished) ...[
                          Text(
                            l10n.chooseWhatNext,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          for (final choice in story.currentChoices)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ElevatedButton(
                                onPressed: story.isLoading
                                    ? null
                                    : () async {
                                        final controller = context
                                            .read<StoryController>();
                                        await narration.stop();
                                        await controller.continueStory(choice);
                                      },
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          choice.label,
                                          softWrap: true,
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Padding(
                                        padding: EdgeInsets.only(top: 2),
                                        child: Icon(Icons.chevron_right),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],

                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: story.error == null || story.isLoading
                                  ? null
                                  : () => context
                                        .read<StoryController>()
                                        .retryLast(),
                              icon: const Icon(Icons.refresh),
                              label: Text(l10n.retry),
                            ),
                          ],
                        ),

                        if (story.isFinished) ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => context
                                .read<StoryController>()
                                .saveStory(manual: true),
                            icon: const Icon(Icons.bookmark_add_outlined),
                            label: Text(l10n.saveToMyStories),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              tooltip: l10n.createNewStory,
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () async {
                                final controller = context
                                    .read<StoryController>();
                                await narration.stop();
                                await controller.createNewStoryFromSession();
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        if (story.isLoading)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: Container(
                color: Colors.black.withValues(alpha: 0.06),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String? error;

  const _ErrorBanner({required this.error});

  @override
  Widget build(BuildContext context) {
    final msg = error;
    if (msg == null || msg.trim().isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
                softWrap: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  final StoryChapter chapter;
  final int ordinal;

  const _ChapterCard({required this.chapter, required this.ordinal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    chapter.title.isNotEmpty
                        ? chapter.title
                        : 'Chapter $ordinal',
                    style: theme.textTheme.titleMedium,
                    softWrap: true,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(chapter.progress * 100).round()}%',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              chapter.text,
              style: theme.textTheme.bodyLarge,
              softWrap: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _NarrationPanel extends StatelessWidget {
  final StoryChapter last;

  const _NarrationPanel({required this.last});

  @override
  Widget build(BuildContext context) {
    final narration = context.watch<NarrationController>();
    final story = context.watch<StoryController>().state;
    final l10n = AppLocalizations.of(context)!;
    final settings = SettingsScope.of(context).settings;
    final narrationEnabled = settings.voiceNarrationEnabled;

    final isSpeaking = narration.isSpeaking;
    final isPaused = narration.isPaused;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: (!narrationEnabled || isSpeaking)
                      ? null
                      : () {
                          context.read<StoryController>().markReadingStarted();
                          if (isPaused) {
                            narration.resumeNarration(
                              locale: story.locale,
                              voice: settings.ttsVoice,
                              volume: settings.ttsVolume,
                              rate: settings.ttsRate,
                              pitch: settings.ttsPitch,
                            );
                          } else {
                            narration.speakChapter(
                              last,
                              locale: story.locale,
                              voice: settings.ttsVoice,
                              volume: settings.ttsVolume,
                              rate: settings.ttsRate,
                              pitch: settings.ttsPitch,
                            );
                          }
                        },
                  icon: Icon(isPaused ? Icons.play_arrow : Icons.volume_up),
                  label: Text(isPaused ? 'Resume' : l10n.readAloud),
                ),
                OutlinedButton.icon(
                  onPressed: (narrationEnabled && isSpeaking)
                      ? narration.pauseNarration
                      : null,
                  icon: const Icon(Icons.pause),
                  label: const Text('Pause'),
                ),
                OutlinedButton.icon(
                  onPressed: (isSpeaking || isPaused)
                      ? narration.stopNarration
                      : null,
                  icon: const Icon(Icons.stop),
                  label: Text(l10n.stopReading),
                ),
                OutlinedButton.icon(
                  onPressed: (!narrationEnabled || isSpeaking)
                      ? null
                      : () async {
                          narration.prepareChapter(last);
                          final segs = narration.segments;

                          await showModalBottomSheet<void>(
                            context: context,
                            showDragHandle: true,
                            builder: (sheetContext) {
                              final theme = Theme.of(sheetContext);

                              String preview(String s) {
                                final oneLine = s.trim().replaceAll(
                                  RegExp(r'\s+'),
                                  ' ',
                                );
                                if (oneLine.length <= 60) return oneLine;
                                return '${oneLine.substring(0, 60)}…';
                              }

                              return SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        8,
                                        16,
                                        8,
                                      ),
                                      child: Text(
                                        'Start from…',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    Flexible(
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        itemCount: segs.length,
                                        separatorBuilder: (context, index) =>
                                            const Divider(height: 1),
                                        itemBuilder: (ctx, i) {
                                          return ListTile(
                                            dense: true,
                                            title: Text(preview(segs[i])),
                                            onTap: () async {
                                              Navigator.of(sheetContext).pop();
                                              context
                                                  .read<StoryController>()
                                                  .markReadingStarted();
                                              await narration.startFromSegment(
                                                last,
                                                i,
                                                locale: story.locale,
                                                voice: settings.ttsVoice,
                                                volume: settings.ttsVolume,
                                                rate: settings.ttsRate,
                                                pitch: settings.ttsPitch,
                                              );
                                            },
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
                  icon: const Icon(Icons.format_list_bulleted),
                  label: const Text('Start from…'),
                ),
              ],
            ),
            if (!narrationEnabled) ...[
              const SizedBox(height: 10),
              Text(
                'Включите Voice narration в Settings',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImagePanel extends StatelessWidget {
  final StoryChapter last;

  const _ImagePanel({required this.last});

  @override
  Widget build(BuildContext context) {
    final story = context.watch<StoryController>().state;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final status = story.illustrationStatus;
    final url = story.illustrationUrl;

    if (status == IllustrationStatus.idle) {
      // Spec: do not show any placeholder before generation begins.
      return const SizedBox.shrink();
    }

    Widget content;
    switch (status) {
      case IllustrationStatus.loading:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.illustration, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 12),
          ],
        );
        break;
      case IllustrationStatus.ready:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.illustration, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _IllustrationImage(source: url),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await context.read<StoryController>().saveToLibrary();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Saved.')));
                },
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Save image'),
              ),
            ),
          ],
        );
        break;
      case IllustrationStatus.error:
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.illustration, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(l10n.tryAgain),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context
                  .read<StoryController>()
                  .generateIllustration(force: true),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.tryAgain),
            ),
          ],
        );
        break;
      case IllustrationStatus.idle:
        content = const SizedBox.shrink();
        break;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(padding: const EdgeInsets.all(16), child: content),
    );
  }
}

class _IllustrationImage extends StatelessWidget {
  final String? source;

  const _IllustrationImage({required this.source});

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

    // Treat as a storage path like: users/<uid>/.../file.png
    return storage.ref(v).getDownloadURL();
  }

  @override
  Widget build(BuildContext context) {
    final s = (source ?? '').trim();
    if (s.isEmpty) {
      return const ColoredBox(
        color: Colors.black12,
        child: Center(child: Icon(Icons.image_not_supported_outlined)),
      );
    }

    return FutureBuilder<String>(
      future: _resolve(s),
      builder: (context, snap) {
        final url = (snap.data ?? '').trim();
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (url.isEmpty || snap.hasError) {
          return ColoredBox(
            color: Colors.black12,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.broken_image_outlined),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to load image',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (context, _) =>
              const Center(child: CircularProgressIndicator()),
          errorWidget: (context, _, error) => const ColoredBox(
            color: Colors.black12,
            child: Center(child: Icon(Icons.broken_image_outlined)),
          ),
        );
      },
    );
  }
}

class _SpeakStopButtons extends StatelessWidget {
  const _SpeakStopButtons();

  @override
  Widget build(BuildContext context) {
    final story = context.watch<StoryController>().state;
    final narration = context.watch<NarrationController>();
    final l10n = AppLocalizations.of(context)!;
    final settings = SettingsScope.of(context).settings;
    final narrationEnabled = settings.voiceNarrationEnabled;

    final last = story.chapters.isNotEmpty ? story.chapters.last : null;
    if (!narrationEnabled || last == null) return const SizedBox.shrink();

    final isSpeaking = narration.isSpeaking;
    final isPaused = narration.isPaused;

    Future<void> start() async {
      context.read<StoryController>().markReadingStarted();
      await narration.speakChapter(
        last,
        locale: story.locale,
        voice: settings.ttsVoice,
        volume: settings.ttsVolume,
        rate: settings.ttsRate,
        pitch: settings.ttsPitch,
      );
    }

    Future<void> resume() async {
      context.read<StoryController>().markReadingStarted();
      narration.resumeNarration(
        locale: story.locale,
        voice: settings.ttsVoice,
        volume: settings.ttsVolume,
        rate: settings.ttsRate,
        pitch: settings.ttsPitch,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: isSpeaking
              ? 'Pause'
              : (isPaused ? 'Continue' : l10n.readAloud),
          onPressed: isSpeaking
              ? narration.pauseNarration
              : (isPaused ? resume : start),
          icon: Icon(
            isSpeaking
                ? Icons.pause
                : (isPaused ? Icons.play_arrow : Icons.volume_up),
          ),
        ),
      ],
    );
  }
}
