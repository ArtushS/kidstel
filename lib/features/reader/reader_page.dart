import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/models/story_setup.dart';

class ReaderPage extends StatelessWidget {
  final StorySetup? setup;

  const ReaderPage({super.key, required this.setup});

  @override
  Widget build(BuildContext context) {
    final s = setup;
    final t = AppLocalizations.of(context)!;

    final mockText = (s == null)
        ? null
        : 'Жил-был герой: ${s.hero}. Однажды он оказался в месте: ${s.location}. '
              'Тип истории: ${s.storyType}. '
              'Скоро мы подключим генерацию через сервер и появятся развилки.';

    return Scaffold(
      appBar: AppBar(title: Text(t.reading)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: (s == null)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.noStoryYet,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(t.noStoryMessage),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.chapter1,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(mockText!, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 24),
                  Text(t.choicePlaceholder),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(onPressed: () {}, child: Text(t.goLeft)),
                      OutlinedButton(onPressed: () {}, child: Text(t.goRight)),
                      OutlinedButton(onPressed: () {}, child: Text(t.stay)),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
