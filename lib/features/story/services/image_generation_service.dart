import '../models/story_state.dart';

abstract class ImageGenerationService {
  /// Generates an image for the *current* story state.
  ///
  /// Returns a URL to display.
  Future<String> generateImage({required StoryState story});
}
