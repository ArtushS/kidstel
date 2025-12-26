import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Speech-to-text controller (Provider-ready).
///
/// Session model:
/// - During listening: `partialText` can be updated (optional UI use).
/// - When a final result arrives: `finalText` is set for this session.
/// - UI commits the text by calling `consumeFinalText()` when listening stops
///   (user stop or auto-stop).
class VoiceInputController extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();

  List<stt.LocaleName> _locales = const [];

  bool _isAvailable = false;
  bool _isListening = false;

  String _partialText = '';
  String _finalText = ''; // final recognized phrase of the last session
  DateTime? _lastFinalAt;
  String _lastPartial = '';
  String _lastFinal = '';
  String? _sessionEndReason;
  Completer<void>? _endCompleter;
  String? _error;

  // Control flags
  bool _userStopped = false;
  String? _activeLocaleIdToPass;
  String? _lastResolvedLocaleId;

  // Desired language/locale (based on app UI language)
  String _desiredAppLangCode = 'en';
  String? _desiredLocaleIdToPass;
  Timer? _langChangeTimer;
  int _langChangeOp = 0;

  // Non-fatal warning (e.g. missing RU/HY locales -> use system default)
  String? _warning;

  // Tunables
  Duration pauseFor = const Duration(seconds: 3);
  Duration listenFor = const Duration(seconds: 10);

  bool get isAvailable => _isAvailable;
  bool get isListening => _isListening;

  /// Live partial words from engine (can be empty).
  String get partialText => _partialText;

  /// Latest finalized chunk from engine.
  String get finalText => _finalText;

  /// Timestamp of the most recent final result.
  DateTime? get lastFinalAt => _lastFinalAt;

  /// Debug-only: why the last session ended.
  String? get sessionEndReason => _sessionEndReason;

  String? get error => _error;

  /// Locale id currently used for listening (best-effort; may be a fallback).
  String get currentLocaleId => _activeLocaleIdToPass ?? 'system';

  /// Locale id passed to the engine, or null meaning "system default".
  String? get activeLocaleIdToPass => _activeLocaleIdToPass;

  /// Alias for legacy call sites/debug labels.
  String get activeLocaleId => _activeLocaleIdToPass ?? 'system';

  /// Most recent desired app UI language code that STT should follow.
  String get desiredAppLangCode => _desiredAppLangCode;

  /// Desired locale id resolved from the app UI language (even if not listening).
  String get desiredLocaleId => _desiredLocaleIdToPass ?? 'system';

  /// Locale id chosen for the latest start request (after resolution).
  String? get lastResolvedLocaleId => _lastResolvedLocaleId;

  List<stt.LocaleName> get locales => _locales;

  List<String> get localeIds =>
      _locales.map((e) => e.localeId).toList(growable: false);

  bool get hasArmenianSupport =>
      _locales.any((l) => l.localeId.toLowerCase().startsWith('hy'));

  /// Non-fatal warning message (e.g. language not supported -> fallback).
  String? get warning => _warning;

  void clearWarning() {
    if (_warning == null) return;
    _warning = null;
    notifyListeners();
  }

  Future<void> init() async {
    try {
      _error = null;
      _isAvailable = await _speech.initialize(
        onError: (e) {
          if (kDebugMode) {
            debugPrint('STT error: ${e.errorMsg} (permanent=${e.permanent})');
          }
          _error = e.errorMsg;
          _isListening = false;
          _sessionEndReason = 'error:${e.errorMsg}';
          if (_endCompleter != null && !_endCompleter!.isCompleted) {
            _endCompleter!.complete();
          }

          notifyListeners();
        },
        onStatus: (status) {
          if (kDebugMode) {
            debugPrint('STT status: $status');
          }
          // statuses: listening, notListening, done
          final nowListening = status == 'listening';
          if (_isListening != nowListening) {
            _isListening = nowListening;
          }

          if (status == 'notListening' || status == 'done') {
            _isListening = false;
            _sessionEndReason = 'status:$status';
            if (_endCompleter != null && !_endCompleter!.isCompleted) {
              _endCompleter!.complete();
            }
          }

          notifyListeners();
        },
      );

      if (_isAvailable) {
        try {
          _locales = await _speech.locales();
          if (kDebugMode) {
            debugPrint(
              'STT locales: ${_locales.map((e) => e.localeId).join(', ')}',
            );
          }
        } catch (e) {
          // Locale discovery is best-effort; keep STT usable.
          _locales = const [];
          if (kDebugMode) {
            debugPrint('STT locales() failed: $e');
          }
        }
      } else {
        _locales = const [];
      }
    } catch (e) {
      _isAvailable = false;
      _isListening = false;
      _error = e.toString();
      _locales = const [];
    }

    notifyListeners();
  }

  /// Resolves a localeId for the given UI language code.
  ///
  /// Returns a matching localeId (e.g. ru-*, en-*, hy-*), or null when no
  /// matching locale is found. Null means: do not pass localeId to the engine
  /// (use system default recognition language).
  String? resolveLocaleIdForAppLang(String langCode) {
    final lc = langCode.trim().toLowerCase();

    if (_locales.isEmpty) {
      // Diagnostics list unavailable -> let system decide.
      return null;
    }

    String? exact(String id) {
      final needle = id.toLowerCase();
      for (final l in _locales) {
        if (l.localeId.toLowerCase() == needle) return l.localeId;
      }
      return null;
    }

    String? firstLang(String code) {
      final c = code.toLowerCase();
      for (final l in _locales) {
        final id = l.localeId.toLowerCase();
        if (id == c || id.startsWith('$c-') || id.startsWith('${c}_')) {
          return l.localeId;
        }
      }
      return null;
    }

    if (lc == 'en') {
      return exact('en-US') ?? firstLang('en');
    }
    if (lc == 'ru') {
      return exact('ru-RU') ?? firstLang('ru');
    }
    if (lc == 'hy') {
      return exact('hy-AM') ?? firstLang('hy');
    }

    return null;
  }

  ResolvedSttLocale resolveForAppLang(String appLangCode) {
    final lc = appLangCode.trim().toLowerCase();
    final resolved = resolveLocaleIdForAppLang(lc);

    // Only warn for RU/HY when we fall back to system.
    if (resolved == null && (lc == 'ru' || lc == 'hy')) {
      final msg = (lc == 'ru')
          ? 'Русский язык для голосового ввода не найден в списке языков устройства. Используем системный язык распознавания. '
                'Если распознаёт не на русском — проверьте Язык и ввод → Голосовой ввод → Языки (Google).'
          : 'Հայերեն լեզուն չի գտնվել սարքի ձայնային լեզուների ցուցակում։ Օգտագործվում է համակարգի խոսքի լեզուն։ '
                'Եթե չի ճանաչում հայերեն՝ ստուգեք Կարգավորումներ → Լեզու և ներածում → Ձայնային ներածում → Լեզուներ (Google).';

      return ResolvedSttLocale(
        localeIdToPass: null,
        isExactMatch: false,
        isFallbackToSystem: true,
        warning: msg,
      );
    }

    // No warning for English (and generally none for other langs) if we fall back.
    return ResolvedSttLocale(
      localeIdToPass: resolved,
      isExactMatch: resolved != null,
      isFallbackToSystem: resolved == null,
      warning: null,
    );
  }

  Future<void> startForLang({
    required String appLangCode,
    bool clearBuffer = true,
  }) async {
    final lang = appLangCode.trim().toLowerCase();

    if (!_isAvailable) {
      await init();
      if (!_isAvailable) {
        _error ??= 'Speech recognition not available';
        notifyListeners();
        return;
      }
    }

    final resolved = resolveForAppLang(lang);

    _desiredAppLangCode = lang;
    _desiredLocaleIdToPass = resolved.localeIdToPass;
    _activeLocaleIdToPass = resolved.localeIdToPass;
    _lastResolvedLocaleId = resolved.localeIdToPass;
    _warning = resolved.warning;

    if (kDebugMode) {
      debugPrint(
        'STT: appLang=$lang resolvedLocale=${resolved.localeIdToPass ?? "system"}',
      );
    }

    // Always start a new session: clear transient session storage.
    _lastPartial = '';
    _lastFinal = '';
    _partialText = '';
    _finalText = '';
    _lastFinalAt = null;
    _sessionEndReason = null;
    _endCompleter = Completer<void>();

    // (clearBuffer is kept for backward-compat; it no longer affects behavior.)
    await _startWithLocaleId(localeIdToPass: resolved.localeIdToPass);
  }

  /// Compatibility alias (preferred name in some call sites/specs).
  Future<void> startForAppLang({
    required String appLangCode,
    bool clearBuffer = true,
  }) => startForLang(appLangCode: appLangCode, clearBuffer: clearBuffer);

  /// Update the desired UI language for STT.
  ///
  /// If currently listening and the resolved locale changes, the controller
  /// cancels and restarts listening using the new localeId.
  ///
  /// Debounced to avoid rapid language switching races.
  Future<void> setDesiredAppLang(String appLangCode) async {
    final lang = appLangCode.trim().toLowerCase();
    _langChangeTimer?.cancel();
    final op = ++_langChangeOp;

    _langChangeTimer = Timer(const Duration(milliseconds: 250), () async {
      if (op != _langChangeOp) return;

      // Requirement: when UI language changes, cancel current session if listening,
      // but DO NOT auto-start/restart. Next mic start will use the new appLang.
      _desiredAppLangCode = lang;

      final resolved = resolveForAppLang(lang);
      _desiredLocaleIdToPass = resolved.localeIdToPass;

      if (kDebugMode) {
        debugPrint(
          'STT desired: appLang=$lang desiredLocale=${resolved.localeIdToPass ?? "system"}',
        );
      }

      if (_isListening) {
        if (kDebugMode) {
          debugPrint(
            'STT: cancelling due to app language change while listening',
          );
        }
        await cancel();
      }

      notifyListeners();
    });
  }

  Future<void> _startWithLocaleId({required String? localeIdToPass}) async {
    _userStopped = false;
    _activeLocaleIdToPass = localeIdToPass;

    _error = null;

    if (!_isAvailable) {
      await init();
      if (!_isAvailable) {
        _error ??= 'Speech recognition not available';
        notifyListeners();
        return;
      }
    }

    if (kDebugMode) {
      debugPrint(
        'STT start: appLang=$_desiredAppLangCode locale=${localeIdToPass ?? "system"}',
      );
    }

    await _listenInternal();
  }

  Future<void> _listenInternal() async {
    if (_userStopped) return;

    try {
      _isListening = true;
      notifyListeners();

      void onResult(dynamic res) {
        final words = res.recognizedWords.toString().trim();

        if (kDebugMode) {
          debugPrint('STT onResult final=${res.finalResult} words="$words"');
        }

        if (res.finalResult) {
          _lastFinal = words;
          _finalText = words;
          _partialText = '';
          _lastFinalAt = DateTime.now();
          notifyListeners();
        } else {
          _lastPartial = words;
          _partialText = words;
          notifyListeners();
        }
      }

      final opts = stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
      );

      // IMPORTANT: when localeId is null, do NOT pass localeId at all.
      if (_activeLocaleIdToPass == null) {
        await _speech.listen(
          listenOptions: opts,
          pauseFor: pauseFor,
          listenFor: listenFor,
          onResult: onResult,
        );
      } else {
        await _speech.listen(
          localeId: _activeLocaleIdToPass,
          listenOptions: opts,
          pauseFor: pauseFor,
          listenFor: listenFor,
          onResult: onResult,
        );
      }
    } catch (e) {
      _isListening = false;
      _error = e.toString();
      _sessionEndReason = 'exception:$e';
      if (_endCompleter != null && !_endCompleter!.isCompleted) {
        _endCompleter!.complete();
      }
      if (kDebugMode) {
        debugPrint('STT listen() exception: $e');
      }
      notifyListeners();
    }
  }

  /// Returns the best available recognized text from the last session:
  /// prefer final, else partial.
  ///
  /// Clears the stored session words after consuming.
  String consumeBestResult() {
    final best = (_lastFinal.trim().isNotEmpty)
        ? _lastFinal.trim()
        : _lastPartial.trim();

    _lastFinal = '';
    _lastPartial = '';
    _finalText = '';
    _partialText = '';
    _lastFinalAt = null;
    notifyListeners();
    return best;
  }

  /// User intentionally stops dictation and wants to commit result.
  Future<void> stop() async {
    _userStopped = true;
    _sessionEndReason = 'stop()';

    try {
      await _speech.stop();
    } catch (e) {
      _error = e.toString();
      _sessionEndReason = 'stopException:$e';
    }

    // Wait briefly for the engine to finish the session / deliver late results.
    try {
      await _endCompleter?.future.timeout(
        const Duration(milliseconds: 600),
        onTimeout: () {},
      );
    } catch (_) {
      // ignore
    } finally {
      _isListening = false;
      // Keep finalText intact for UI consumption; clear partial.
      _partialText = '';
      notifyListeners();
    }
  }

  /// User cancels dictation (discard partial listening state).
  Future<void> cancel() async {
    _userStopped = true;
    _sessionEndReason = 'cancel()';

    try {
      await _speech.cancel();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isListening = false;
      // Cancel discards any uncommitted text.
      _partialText = '';
      _finalText = '';
      _lastFinalAt = null;
      _lastPartial = '';
      _lastFinal = '';
      if (_endCompleter != null && !_endCompleter!.isCompleted) {
        _endCompleter!.complete();
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _langChangeTimer?.cancel();
    super.dispose();
  }
}

class ResolvedSttLocale {
  final String? localeIdToPass; // null => use system default
  final bool isExactMatch;
  final bool isFallbackToSystem;
  final String? warning; // user-facing

  const ResolvedSttLocale({
    required this.localeIdToPass,
    required this.isExactMatch,
    required this.isFallbackToSystem,
    required this.warning,
  });
}
