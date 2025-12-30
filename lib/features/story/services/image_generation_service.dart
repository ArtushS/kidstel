import 'dart:typed_data';

import '../models/story_state.dart';

class GeneratedImageResult {
  final String? url;
  final Uint8List? bytes;

  const GeneratedImageResult({this.url, this.bytes});

  bool get hasUrl => (url ?? '').trim().isNotEmpty;
  bool get hasBytes => bytes != null && bytes!.isNotEmpty;

  @override
  String toString() =>
      'GeneratedImageResult(url=${hasUrl ? 'yes' : 'no'}, bytes=${hasBytes ? bytes!.length : 0})';
}

abstract class ImageGenerationService {
  /// Generates an image for the *current* story state.
  ///
  /// Returns either a URL or raw bytes.
  Future<GeneratedImageResult> generateImage({required StoryState story});
}
