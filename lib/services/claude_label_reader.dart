import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/medicine.dart';

/// Reads a medicine label photo with Claude's vision model and returns
/// structured fields.
///
/// PROTOTYPE ONLY: the API key is compiled into the app. Before shipping,
/// move this call behind your own backend so the key never reaches devices.
class ClaudeLabelReader {
  ClaudeLabelReader({required this.apiKey, http.Client? client}) : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  static const model = 'claude-opus-5-5';

  static const _prompt = '''
This is a photo of a medicine pack sold in India (blister strip, box, bottle or tube).
Read the printed text and extract the fields in the schema.

- brand_name: the product's brand name as printed, including the strength if it is part of the name (e.g. "Dolo 650"). Do not include words like "Tablets IP".
- ingredients: each active ingredient with its strength per unit, as listed under the composition ("Each tablet contains..."). Use the generic name without IP/BP/USP. Omit excipients and colours.
- expiry: the expiry date as YYYY-MM. Indian packs print it as "EXP 03/2027", "Exp. MAR 27" and similar; it is often embossed or faint near the batch number. Do not confuse it with the manufacturing date (MFG/MFD). Use "" if not legible.
- remaining_count: for a blister strip, count the pockets that still contain a tablet/capsule. Use -1 if you cannot tell.
- pack_quantity: units in the pack as printed (e.g. "1x15" means 15 per strip, "100 ml" bottle). Use 0 if not printed.
- Use "" for any text field you cannot read. Never guess values that are not visible.''';

  static final _schema = {
    'type': 'object',
    'additionalProperties': false,
    'required': [
      'brand_name', 'ingredients', 'dosage_form', 'expiry', 'batch_number',
      'manufacturer', 'pack_quantity', 'remaining_count',
    ],
    'properties': {
      'brand_name': {'type': 'string'},
      'ingredients': {
        'type': 'array',
        'items': {
          'type': 'object',
          'additionalProperties': false,
          'required': ['name', 'strength'],
          'properties': {
            'name': {'type': 'string'},
            'strength': {'type': 'string', 'description': 'e.g. "650 mg" or "10 mg/5 ml"'},
          },
        },
      },
      'dosage_form': {'type': 'string', 'enum': DosageForm.values.map((f) => f.name).toList()},
      'expiry': {'type': 'string', 'description': 'YYYY-MM or empty'},
      'batch_number': {'type': 'string'},
      'manufacturer': {'type': 'string'},
      'pack_quantity': {'type': 'integer'},
      'remaining_count': {'type': 'integer'},
    },
  };

  Future<Medicine> read(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final mediaType = imagePath.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

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
            'max_tokens': 4096,
            'fallbacks': 'default',
            'output_config': {
              // Reading a label is not reasoning-heavy; keep latency low at the pharmacy counter.
              'effort': 'low',
              'format': {'type': 'json_schema', 'schema': _schema},
            },
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'image',
                    'source': {'type': 'base64', 'media_type': mediaType, 'data': base64Encode(bytes)},
                  },
                  {'type': 'text', 'text': _prompt},
                ],
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 90));

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
    return _toMedicine(jsonDecode(text) as Map<String, dynamic>, imagePath);
  }

  Medicine _toMedicine(Map<String, dynamic> data, String imagePath) {
    final form = DosageForm.parse(data['dosage_form'] as String?);
    final remaining = data['remaining_count'] as int? ?? -1;
    final pack = data['pack_quantity'] as int? ?? 0;
    return Medicine(
      brandName: (data['brand_name'] as String? ?? '').trim(),
      ingredients: (data['ingredients'] as List? ?? [])
          .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
          .where((i) => i.name.trim().isNotEmpty)
          .toList(),
      form: form,
      expiry: parseYearMonth(data['expiry'] as String?),
      batchNumber: (data['batch_number'] as String? ?? '').trim(),
      manufacturer: (data['manufacturer'] as String? ?? '').trim(),
      quantity: remaining >= 0 ? remaining : pack,
      unit: form.unit,
      imagePath: imagePath,
      createdAt: DateTime.now(),
    );
  }
}
