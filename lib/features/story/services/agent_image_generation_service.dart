import 'dart:convert';

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

  void _imgLog(
    String message, {
    Map<String, Object?>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;
    final b = StringBuffer('[IMG] $message');
    if (data != null && data.isNotEmpty) {
      for (final e in data.entries) {
        b.write(' ${e.key}=${e.value}');
      }
    }
    debugPrint(b.toString());
    if (error != null) {
      debugPrint('[IMG] error=$error');
    }
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }

  String _preview(String s, {int max = 120}) {
    final v = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (v.length <= max) return v;
    return '${v.substring(0, max)}…';
  }

  String _hostOrEmpty(String url) {
    try {
      final u = Uri.tryParse(url.trim());
      return u?.host ?? '';
    } catch (_) {
      return '';
    }
  }

  bool _looksLikeHttpUrl(String s) {
    final v = s.trim().toLowerCase();
    return v.startsWith('http://') || v.startsWith('https://');
  }

  bool _looksLikeGsUrl(String s) {
    final v = s.trim().toLowerCase();
    return v.startsWith('gs://');
  }

  @override
  Future<GeneratedImageResult> generateImage({
    required StoryState story,
  }) async {
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

    _imgLog(
      'agent request',
      data: {
        'storyId': story.storyId,
        'storyLang': story.locale,
        'chapterIndex': last.chapterIndex,
        'promptLen': prompt.length,
        'promptPreview': _preview(prompt),
      },
    );

    try {
      final json = await _storyService.callAgentJson(body);

      final imgField = json['image'];
      if (kDebugMode) {
        final rawUrl = (imgField is Map) ? imgField['url'] : null;
        final rawUrlStr = rawUrl?.toString() ?? '';
        final rawUrlTrimmed = rawUrlStr.trim();

        Object? urlCandidate;
        if (imgField is Map) {
          urlCandidate =
              imgField['url'] ??
              imgField['imageUrl'] ??
              imgField['image_url'] ??
              imgField['downloadUrl'] ??
              imgField['download_url'] ??
              imgField['href'];
        }

        _imgLog(
          'agent image field',
          data: {
            'imageType': imgField?.runtimeType.toString(),
            if (imgField is Map) 'imageKeys': imgField.keys.take(20).join(','),
            if (imgField is String) 'imageLen': imgField.length,
            'rawUrlType': rawUrl?.runtimeType.toString(),
            'rawUrlIsString': rawUrl is String,
            'rawUrlLen': rawUrlTrimmed.length,
            'rawUrlPrefix': rawUrlTrimmed.substring(
              0,
              rawUrlTrimmed.length.clamp(0, 64),
            ),
            'rawUrlTrimEmpty': rawUrlTrimmed.isEmpty,
            'rawUrlLooksHttp': _looksLikeHttpUrl(rawUrlTrimmed),
            'rawUrlLooksGs': _looksLikeGsUrl(rawUrlTrimmed),
            if (urlCandidate != null)
              'imageUrlType': urlCandidate.runtimeType.toString(),
            if (urlCandidate is String)
              'imageUrlLen': urlCandidate.trim().length,
            if (urlCandidate is String)
              'imageUrlHost': _hostOrEmpty(urlCandidate),
          },
        );
      }

      _imgLog(
        'agent response',
        data: {
          'keys': json.keys.take(12).join(','),
          'hasUrl':
              (json['url'] is String) &&
              (json['url'] as String).trim().isNotEmpty,
          'hasImage': json['image'] is Map,
          'hasImageUrl':
              (json['image'] is Map) &&
              (((json['image'] as Map)['url'] is String) &&
                  (((json['image'] as Map)['url'] as String)
                      .trim()
                      .isNotEmpty)),
          if ((json['image'] is Map) &&
              ((json['image'] as Map)['url'] is String))
            'imageUrlLen': (((json['image'] as Map)['url'] as String)
                .trim()
                .length),
          'hasData': json['data'] is Map,
        },
      );

      final result = _extractResult(json);
      if (!result.hasUrl && !result.hasBytes) {
        final keys = json.keys.take(20).join(',');
        final rawUrl = (json['image'] is Map)
            ? (json['image'] as Map)['url']
            : null;
        final rawUrlStr = rawUrl?.toString() ?? '';
        final rawUrlTrimmed = rawUrlStr.trim();
        _imgLog(
          'agent response missing url/bytes',
          data: {
            'keys': keys,
            'rawUrlType': rawUrl?.runtimeType.toString(),
            'rawUrlLen': rawUrlTrimmed.length,
            'rawUrlPrefix': rawUrlTrimmed.substring(
              0,
              rawUrlTrimmed.length.clamp(0, 64),
            ),
            'rawUrlTrimEmpty': rawUrlTrimmed.isEmpty,
            'rawUrlLooksHttp': _looksLikeHttpUrl(rawUrlTrimmed),
            'rawUrlLooksGs': _looksLikeGsUrl(rawUrlTrimmed),
          },
        );
        throw FormatException(
          'Agent returned no image url/bytes. keys=[$keys]',
        );
      }

      if (result.hasUrl) {
        final u = result.url!.trim();
        _imgLog(
          'agent parsed url',
          data: {
            'urlLen': u.length,
            'urlHost': _hostOrEmpty(u),
            'urlPrefix': u.substring(0, u.length.clamp(0, 32)),
          },
        );
      } else {
        _imgLog('agent parsed bytes', data: {'bytesLen': result.bytes!.length});
      }

      return result;
    } catch (e, st) {
      _imgLog(
        'agent call failed',
        data: {
          'storyId': story.storyId,
          'storyLang': story.locale,
          'chapterIndex': last.chapterIndex,
        },
        error: e,
        stackTrace: st,
      );
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
      final u = _extractUrlFromMap(image);
      if (u != null) return u;
    }

    final data = json['data'];
    if (data is Map) {
      final u = _extractUrlFromMap(data);
      if (u != null) return u;
      final img = data['image'];
      if (img is Map) {
        final iu = _extractUrlFromMap(img);
        if (iu != null) return iu;
      }
    }

    return null;
  }

  String? _extractUrlFromMap(Map map) {
    final candidates = <Object?>[
      map['url'],
      map['imageUrl'],
      map['image_url'],
      map['downloadUrl'],
      map['download_url'],
      map['href'],
    ];

    for (final c in candidates) {
      if (c is String) {
        final v = c.trim();
        if (v.isNotEmpty && _looksLikeHttpUrl(v)) return v;
      }
      if (c is Uri) {
        final v = c.toString().trim();
        if (v.isNotEmpty && _looksLikeHttpUrl(v)) return v;
      }
      if (c is Map) {
        final nested = c['url'];
        if (nested is String) {
          final v = nested.trim();
          if (v.isNotEmpty && _looksLikeHttpUrl(v)) return v;
        }
      }
    }
    return null;
  }

  GeneratedImageResult _extractResult(Map<String, dynamic> json) {
    // 0) Primary shape (current server): image: { url: "https://..." }
    final image = json['image'];
    if (image is Map) {
      final rawUrl = image['url'];
      if (rawUrl != null) {
        final u = rawUrl.toString().trim();
        if (u.isNotEmpty && _looksLikeHttpUrl(u)) {
          return GeneratedImageResult(url: u);
        }
        // If it's gs:// or empty, do not treat as success here.
      }
    }

    // 1) Existing URL shapes.
    final url = _extractUrl(json);
    if (url != null) {
      final u = url.trim();
      if (u.isNotEmpty && _looksLikeHttpUrl(u)) {
        return GeneratedImageResult(url: u);
      }
    }

    // 2) image: <base64 string> OR image: <url string>
    final img = json['image'];
    final direct = _extractFromImageField(img);
    if (direct != null) return direct;

    // 3) Some servers may place image under choices[0].*
    final choices = json['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map) {
        final m = Map<String, dynamic>.from(first);
        final cUrl = m['imageUrl'];
        if (cUrl is String && cUrl.trim().isNotEmpty) {
          return GeneratedImageResult(url: cUrl.trim());
        }
        final cImg = m['image'];
        final fromChoice = _extractFromImageField(cImg);
        if (fromChoice != null) return fromChoice;
      }
    }

    return const GeneratedImageResult();
  }

  GeneratedImageResult? _extractFromImageField(Object? image) {
    if (image == null) return null;

    if (image is String) {
      final s = image.trim();
      if (s.isEmpty) return null;
      if (_looksLikeHttpUrl(s)) return GeneratedImageResult(url: s);
      final bytes = _tryDecodeBase64Image(s);
      if (bytes != null && bytes.isNotEmpty) {
        return GeneratedImageResult(bytes: bytes);
      }
      return null;
    }

    if (image is Map) {
      final m = Map<String, dynamic>.from(image);

      final u = m['url'];
      if (u is String) {
        final v = u.trim();
        if (v.isNotEmpty && _looksLikeHttpUrl(v)) {
          return GeneratedImageResult(url: v);
        }
      }

      final b64 = (m['base64'] ?? m['data']);
      if (b64 is String && b64.trim().isNotEmpty) {
        final bytes = _tryDecodeBase64Image(b64.trim());
        if (bytes != null && bytes.isNotEmpty) {
          return GeneratedImageResult(bytes: bytes);
        }
      }
    }

    return null;
  }

  Uint8List? _tryDecodeBase64Image(String s) {
    try {
      var v = s.trim();

      // Accept data: URLs.
      if (v.startsWith('data:')) {
        final comma = v.indexOf(',');
        if (comma < 0) return null;
        v = v.substring(comma + 1);
      }

      // Some base64 may contain whitespace/newlines.
      v = v.replaceAll(RegExp(r'\s+'), '');
      if (v.isEmpty) return null;

      return base64Decode(v);
    } catch (_) {
      return null;
    }
  }
}
