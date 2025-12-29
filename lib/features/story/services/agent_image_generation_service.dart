import 'package:flutter/foundation.dart';

import '../models/story_chapter.dart';
import '../models/story_state.dart';
import 'image_generation_service.dart';
import 'story_service.dart';

/// Image generation backed by the existing agent endpoint.
///
/// This is intentionally tolerant to response shapes because the server may
/// evolve independently of the app.
class AgentImageGenerationService implements ImageGenerationService {
  final StoryService _storyService;

  const AgentImageGenerationService({required StoryService storyService})
    : _storyService = storyService;

  @override
  Future<String> generateImage({required StoryState story}) async {
    if (story.chapters.isEmpty) {
      throw StateError('Cannot generate image: story has no chapters.');
    }

    final last = story.chapters.last;
    final prompt = (story.illustrationPrompt ?? _buildPrompt(story, last))
        .trim();

    if (prompt.isEmpty) {
      throw StateError('Cannot generate image: prompt is empty.');
    }

    final body = <String, dynamic>{
      'action': 'illustrate',
      'storyId': story.storyId,
      'storyLang': story.locale,
      'chapterIndex': last.chapterIndex,
      'prompt': prompt,
    };

    try {
      final json = await _storyService.callAgentJson(body);

      final url = _extractUrl(json);
      if (url == null || url.trim().isEmpty) {
        throw FormatException('Agent returned no image url.');
      }

      return url.trim();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AgentImageGenerationService.generateImage failed: $e');
      }
      rethrow;
    }
  }

  String _buildPrompt(StoryState story, StoryChapter chapter) {
    final title = chapter.title.trim().isNotEmpty
        ? chapter.title.trim()
        : story.title.trim();
    final text = chapter.text.trim();
    final snippet = text.length > 200 ? '${text.substring(0, 200)}…' : text;
    return [
      if (title.isNotEmpty) title,
      if (snippet.isNotEmpty) snippet,
    ].join('\n');
  }

  String? _extractUrl(Map<String, dynamic> json) {
    final direct = json['url'];
    if (direct is String) return direct;

    final image = json['image'];
    if (image is Map) {
      final u = image['url'];
      if (u is String) return u;
    }

    final data = json['data'];
    if (data is Map) {
      final u = data['url'];
      if (u is String) return u;
      final img = data['image'];
      if (img is Map) {
        final iu = img['url'];
        if (iu is String) return iu;
      }
    }

    return null;
  }
}
