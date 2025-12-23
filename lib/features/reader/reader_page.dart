import 'package:flutter/material.dart';

import '../../shared/models/story_setup.dart';

class ReaderPage extends StatelessWidget {
  final StorySetup? setup;

  const ReaderPage({super.key, required this.setup});

  @override
  Widget build(BuildContext context) {
    final s = setup;

    final mockText = (s == null)
        ? null
        : 'Жил-был герой: ${s.hero}. Однажды он оказался в месте: ${s.location}. '
              'История будет в стиле: ${s.style}. '
              'Скоро мы подключим генерацию через сервер и появятся развилки.';

    return Scaffold(
      appBar: AppBar(title: const Text('Чтение')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: (s == null)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Пока нет открытой истории',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Нажми "Create Story" на главной странице, '
                    'чтобы создать новую сказку.',
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Глава 1',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(mockText!, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 24),
                  const Text('Выбор (пока мок):'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('Пойти налево'),
                      ),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('Пойти направо'),
                      ),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('Остаться'),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
