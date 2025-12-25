import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models/generate_story_request.dart';
import 'models/generate_story_response.dart';

class StoryService {
  /// Set your Agent endpoint here (Cloud Function HTTPS endpoint or your server).
  /// Example:
  /// https://<region>-<project>.cloudfunctions.net/generateStory
  final String endpointUrl;

  const StoryService({required this.endpointUrl});

  Future<GenerateStoryResponse> generateStory(GenerateStoryRequest req) async {
    final json = await _post(req.toJson());
    return GenerateStoryResponse.fromJson(json);
  }

  Future<GenerateStoryResponse> continueStory(GenerateStoryRequest req) async {
    final json = await _post(req.toJson());
    return GenerateStoryResponse.fromJson(json);
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    final uri = Uri.parse(endpointUrl);
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.add(utf8.encode(jsonEncode(body)));

      final response = await request.close();
      final text = await utf8.decodeStream(response);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Agent error ${response.statusCode}: $text',
          uri: uri,
        );
      }

      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Agent response must be a JSON object');
      }

      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> callAgentJson(Map<String, dynamic> body) async {
    final uri = Uri.parse(endpointUrl);

    debugPrint('POST -> $uri');
    debugPrint('REQUEST -> ${jsonEncode(body)}');

    final resp = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));

    final text = resp.body;
    debugPrint('STATUS -> ${resp.statusCode}');
    debugPrint(
      'RESPONSE -> ${text.length > 800 ? text.substring(0, 800) : text}',
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Agent error ${resp.statusCode}: $text');
    }

    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;

    throw Exception('Agent returned non-object JSON: $decoded');
  }
}
