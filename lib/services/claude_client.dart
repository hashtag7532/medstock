import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Minimal Claude Messages API client that returns JSON matching a schema.
///
/// PROTOTYPE ONLY: the API key is compiled into the app. Before shipping,
/// move these calls behind your own backend so the key never reaches devices.
class ClaudeClient {
  ClaudeClient({required this.apiKey, http.Client? client}) : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  static const model = 'claude-opus-5-5';

  /// A content block for a photo or PDF on disk.
  static Future<Map<String, Object?>> fileBlock(String path) async {
    final data = base64Encode(await File(path).readAsBytes());
    final lower = path.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return {
        'type': 'document',
        'source': {'type': 'base64', 'media_type': 'application/pdf', 'data': data},
      };
    }
    final mediaType = lower.endsWith('.png')
        ? 'image/png'
        : lower.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';
    return {
      'type': 'image',
      'source': {'type': 'base64', 'media_type': mediaType, 'data': data},
    };
  }

  /// Sends [content] (files first, then the prompt) and returns the parsed
  /// JSON object, which the API guarantees matches [schema].
  Future<Map<String, dynamic>> extract({
    required List<Map<String, Object?>> content,
    required Map<String, Object?> schema,
    String effort = 'low',
    int maxTokens = 16000,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final response = await _client
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'content-type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
            // If a safety classifier declines, the API retries on a fallback model.
            'anthropic-beta': 'server-side-fallback-2026-07-01',
          },
          body: jsonEncode({
            'model': model,
            'max_tokens': maxTokens,
            'fallbacks': 'default',
            'output_config': {
              'effort': effort,
              'format': {'type': 'json_schema', 'schema': schema},
            },
            'messages': [
              {'role': 'user', 'content': content},
            ],
          }),
        )
        .timeout(timeout);

    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode != 200) {
      throw HttpException('Claude API returned ${response.statusCode}: $body');
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    final stopReason = json['stop_reason'];
    if (stopReason == 'refusal' || stopReason == 'max_tokens') {
      throw HttpException('Claude stopped early ($stopReason)');
    }
    final text = (json['content'] as List)
        .where((block) => block['type'] == 'text')
        .map((block) => block['text'] as String)
        .join();
    return jsonDecode(text) as Map<String, dynamic>;
  }
}

/// Builds a strict JSON schema object: every property required, no extras.
Map<String, Object?> strictObject(Map<String, Object?> properties) => {
      'type': 'object',
      'additionalProperties': false,
      'required': properties.keys.toList(),
      'properties': properties,
    };

const jsonString = {'type': 'string'};
const jsonInt = {'type': 'integer'};
const jsonBool = {'type': 'boolean'};

/// Parses a number Claude returned as text ("85000", "" for none).
double? parseNumber(Object? value) {
  if (value is num) return value.toDouble();
  final s = (value as String? ?? '').replaceAll(',', '').trim();
  return s.isEmpty ? null : double.tryParse(s);
}
