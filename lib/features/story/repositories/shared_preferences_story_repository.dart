import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/story_state.dart';
import 'story_repository.dart';

class SharedPreferencesStoryRepository implements StoryRepository {
  static const _key = 'my_stories_v1';

  @override
  Future<void> upsert(StoryState story) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _readAll(prefs);

    final idx = all.indexWhere((s) => s.storyId == story.storyId);
    if (idx >= 0) {
      all[idx] = story;
    } else {
      all.add(story);
    }

    // Keep most recent first.
    all.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));

    await prefs.setString(
      _key,
      jsonEncode(all.map((e) => e.toJson()).toList(growable: false)),
    );
  }

  @override
  Future<StoryState?> getById(String storyId) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _readAll(prefs);

    for (final s in all) {
      if (s.storyId == storyId) return s;
    }

    return null;
  }

  @override
  Future<List<StoryState>> listAll() async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _readAll(prefs);

    all.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    return all;
  }

  @override
  Future<void> delete(String storyId) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _readAll(prefs);

    all.removeWhere((s) => s.storyId == storyId);

    await prefs.setString(
      _key,
      jsonEncode(all.map((e) => e.toJson()).toList(growable: false)),
    );
  }

  Future<List<StoryState>> _readAll(SharedPreferences prefs) async {
    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return <StoryState>[];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return <StoryState>[];

    return decoded
        .whereType<Map>()
        .map((e) => StoryState.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: true);
  }
}
