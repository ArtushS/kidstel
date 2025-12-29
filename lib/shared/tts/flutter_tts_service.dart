import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'tts_service.dart';

/// Stub implementation to prepare DI switching.
///
/// Replace internals with a real TTS plugin (e.g. flutter_tts) when ready.
class FlutterTtsService implements TtsService {
  FlutterTtsService();

  final ValueNotifier<bool> _speaking = ValueNotifier(false);

  void Function(TtsProgress progress)? _progressListener;

  FlutterTts? _tts;
  bool _initTried = false;
  bool _available = false;
  Future<void>? _initFuture;

  @override
  ValueListenable<bool> get speakingListenable => _speaking;

  @override
  ValueListenable<bool> get speaking => speakingListenable;

  @override
  void setProgressListener(void Function(TtsProgress progress)? listener) {
    _progressListener = listener;
  }

  @override
  Future<void> init() {
    _initFuture ??= _initInternal();
    return _initFuture!;
  }

  String? normalizeLocale(String? locale) {
    final raw = locale?.trim();
    if (raw == null || raw.isEmpty) return null;
    switch (raw.toLowerCase()) {
      case 'ru':
        return 'ru-RU';
      case 'en':
        return 'en-US';
      case 'hy':
        return 'hy-AM';
      default:
        return raw;
    }
  }

  Future<void> _initInternal() async {
    if (_initTried) return;
    _initTried = true;

    try {
      final tts = FlutterTts();
      _tts = tts;

      // Track speaking state.
      tts.setStartHandler(() {
        _speaking.value = true;
      });
      tts.setCompletionHandler(() {
        _speaking.value = false;
      });
      tts.setCancelHandler(() {
        _speaking.value = false;
      });
      tts.setErrorHandler((err) {
        _speaking.value = false;
        if (kDebugMode) {
          debugPrint('FlutterTtsService.onError: $err');
        }
      });

      // Track progress offsets (best-effort; may not fire on some platforms/voices).
      tts.setProgressHandler((String text, int start, int end, String word) {
        _progressListener?.call(
          TtsProgress(text: text, start: start, end: end, word: word),
        );
      });

      // Configure defaults that are safe.
      // Keep awaiting optional: some platforms/plugins return null.
      await tts.awaitSpeakCompletion(true);

      _available = true;
    } on MissingPluginException catch (e) {
      // Running on a platform without the plugin registered.
      if (kDebugMode) {
        debugPrint('FlutterTtsService.init: MissingPluginException: $e');
      }
      _available = false;
      _tts = null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FlutterTtsService.init failed: $e');
      }
      _available = false;
      _tts = null;
    }
  }

  @override
  Future<List<Map<String, String>>> listVoices({String? locale}) async {
    await init();
    final tts = _tts;
    if (!_available || tts == null) return const [];

    try {
      final raw = await tts.getVoices;
      final List<Map<String, String>> out = [];

      void addVoice(String? name, String? loc) {
        final n = (name ?? '').trim();
        final l = (loc ?? '').trim();
        if (n.isEmpty || l.isEmpty) return;
        out.add({'name': n, 'locale': l});
      }

      if (raw is List) {
        for (final v in raw) {
          if (v is Map) {
            addVoice(v['name']?.toString(), v['locale']?.toString());
          } else {
            // Unknown voice entry shape.
          }
        }
      }

      // De-duplicate.
      final seen = <String>{};
      final deduped = <Map<String, String>>[];
      for (final v in out) {
        final key = '${v['name']}|${v['locale']}';
        if (seen.add(key)) deduped.add(v);
      }

      final filter = normalizeLocale(locale) ?? locale?.trim();
      if (filter == null || filter.isEmpty) return deduped;
      final f = filter.toLowerCase();
      final base = f.split('-').first;

      return deduped
          .where((v) {
            final l = (v['locale'] ?? '').toLowerCase();
            return l == f ||
                l.startsWith(f) ||
                l == base ||
                l.startsWith('$base-');
          })
          .toList(growable: false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FlutterTtsService.listVoices failed: $e');
      }
      return const [];
    }
  }

  @override
  Future<void> speak({
    required String text,
    String? locale,
    Map<String, String>? voice,
    double? volume,
    double? rate,
    double? pitch,
  }) async {
    await init();
    final tts = _tts;

    // Always stop previous speech first.
    await stop();

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    if (!_available || tts == null) {
      // Safe no-op on unsupported platforms.
      if (kDebugMode) {
        debugPrint(
          'FlutterTtsService.speak skipped (not available). text="${trimmed.substring(0, trimmed.length.clamp(0, 80))}"',
        );
      }
      return;
    }

    final voiceLocaleRaw = voice?['locale']?.toString();
    final effectiveLocale =
        (voiceLocaleRaw != null && voiceLocaleRaw.trim().isNotEmpty)
        ? voiceLocaleRaw.trim()
        : (normalizeLocale(locale) ?? locale?.trim());

    try {
      if (volume != null) {
        await tts.setVolume(volume.clamp(0.0, 1.0));
      }
      if (rate != null) {
        await tts.setSpeechRate(rate.clamp(0.1, 1.0));
      }
      if (pitch != null) {
        await tts.setPitch(pitch.clamp(0.5, 2.0));
      }

      if (effectiveLocale != null && effectiveLocale.isNotEmpty) {
        await tts.setLanguage(effectiveLocale);
      }

      if (voice != null) {
        final name = voice['name']?.toString().trim();
        final loc = (voice['locale']?.toString().trim().isNotEmpty == true)
            ? voice['locale']!.toString().trim()
            : effectiveLocale;
        if (name != null && name.isNotEmpty && loc != null && loc.isNotEmpty) {
          await tts.setVoice({'name': name, 'locale': loc});
        }
      }

      await tts.speak(trimmed);
    } catch (e) {
      _speaking.value = false;
      if (kDebugMode) {
        debugPrint(
          'FlutterTtsService.speak failed: $e (locale=$locale effective=$effectiveLocale voice=$voice)',
        );
      }
    }
  }

  @override
  Future<void> stop() async {
    await init();
    final tts = _tts;
    if (!_available || tts == null) {
      _speaking.value = false;
      return;
    }

    try {
      await tts.stop();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FlutterTtsService.stop failed: $e');
      }
    } finally {
      _speaking.value = false;
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    _tts = null;
    _progressListener = null;
    _speaking.dispose();
  }
}
