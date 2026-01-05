import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

import 'models/generate_story_request.dart';
import 'models/generate_story_response.dart';

class StoryService {
  /// Set your Agent endpoint here (Cloud Function HTTPS endpoint or your server).
  /// Example:
  /// `https://<region>-<project>.cloudfunctions.net/generateStory`
  final String endpointUrl;

  /// If true, requests must include a valid Firebase App Check token.
  ///
  /// Default behavior:
  /// - Release builds: required
  /// - Debug/profile: not required unless overridden by dart-define
  ///
  /// Override at build time:
  /// `--dart-define=APPCHECK_REQUIRED=true|false`
  final bool appCheckRequired;

  /// Optional locale hint header.
  ///
  /// IMPORTANT:
  /// - If null/empty, the header is not sent.
  /// - If the string is literally "null", it is also not sent.
  final String? firebaseLocale;

  StoryService({
    required this.endpointUrl,
    bool? appCheckRequired,
    this.firebaseLocale,
  }) : appCheckRequired = appCheckRequired ?? _defaultAppCheckRequired() {
    if (kDebugMode) {
      final uri = Uri.tryParse(endpointUrl);
      debugPrint(
        '[StoryService] configured endpoint=${uri?.toString() ?? endpointUrl} '
        'host=${uri?.host ?? 'unknown'} appCheckRequired=$appCheckRequired',
      );
    }
  }

  // In-flight request de-duplication (single-flight per logical operation).
  // This helps avoid accidental double-submits (e.g. rebuilds / quick taps).
  final Map<String, Future<Map<String, dynamic>>> _inFlight =
      <String, Future<Map<String, dynamic>>>{};

  static final Random _rand = Random();

  // Wire-log policy: exactly 1 line for REQ and 1 line for RESP.
  // Keep this enabled by default to avoid noisy logs (and to reduce risk of
  // accidentally logging story content elsewhere).
  static const bool _wireLogOnly = true;

  static String? _storyLangFromBody(Map<String, dynamic> body) {
    final v = (body['storyLang'] ?? '').toString().trim().toLowerCase();
    return v.isNotEmpty ? v : null;
  }

  static List<String> _sortedBodyKeys(Map<String, dynamic> body) {
    final keys = body.keys.map((k) => k.toString()).toList(growable: false);
    keys.sort();
    return keys;
  }

  static List<String> _sortedHeaderKeys(Map<String, String> headers) {
    final keys = headers.keys.map((k) => k.toString()).toList(growable: false);
    keys.sort();
    return keys;
  }

  static String? _toErrShort(String? raw, {int maxLen = 140}) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return null;
    final flat = s
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .replaceAll(RegExp(r'\s\s+'), ' ')
        .trim();
    if (flat.isEmpty) return null;
    return flat.length > maxLen ? flat.substring(0, maxLen) : flat;
  }

  static String? _errShortFromResponse({
    required int status,
    required Object? decoded,
    required String bodyText,
  }) {
    // IMPORTANT: avoid logging any story text. Prefer structured error fields.
    if (decoded is Map) {
      final err = decoded['error']?.toString();
      final safeMessage = decoded['safeMessage']?.toString();
      final code = decoded['code']?.toString();

      return _toErrShort(err) ?? _toErrShort(code) ?? _toErrShort(safeMessage);
    }

    // Fallback: very short preview for non-JSON error bodies.
    if (status >= 400) {
      return _toErrShort(bodyText, maxLen: 120);
    }
    return null;
  }

  // Cooldown to prevent hammering the backend when upstream daily quota is exhausted.
  // Keyed by endpoint URL to keep behavior stable across environments.
  static final Map<String, DateTime> _globalCooldownUntilByEndpoint =
      <String, DateTime>{};

  // Short UI cooldown after successful user actions (generate/illustrate).
  // Keyed by endpoint + action, so continue isn't blocked.
  static final Map<String, DateTime> _actionCooldownUntilByKey =
      <String, DateTime>{};

  static String _cooldownKey(Uri uri, String action) =>
      '${uri.toString()}|${action.trim().toLowerCase()}';

  static DateTime? _globalCooldownUntil(Uri uri) =>
      _globalCooldownUntilByEndpoint[uri.toString()];

  static DateTime? _actionCooldownUntil(Uri uri, String action) =>
      _actionCooldownUntilByKey[_cooldownKey(uri, action)];

  static void _setGlobalCooldown(Uri uri, Duration d) {
    _globalCooldownUntilByEndpoint[uri.toString()] = DateTime.now().toUtc().add(
      d,
    );
  }

  static void _setActionCooldown(Uri uri, String action, Duration d) {
    _actionCooldownUntilByKey[_cooldownKey(uri, action)] = DateTime.now()
        .toUtc()
        .add(d);
  }

  static String _newClientRequestId() {
    final t = DateTime.now().toUtc().microsecondsSinceEpoch;
    final r = _rand.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 'req_${t}_$r';
  }

  static String _operationKeyFor(Map<String, dynamic> body) {
    final action = (body['action'] ?? '').toString().trim().toLowerCase();

    // Hard cap: at most 1 generate in flight (regardless of lang/idea/etc).
    if (action == 'generate') return 'generate';

    final storyId = (body['storyId'] ?? '').toString().trim();
    final storyLang = (body['storyLang'] ?? '').toString().trim().toLowerCase();
    final chapterIndex = body.containsKey('chapterIndex')
        ? (body['chapterIndex']?.toString() ?? '')
        : '';
    final choice = body['choice'];
    final choiceId = (choice is Map)
        ? ((choice['id'] ?? '').toString().trim())
        : '';
    return [action, storyId, storyLang, chapterIndex, choiceId].join('|');
  }

  void _wireLogReq({
    required Uri uri,
    required String requestId,
    required String opKey,
    required Map<String, dynamic> body,
    required Map<String, String> headers,
    required bool hasAuth,
    required bool hasAppCheck,
    required String xFirebaseLocale,
    required int jsonBytesLength,
    required int attempt,
  }) {
    if (!kDebugMode) return;

    final action = (body['action'] ?? '').toString().trim().toLowerCase();
    final storyId = (body['storyId'] ?? '').toString().trim();
    final storyLang = _storyLangFromBody(body);
    final keys = _sortedBodyKeys(body);
    final provider = body['provider']?.toString().trim();
    final model = body['model']?.toString().trim();
    final idea = body['idea'];
    final prompt = body['prompt'];
    final selectionAny = _selectionHasAnyInput(body['selection']);

    final headerKeys = _sortedHeaderKeys(headers);

    // NOTE: Treat either `idea` or `prompt` as "text" for the wire log.
    final ideaText = idea is String ? idea.trim() : '';
    final promptText = prompt is String ? prompt.trim() : '';
    final hasText = ideaText.isNotEmpty || promptText.isNotEmpty;
    final promptLen = ideaText.isNotEmpty
        ? ideaText.length
        : (promptText.isNotEmpty ? promptText.length : 0);

    // IMPORTANT: never log prompt/idea text.
    _safeLog(
      'REQ',
      data: {
        'rid': requestId,
        'op': opKey,
        'attempt': attempt,
        'host': uri.host,
        'path': uri.path,
        'action': action,
        if (storyLang != null) 'lang': storyLang,
        'headersKeys': headerKeys.join(','),
        'X-Firebase-Locale': xFirebaseLocale,
        'hasAuth': hasAuth,
        'hasAppCheck': hasAppCheck,
        'storyId': storyId.isNotEmpty ? storyId : null,
        'chapterIndex': body['chapterIndex'],
        if (provider != null && provider.isNotEmpty) 'provider': provider,
        if (model != null && model.isNotEmpty) 'model': model,
        'jsonBytes': jsonBytesLength,
        'hasSelection': selectionAny,
        'hasText': hasText,
        'promptLen': promptLen,
        // For wire-comparison (EN vs RU), ensure keys are visible.
        'bodyKeys': keys.join(','),
      },
    );
  }

  void _wireLogResp({
    required String requestId,
    required String opKey,
    required int attempt,
    required int status,
    required int ms,
    required String? lang,
    required String? errShort,
    required String? serverRequestId,
    required String? serverErrorCode,
    required String? revision,
    required String? kidstelAction,
    required String? kidstelService,
    required String? kidstelRev,
    required String? serverDebugService,
    required String? serverDebugRevision,
    required String? serverDebugConfig,
    required bool cooldownApplied,
    required int? cooldownSec,
  }) {
    if (!kDebugMode) return;
    _safeLog(
      'RESP',
      data: {
        'rid': requestId,
        'op': opKey,
        'attempt': attempt,
        'status': status,
        'ms': ms,
        if (lang != null && lang.trim().isNotEmpty) 'lang': lang,
        if (revision != null && revision.trim().isNotEmpty) 'rev': revision,
        if (kidstelAction != null && kidstelAction.trim().isNotEmpty)
          'kidstelAction': kidstelAction,
        if (kidstelService != null && kidstelService.trim().isNotEmpty)
          'kidstelService': kidstelService,
        if (kidstelRev != null && kidstelRev.trim().isNotEmpty)
          'kidstelRev': kidstelRev,
        if (serverDebugService != null && serverDebugService.trim().isNotEmpty)
          'dbgService': serverDebugService,
        if (serverDebugRevision != null &&
            serverDebugRevision.trim().isNotEmpty)
          'dbgRev': serverDebugRevision,
        if (serverDebugConfig != null && serverDebugConfig.trim().isNotEmpty)
          'dbgCfg': serverDebugConfig,
        if (serverRequestId != null && serverRequestId.trim().isNotEmpty)
          'serverRid': serverRequestId,
        if (serverErrorCode != null && serverErrorCode.trim().isNotEmpty)
          'err': serverErrorCode,
        if (errShort != null && errShort.trim().isNotEmpty)
          'errShort': errShort,
        if (cooldownApplied) 'cooldown': true,
        if (cooldownApplied && cooldownSec != null) 'cooldownSec': cooldownSec,
      },
    );
  }

  static String _dailyLimitUserMessage(String? lang) {
    if (lang == 'ru') {
      return 'Дневной лимит генераций исчерпан. Попробуйте завтра.';
    }
    if (lang == 'hy') {
      return 'Օրվա ստեղծումների սահմանը լրացել է։ Փորձեք վաղը։';
    }
    return 'Daily generation limit reached. Please try again tomorrow.';
  }

  static String _userDailyLimitMessage(String? lang) {
    if (lang == 'ru') {
      return 'Достигнут дневной лимит в приложении. Попробуйте завтра.';
    }
    if (lang == 'hy') {
      return 'Հավելվածում օրվա սահմանը լրացել է։ Փորձեք վաղը։';
    }
    return 'You’ve reached the app daily limit. Please try again tomorrow.';
  }

  static String _cooldownMessage(String? lang, int waitSec) {
    if (lang == 'ru') {
      return 'Пожалуйста, подождите $waitSec сек. и попробуйте снова.';
    }
    if (lang == 'hy') {
      return 'Խնդրում ենք սպասել $waitSec վրկ․ և փորձել կրկին։';
    }
    return 'Please wait $waitSec sec and try again.';
  }

  static bool _defaultAppCheckRequired() {
    const raw = String.fromEnvironment('APPCHECK_REQUIRED', defaultValue: '');
    final v = raw.trim().toLowerCase();
    if (v == 'true' || v == '1' || v == 'yes') return true;
    if (v == 'false' || v == '0' || v == 'no') return false;
    return kReleaseMode;
  }

  static bool _looksLikePlaceholderAppCheckToken(String token) {
    final t = token.trim().toLowerCase();
    // Observed in the wild when attestation fails.
    if (t == 'placeholder') return true;
    if (t == 'appcheck-placeholder') return true;
    return false;
  }

  void _safeLog(String message, {Map<String, Object?>? data}) {
    if (!kDebugMode) return;

    // Enforce the “1 line REQ + 1 line RESP” rule.
    if (_wireLogOnly && message != 'REQ' && message != 'RESP') return;

    final b = StringBuffer('[StoryService] $message');
    if (data != null && data.isNotEmpty) {
      for (final e in data.entries) {
        b.write(' ${e.key}=${e.value}');
      }
    }
    debugPrint(b.toString());
  }

  static bool _selectionHasAnyInput(Object? selection) {
    if (selection is! Map) return false;
    final hero = (selection['hero'] ?? '').toString().trim();
    final location = (selection['location'] ?? '').toString().trim();
    final style = (selection['style'] ?? '').toString().trim();
    return hero.isNotEmpty || location.isNotEmpty || style.isNotEmpty;
  }

  void _logParsedImageMeta(String action, GenerateStoryResponse resp) {
    // Intentionally no-op: keep wire logs to 1 REQ + 1 RESP line.
    // (We keep the method so callers don't need conditional compilation.)
    return;
  }

  Future<_BuiltHeaders> _buildHeaders({String? storyLangHint}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    var hasAuth = false;
    var hasAppCheck = false;
    var appCheckError = false;

    // Auth: ID token
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        final t = (token ?? '').trim();
        if (t.isNotEmpty) {
          headers['Authorization'] = 'Bearer $t';
          hasAuth = true;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('StoryService: failed to get Auth ID token: $e');
      }
    }

    // App Check
    try {
      final token = await FirebaseAppCheck.instance.getToken();
      final t = (token ?? '').trim();
      if (t.isNotEmpty && !_looksLikePlaceholderAppCheckToken(t)) {
        headers['X-Firebase-AppCheck'] = t;
        hasAppCheck = true;
      }
    } catch (e) {
      appCheckError = true;
      if (kDebugMode) {
        debugPrint('StoryService: failed to get App Check token: $e');
      }
    }

    // Locale hint (optional).
    // Prefer the request's storyLang so EN/RU/HY requests are identical except lang.
    final hint = storyLangHint?.trim().toLowerCase();
    final fallback = firebaseLocale?.trim();
    final raw = (hint != null && hint.isNotEmpty) ? hint : fallback;
    if (raw != null && raw.isNotEmpty && raw.toLowerCase() != 'null') {
      // IMPORTANT: only send small allowlisted values to backend.
      // This avoids accidental "ru-RU" / "en-US" values breaking strict servers.
      final normalized = raw.toLowerCase();
      if (normalized == 'en' || normalized == 'ru' || normalized == 'hy') {
        headers['X-Firebase-Locale'] = normalized;
      }
    }

    // Fail closed on client when App Check is required but token is absent.
    if (appCheckRequired &&
        (headers['X-Firebase-AppCheck'] ?? '').trim().isEmpty) {
      // User-safe message: do not include debug details/tokens.
      throw Exception(
        'Security check failed (App Check). Please try again later.\n'
        'If you are on an emulator/dev build, add the debug token in Firebase Console.',
      );
    }

    return _BuiltHeaders(
      headers: headers,
      hasAuth: hasAuth,
      hasAppCheck: hasAppCheck,
      appCheckError: appCheckError,
    );
  }

  Future<GenerateStoryResponse> generateStory(GenerateStoryRequest req) async {
    final json = await callAgentJson(req.toJson());
    final resp = GenerateStoryResponse.fromJson(json);
    _logParsedImageMeta('generate', resp);
    return resp;
  }

  Future<GenerateStoryResponse> continueStory(GenerateStoryRequest req) async {
    final json = await callAgentJson(req.toJson());
    final resp = GenerateStoryResponse.fromJson(json);
    _logParsedImageMeta('continue', resp);
    return resp;
  }

  Future<Map<String, dynamic>> callAgentJson(Map<String, dynamic> body) async {
    final uriRaw = Uri.parse(endpointUrl);
    // Normalize host-only URLs to include a root path for clearer logging
    // and maximum compatibility across HTTP stacks.
    final uri = uriRaw.path.isEmpty ? uriRaw.replace(path: '/') : uriRaw;

    // Never mutate external maps passed by callers.
    final reqBody = Map<String, dynamic>.from(body);

    final clientRequestIdRaw = (reqBody['requestId'] ?? '').toString().trim();
    final requestId = clientRequestIdRaw.isNotEmpty
        ? clientRequestIdRaw
        : _newClientRequestId();
    reqBody['requestId'] = requestId;

    final opKey = _operationKeyFor(reqBody);
    final existing = _inFlight[opKey];
    if (existing != null) {
      return existing;
    }

    final future = _callAgentJsonSingle(
      uri: uri,
      requestId: requestId,
      opKey: opKey,
      body: reqBody,
    );
    _inFlight[opKey] = future;
    try {
      return await future;
    } finally {
      // Only clear if we still own this key.
      if (identical(_inFlight[opKey], future)) {
        _inFlight.remove(opKey);
      }
    }
  }

  Future<Map<String, dynamic>> _callAgentJsonSingle({
    required Uri uri,
    required String requestId,
    required String opKey,
    required Map<String, dynamic> body,
  }) async {
    final storyLang = _storyLangFromBody(body);

    final action = (body['action'] ?? '').toString().trim().toLowerCase();
    final now = DateTime.now().toUtc();

    // Global cooldown (daily quota exhaustion): blocks all actions.
    final globalUntil = _globalCooldownUntil(uri);
    if (globalUntil != null && now.isBefore(globalUntil)) {
      final waitSec = globalUntil.difference(now).inSeconds.clamp(1, 60);
      _safeLog(
        'RESP',
        data: {
          'rid': requestId,
          'op': opKey,
          'attempt': 0,
          'status': 429,
          'ms': 0,
          if (storyLang != null) 'lang': storyLang,
          'errShort': 'cooldown_active',
          'cooldownApplied': true,
          'cooldownSec': waitSec,
        },
      );
      throw StoryServiceCooldownException(
        userMessage: _dailyLimitUserMessage(storyLang),
        requestId: requestId,
        lang: storyLang,
        waitSeconds: waitSec,
      );
    }

    // Action cooldown (post-success): blocks only generate/illustrate UI spam.
    if (action == 'generate' || action == 'illustrate') {
      final until = _actionCooldownUntil(uri, action);
      if (until != null && now.isBefore(until)) {
        final waitSec = until.difference(now).inSeconds.clamp(1, 60);
        _safeLog(
          'RESP',
          data: {
            'rid': requestId,
            'op': opKey,
            'attempt': 0,
            'status': 429,
            'ms': 0,
            if (storyLang != null) 'lang': storyLang,
            'errShort': 'cooldown_active',
            'cooldownApplied': true,
            'cooldownSec': waitSec,
          },
        );
        throw StoryServiceCooldownException(
          userMessage: _cooldownMessage(storyLang, waitSec),
          requestId: requestId,
          lang: storyLang,
          waitSeconds: waitSec,
        );
      }
    }

    // Hard guard: never send an empty generate request.
    // This protects against accidental calls from any screen/controller.
    if (action == 'generate') {
      final storyId = (body['storyId'] ?? '').toString().trim();
      final idea = (body['idea'] ?? '').toString().trim();
      final prompt = (body['prompt'] ?? '').toString().trim();
      final selectionAny = _selectionHasAnyInput(body['selection']);
      if (storyId.isEmpty && idea.isEmpty && prompt.isEmpty && !selectionAny) {
        throw const StoryServiceSkipException(
          'Skip generate: no storyId and no prompt/idea',
        );
      }
    }

    final client = http.Client();
    try {
      final built = await _buildHeaders(storyLangHint: storyLang);

      const timeout = Duration(seconds: 60);
      const maxRetries429 = 2;
      var attempt = 0;

      while (true) {
        final t0 = DateTime.now();

        // Encode once per attempt so we can log size and reuse the same body.
        final bodyJson = jsonEncode(body);
        final jsonBytesLength = utf8.encode(bodyJson).length;

        _wireLogReq(
          uri: uri,
          requestId: requestId,
          opKey: opKey,
          body: body,
          headers: built.headers,
          hasAuth: built.hasAuth,
          hasAppCheck: built.hasAppCheck,
          xFirebaseLocale: (built.headers['X-Firebase-Locale'] ?? 'absent'),
          jsonBytesLength: jsonBytesLength,
          attempt: attempt,
        );

        final resp = await client
            .post(uri, headers: built.headers, body: bodyJson)
            .timeout(timeout);

        final ms = DateTime.now().difference(t0).inMilliseconds;
        final revision = resp.headers['x-k-revision'];
        final kidstelAction = resp.headers['x-kidstel-action'];
        final kidstelService = resp.headers['x-kidstel-service'];
        final kidstelRev = resp.headers['x-kidstel-rev'];

        final text = resp.body;
        Object? decoded;
        try {
          decoded = jsonDecode(text);
        } catch (_) {
          decoded = null;
        }

        // Optional server debug envelope (safe metadata only).
        final serverDebug = (decoded is Map) ? decoded['debug'] : null;
        final serverDebugService = (serverDebug is Map)
            ? serverDebug['service']?.toString()
            : null;
        final serverDebugRevision = (serverDebug is Map)
            ? serverDebug['revision']?.toString()
            : null;
        final serverDebugConfig = (serverDebug is Map)
            ? serverDebug['configuration']?.toString()
            : null;

        final serverRid = (decoded is Map)
            ? decoded['requestId']?.toString()
            : null;
        final serverErr = (decoded is Map)
            ? decoded['error']?.toString()
            : null;

        final errShort = _errShortFromResponse(
          status: resp.statusCode,
          decoded: decoded,
          bodyText: text,
        );

        // Decide whether we will apply a cooldown for this action.
        bool cooldownApplied = false;
        int? cooldownSec;

        // Success cooldown: after generate/illustrate, block button 10–30s.
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          if (action == 'generate' || action == 'illustrate') {
            cooldownApplied = true;
            cooldownSec = 10 + _rand.nextInt(21); // 10..30 sec
          }
        }

        // 429 daily-ish cooldown is handled below; we surface it in the same RESP line.
        if (resp.statusCode == 429) {
          final errCodeForCooldown =
              (decoded is Map && decoded['error'] is String)
              ? (decoded['error'] as String).trim()
              : '';
          final tLower = text.toLowerCase();
          final textSaysDaily =
              tLower.contains('daily limit exceeded') ||
              tLower.contains('daily ai quota');
          final textSaysQuota = tLower.contains('quota');
          final textSaysRate =
              tLower.contains('too many requests') ||
              errCodeForCooldown == 'rate_limited';

          final isQuotaDaily =
              errCodeForCooldown == 'quota_daily_exceeded' || textSaysDaily;
          final isLocalDaily = errCodeForCooldown == 'daily_limit_exceeded';
          final isUserDaily = errCodeForCooldown == 'limit_user_daily';
          final isDailyHeuristic =
              !isQuotaDaily &&
              !isLocalDaily &&
              !isUserDaily &&
              (textSaysDaily || (textSaysQuota && !textSaysRate));

          if (isQuotaDaily || isLocalDaily || isUserDaily || isDailyHeuristic) {
            cooldownApplied = true;
            cooldownSec = 60;
          }
        }

        _wireLogResp(
          requestId: requestId,
          opKey: opKey,
          attempt: attempt,
          status: resp.statusCode,
          ms: ms,
          lang: storyLang,
          errShort: errShort,
          serverRequestId: serverRid,
          serverErrorCode: serverErr,
          revision: revision,
          kidstelAction: kidstelAction,
          kidstelService: kidstelService,
          kidstelRev: kidstelRev,
          serverDebugService: serverDebugService,
          serverDebugRevision: serverDebugRevision,
          serverDebugConfig: serverDebugConfig,
          cooldownApplied: cooldownApplied,
          cooldownSec: cooldownSec,
        );

        // Apply cooldown after logging (so logs describe exactly what happened).
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          if (cooldownApplied && cooldownSec != null) {
            _setActionCooldown(uri, action, Duration(seconds: cooldownSec));
          }
        }

        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          if (decoded is Map<String, dynamic>) return decoded;
          throw Exception('Agent returned non-object JSON');
        }

        final errCode = (decoded is Map && decoded['error'] is String)
            ? (decoded['error'] as String).trim()
            : '';

        // Bounded retry on 429 *rate limit only* (never retry daily limits).
        if (resp.statusCode == 429) {
          final retryAfterSec =
              (decoded is Map && decoded['retryAfterSec'] is num)
              ? (decoded['retryAfterSec'] as num).toInt()
              : null;

          final textLower = text.toLowerCase();
          final textSaysDailyLimit =
              textLower.contains('daily limit exceeded') ||
              textLower.contains('daily ai quota');
          final textSaysQuota = textLower.contains('quota');
          final textSaysRateLimit =
              textLower.contains('too many requests') ||
              errCode == 'rate_limited';

          final isDailyQuota =
              errCode == 'quota_daily_exceeded' ||
              // Backward/alternate shapes:
              (decoded is Map &&
                  (decoded['error']?.toString() ?? '').contains(
                    'Daily limit exceeded',
                  ));

          final isLocalDailyLimit = errCode == 'daily_limit_exceeded';

          final isUserDailyLimit = errCode == 'limit_user_daily';

          // Heuristic fallback if server didn't normalize the error shape.
          final isDailyQuotaHeuristic =
              !isDailyQuota &&
              !isLocalDailyLimit &&
              !isUserDailyLimit &&
              (textSaysDailyLimit || (textSaysQuota && !textSaysRateLimit));

          // Never retry daily limits (either our own daily limit or upstream daily quota).
          if (isDailyQuota ||
              isLocalDailyLimit ||
              isUserDailyLimit ||
              isDailyQuotaHeuristic) {
            const cooldownSec = 60;
            _setGlobalCooldown(uri, const Duration(seconds: cooldownSec));

            final ridText = serverRid ?? requestId;
            final msg = isUserDailyLimit
                ? _userDailyLimitMessage(storyLang)
                : _dailyLimitUserMessage(storyLang);

            if (isDailyQuota || isDailyQuotaHeuristic) {
              final provider = (decoded is Map)
                  ? (decoded['provider']?.toString() ?? '')
                  : '';
              final model = (decoded is Map)
                  ? (decoded['model']?.toString() ?? '')
                  : '';

              throw StoryServiceDailyLimitException(
                userMessage: msg,
                requestId: ridText,
                lang: storyLang,
                statusCode: 429,
                errShort: errShort,
                cooldownSeconds: cooldownSec,
                retryAfterSec: retryAfterSec,
                provider: provider.isNotEmpty ? provider : null,
                model: model.isNotEmpty ? model : null,
              );
            }

            throw StoryServiceDailyLimitException(
              userMessage: msg,
              requestId: ridText,
              lang: storyLang,
              statusCode: 429,
              errShort: errShort,
              cooldownSeconds: cooldownSec,
              retryAfterSec: retryAfterSec,
            );
          }

          final looksRateLimited =
              errCode == 'rate_limited' ||
              (decoded is Map &&
                  (decoded['error']?.toString() ?? '').contains(
                    'Too many requests',
                  ));

          if (looksRateLimited && attempt < maxRetries429) {
            // Fixed backoff (user-action only): 800ms, then 1600ms.
            final delayMs = attempt == 0 ? 800 : 1600;
            await Future<void>.delayed(Duration(milliseconds: delayMs));
            attempt += 1;
            continue;
          }
        }

        if (resp.statusCode == 400 && errCode == 'invalid_json') {
          throw Exception(
            'The request could not be processed (invalid JSON body). Please retry.',
          );
        }

        if (resp.statusCode == 400 && errCode.isNotEmpty) {
          throw Exception('Request rejected: $errCode');
        }

        // In debug: include a short preview only.
        throw Exception(
          'Agent error ${resp.statusCode}: ${kDebugMode ? (text.length > 240 ? text.substring(0, 240) : text) : '<redacted>'}',
        );
      }
    } finally {
      client.close();
    }
  }
}

class StoryServiceDailyLimitException implements Exception {
  final String userMessage;
  final String requestId;
  final String? lang;
  final int statusCode;
  final String? errShort;
  final int cooldownSeconds;
  final int? retryAfterSec;
  final String? provider;
  final String? model;

  const StoryServiceDailyLimitException({
    required this.userMessage,
    required this.requestId,
    required this.lang,
    required this.statusCode,
    required this.errShort,
    required this.cooldownSeconds,
    this.retryAfterSec,
    this.provider,
    this.model,
  });

  @override
  String toString() => userMessage;
}

class StoryServiceCooldownException implements Exception {
  final String userMessage;
  final String requestId;
  final String? lang;
  final int waitSeconds;

  const StoryServiceCooldownException({
    required this.userMessage,
    required this.requestId,
    required this.lang,
    required this.waitSeconds,
  });

  @override
  String toString() => userMessage;
}

/// Debug-friendly HTTP result for agent calls.
///
/// This is intended for diagnostics screens (e.g. Firebase sanity check) where
/// we want to see HTTP status + response keys even when the server returns a
/// non-2xx code.
class AgentHttpResult {
  final int statusCode;
  final Map<String, String> headers;
  final Object? json;
  final int bodyBytesLength;
  final String? textPreview;
  final String requestUrl;
  final String action;

  const AgentHttpResult({
    required this.statusCode,
    required this.headers,
    required this.json,
    required this.bodyBytesLength,
    required this.textPreview,
    required this.requestUrl,
    required this.action,
  });

  bool get ok => statusCode >= 200 && statusCode < 300;

  Map<String, dynamic>? get jsonMap =>
      (json is Map<String, dynamic>) ? (json as Map<String, dynamic>) : null;
}

extension StoryServiceDebug on StoryService {
  /// Performs a raw agent call and returns HTTP status + decoded JSON (if any).
  ///
  /// - Does NOT throw for non-2xx statuses.
  /// - May throw if the request cannot be made (e.g. App Check required but
  ///   token missing, network errors, invalid endpoint URL).
  Future<AgentHttpResult> callAgentHttp(Map<String, dynamic> body) async {
    final uriRaw = Uri.parse(endpointUrl);
    final uri = uriRaw.path.isEmpty ? uriRaw.replace(path: '/') : uriRaw;
    final client = http.Client();

    try {
      // Hard guard: keep debug/sanity screens from sending empty generate requests.
      final action = (body['action'] ?? '').toString().trim().toLowerCase();
      if (action == 'generate') {
        final storyId = (body['storyId'] ?? '').toString().trim();
        final idea = (body['idea'] ?? '').toString().trim();
        final prompt = (body['prompt'] ?? '').toString().trim();
        final selectionAny = StoryService._selectionHasAnyInput(
          body['selection'],
        );
        if (storyId.isEmpty &&
            idea.isEmpty &&
            prompt.isEmpty &&
            !selectionAny) {
          if (kDebugMode) {
            debugPrint(
              '[StoryService] Skip generate: no storyId and no prompt/idea',
            );
          }
          throw const StoryServiceSkipException(
            'Skip generate: no storyId and no prompt/idea',
          );
        }
      }

      final built = await _buildHeaders();

      final resp = await client
          .post(uri, headers: built.headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 60));

      Object? decoded;
      String? preview;
      try {
        decoded = jsonDecode(resp.body);
      } catch (_) {
        // Not JSON; include a short preview in debug screens.
        final text = resp.body;
        if (text.trim().isNotEmpty) {
          preview = text.length > 400 ? text.substring(0, 400) : text;
        }
      }

      // Keep only the headers we care about for diagnostics.
      final headers = <String, String>{
        for (final e in resp.headers.entries) e.key.toLowerCase(): e.value,
      };

      return AgentHttpResult(
        statusCode: resp.statusCode,
        headers: headers,
        json: decoded,
        bodyBytesLength: resp.bodyBytes.length,
        textPreview: preview,
        requestUrl: uri.toString(),
        action: (body['action'] ?? '').toString(),
      );
    } finally {
      client.close();
    }
  }
}

class _BuiltHeaders {
  final Map<String, String> headers;
  final bool hasAuth;
  final bool hasAppCheck;
  final bool appCheckError;

  const _BuiltHeaders({
    required this.headers,
    required this.hasAuth,
    required this.hasAppCheck,
    required this.appCheckError,
  });
}

class StoryServiceSkipException implements Exception {
  final String message;

  const StoryServiceSkipException(this.message);

  @override
  String toString() => message;
}
