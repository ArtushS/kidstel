import 'dart:async';

import '../models/story_state.dart';
import 'image_generation_service.dart';

class MockImageGenerationService implements ImageGenerationService {
  @override
  Future<GeneratedImageResult> generateImage({
    required StoryState story,
  }) async {
    // Simulate background generation.
    await Future<void>.delayed(const Duration(seconds: 2));

    final last = story.chapters.isNotEmpty ? story.chapters.last : null;
    final url = last?.imageUrl;

    if (url == null || url.trim().isEmpty) {
      throw Exception('Illustration is unavailable right now.');
    }

    return GeneratedImageResult(url: url.trim());
  }
}
