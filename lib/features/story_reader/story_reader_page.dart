import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import 'story_reader_controller.dart';
import 'models/story_view_data.dart';

class StoryReaderPage extends StatelessWidget {
  final dynamic service;
  final String ageGroup;
  final String storyLang;
  final String storyLength;
  final double creativityLevel;
  final bool imageEnabled;
  final String hero;
  final String location;
  final String style;

  const StoryReaderPage({
    super.key,
    required this.service,
    required this.ageGroup,
    required this.storyLang,
    required this.storyLength,
    required this.creativityLevel,
    required this.imageEnabled,
    required this.hero,
    required this.location,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ChangeNotifierProvider<StoryReaderController>(
      create: (_) => StoryReaderController(
        service: service,
        ageGroup: ageGroup,
        storyLang: storyLang,
        storyLength: storyLength,
        creativityLevel: creativityLevel,
        imageEnabled: imageEnabled,
        hero: hero,
        location: location,
        style: style,
      )..loadInitial({
        'ageGroup': ageGroup,
        'storyLang': storyLang,
        'storyLength': storyLength,
        'creativityLevel': creativityLevel,
        'imageEnabled': imageEnabled,
        'hero': hero,
        'location': location,
        'style': style,
      }),
      child: Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: Text(l10n.story),
          actions: [
            _NarrationButton(),
            const SizedBox(width: 8),
            _MusicToggleButton(),
            const SizedBox(width: 12),
          ],
        ),
        body: const SafeArea(child: _StoryReaderBody()),
      ),
    );
  }
}

class _StoryReaderBody extends StatelessWidget {
  const _StoryReaderBody();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<StoryReaderController>();

    if (controller.isLoading && controller.data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.error != null) {
      return Center(child: Text(controller.error!));
    }

    final data = controller.data!;
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _ImageCard(data: data),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _TextCard(data: data),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: _BottomInteractionPanel(data: data),
        ),
      ],
    );
  }
}

class _ImageCard extends StatelessWidget {
  final StoryViewData data;

  const _ImageCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: data.coverImageUrl != null
                  ? Image.network(data.coverImageUrl!, fit: BoxFit.cover)
                  : Container(color: theme.colorScheme.surfaceVariant),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: _Chip(label: 'Chapter ${data.chapterIndex + 1}'),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: _Chip(label: '${(data.progress * 100).round()}%'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;

  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(label, style: theme.textTheme.labelMedium),
    );
  }
}

class _TextCard extends StatelessWidget {
  final StoryViewData data;

  const _TextCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<StoryReaderController>();
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(top: 16, bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          data.text,
          textScaleFactor: controller.textScale,
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _BottomInteractionPanel extends StatelessWidget {
  final StoryViewData data;

  const _BottomInteractionPanel({required this.data});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<StoryReaderController>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (!data.isFinal) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.chooseWhatNext,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            for (final choice in data.choices)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton(
                  onPressed: () => controller.onChoiceSelected(choice),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(choice.label),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 8),
          _MiniControls(),
        ],
      ),
    );
  }
}

class _MiniControls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<StoryReaderController>();

    return Row(
      children: [
        IconButton(
          icon: Icon(
            controller.musicEnabled ? Icons.music_note : Icons.music_off,
          ),
          onPressed: controller.toggleMusic,
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.text_decrease),
          onPressed: controller.decreaseText,
        ),
        IconButton(
          icon: const Icon(Icons.text_increase),
          onPressed: controller.increaseText,
        ),
      ],
    );
  }
}

class _NarrationButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<StoryReaderController>();

    return IconButton(
      icon: Icon(controller.narrationPlaying ? Icons.pause : Icons.play_arrow),
      onPressed: controller.toggleNarration,
    );
  }
}

class _MusicToggleButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<StoryReaderController>();

    return IconButton(
      icon: Icon(controller.musicEnabled ? Icons.music_note : Icons.music_off),
      onPressed: controller.toggleMusic,
    );
  }
}
