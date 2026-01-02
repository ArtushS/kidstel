import 'dart:convert';
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

  StoryService({required this.endpointUrl, bool? appCheckRequired})
    : appCheckRequired = appCheckRequired ?? _defaultAppCheckRequired() {
    if (kDebugMode) {
      final uri = Uri.tryParse(endpointUrl);
      debugPrint(
        '[StoryService] configured endpoint=${uri?.toString() ?? endpointUrl} '
        'host=${uri?.host ?? 'unknown'} appCheckRequired=$appCheckRequired',
      );
    }
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
    final b = StringBuffer('[StoryService] $message');
    if (data != null && data.isNotEmpty) {
      for (final e in data.entries) {
        b.write(' ${e.key}=${e.value}');
      }
    }
    debugPrint(b.toString());
  }

  String _urlKind(String? url) {
    final s = (url ?? '').trim();
    if (s.isEmpty) return 'none';
    final lower = s.toLowerCase();
    if (lower.startsWith('https://')) return 'https';
    if (lower.startsWith('http://')) return 'http';
    if (lower.startsWith('gs://')) return 'gs';
    if (lower.startsWith('storage://')) return 'storage';
    if (lower.contains('://')) return 'other';
    return 'path';
  }

  void _logParsedImageMeta(String action, GenerateStoryResponse resp) {
    if (!kDebugMode) return;
    final img = resp.image;
    final url = img?.url;
    final base64 = img?.base64;

    _safeLog(
      'PARSED',
      data: {
        'action': action,
        'respHasImage': img != null,
        'hasUrl': (url ?? '').trim().isNotEmpty,
        'urlKind': _urlKind(url),
        'hasBase64': (base64 ?? '').trim().isNotEmpty,
        'base64Len': (base64 ?? '').trim().length,
        'imgEnabled': img?.enabled,
        'imgDisabled': img?.disabled,
        'hasReason': (img?.reason ?? '').trim().isNotEmpty,
      },
    );
  }

  Future<_BuiltHeaders> _buildHeaders() async {
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
    final uri = Uri.parse(endpointUrl);

    // NOTE: never log full request/response bodies (kid content). Only metadata in debug.
    final idea = body['idea'];
    final prompt = body['prompt'];
    _safeLog(
      'POST',
      data: {
        'url': uri.toString(),
        'action': body['action'],
        'storyId': body['storyId'],
        'chapterIndex': body['chapterIndex'],
        'storyLang': body['storyLang'],
        'hasIdea': idea != null,
        if (idea is String) 'ideaLen': idea.trim().length,
        'hasPrompt': prompt != null,
        if (prompt is String) 'promptLen': prompt.trim().length,
      },
    );

    final client = http.Client();
    try {
      final built = await _buildHeaders();

      // Debug-only meta proof: do NOT log tokens, only booleans.
      _safeLog(
        'HEADERS',
        data: {
          'host': uri.host,
          'appCheckRequired': appCheckRequired,
          'hasAuth': built.hasAuth,
          'hasAppCheck': built.hasAppCheck,
          'appCheckError': built.appCheckError,
        },
      );

      final resp = await client
          .post(uri, headers: built.headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 60));

      _safeLog(
        'STATUS',
        data: {
          'code': resp.statusCode,
          'blocked': resp.headers['x-kidstel-blocked'],
          'blockReason': resp.headers['x-kidstel-block-reason'],
          'contentLen': resp.bodyBytes.length,
        },
      );

      final text = resp.body;

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        // In debug: include a short preview only.
        throw Exception(
          'Agent error ${resp.statusCode}: ${kDebugMode ? (text.length > 240 ? text.substring(0, 240) : text) : '<redacted>'}',
        );
      }

      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        _safeLog(
          'OK',
          data: {
            'requestId': decoded['requestId'],
            'storyId': decoded['storyId'],
            'chapterIndex': decoded['chapterIndex'],
            'keys': decoded.keys.take(12).join(','),
          },
        );
        return decoded;
      }

      throw Exception('Agent returned non-object JSON');
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
