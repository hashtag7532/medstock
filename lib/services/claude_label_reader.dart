import '../models/medicine.dart';
import 'claude_client.dart';

/// Reads a medicine pack photo with Claude's vision model.
class ClaudeLabelReader {
  ClaudeLabelReader(this._claude);

  final ClaudeClient _claude;

  static const _prompt = '''
This is a photo of a medicine pack sold in India (blister strip, box, bottle or tube).
Read the printed text and extract the fields in the schema.

- brand_name: the product's brand name as printed, including the strength if it is part of the name (e.g. "Dolo 650"). Do not include words like "Tablets IP".
- ingredients: each active ingredient with its strength per unit, as listed under the composition ("Each tablet contains..."). Use the generic name without IP/BP/USP. Omit excipients and colours.
- expiry: the expiry date as YYYY-MM. Indian packs print it as "EXP 03/2027", "Exp. MAR 27" and similar; it is often embossed or faint near the batch number. Do not confuse it with the manufacturing date (MFG/MFD). Use "" if not legible.
- remaining_count: for a blister strip, count the pockets that still contain a tablet/capsule. Use -1 if you cannot tell.
- pack_quantity: units in the pack as printed (e.g. "1x15" means 15 per strip, "100 ml" bottle). Use 0 if not printed.
- common_uses: what this medicine is commonly used for, in at most 10 plain words (e.g. "Fever and mild to moderate pain"), from the pack or the standard uses of its active ingredients. Use "" if unsure.
- Use "" for any text field you cannot read. Never guess values that are not visible.''';

  static final _schema = strictObject({
    'brand_name': jsonString,
    'ingredients': {
      'type': 'array',
      'items': strictObject({
        'name': jsonString,
        'strength': {'type': 'string', 'description': 'e.g. "650 mg" or "10 mg/5 ml"'},
      }),
    },
    'dosage_form': {'type': 'string', 'enum': DosageForm.values.map((f) => f.name).toList()},
    'expiry': {'type': 'string', 'description': 'YYYY-MM or empty'},
    'batch_number': jsonString,
    'manufacturer': jsonString,
    'pack_quantity': jsonInt,
    'remaining_count': jsonInt,
    'common_uses': jsonString,
  });

  Future<Medicine> read(String imagePath) async {
    final data = await _claude.extract(
      content: [await ClaudeClient.fileBlock(imagePath), {'type': 'text', 'text': _prompt}],
      schema: _schema,
      // Reading a label is not reasoning-heavy; keep latency low at the pharmacy counter.
      effort: 'low',
      maxTokens: 4096,
      timeout: const Duration(seconds: 90),
    );
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
      uses: (data['common_uses'] as String? ?? '').trim(),
      createdAt: DateTime.now(),
    );
  }

  /// Looks up common uses for a medicine already in the cabinet (e.g. one
  /// added by on-device OCR or by hand).
  Future<String> lookUpUses(Medicine m) async {
    final data = await _claude.extract(
      content: [
        {
          'type': 'text',
          'text': 'Medicine sold in India: "${m.brandName}" (${m.form.label})'
              '${m.ingredients.isEmpty ? '' : ', composition: ${m.compositionSummary}'}.\n'
              'In at most 10 plain words, what is it commonly used for (e.g. "Fever and mild to moderate pain")? '
              'Use "" if you do not recognise it.',
        },
      ],
      schema: strictObject({'common_uses': jsonString}),
      effort: 'low',
      maxTokens: 1024,
      timeout: const Duration(seconds: 45),
    );
    return (data['common_uses'] as String? ?? '').trim();
  }
}
