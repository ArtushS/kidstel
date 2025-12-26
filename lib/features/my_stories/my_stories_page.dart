import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../story/repositories/story_repository.dart';

class MyStoriesPage extends StatefulWidget {
  const MyStoriesPage({super.key});

  @override
  State<MyStoriesPage> createState() => _MyStoriesPageState();
}

class _MyStoriesPageState extends State<MyStoriesPage> {
  late Future<void> _load;
  List<_StoryItem> _items = const [];

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
    setState(() {
      _items = stories
          .where((s) => s.storyId.trim().isNotEmpty)
          .map(
            (s) => _StoryItem(
              id: s.storyId,
              title: s.title.trim().isEmpty ? s.storyId : s.title,
              isFinished: s.isFinished,
              updated: s.lastUpdated,
              chapterCount: s.chapters.length,
            ),
          )
          .toList(growable: false);
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

            if (_items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(t.noStoryYet),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final s = _items[index];
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        s.isFinished
                            ? Icons.check_circle_outline
                            : Icons.play_circle_outline,
                      ),
                      title: Text(
                        s.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${s.chapterCount} • ${_formatDate(s.updated)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        context.push(
                          '/story-reader',
                          extra: <String, dynamic>{'storyId': s.id},
                        );
                      },
                    ),
                  );
                },
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
  final DateTime updated;
  final int chapterCount;

  const _StoryItem({
    required this.id,
    required this.title,
    required this.isFinished,
    required this.updated,
    required this.chapterCount,
  });
}
