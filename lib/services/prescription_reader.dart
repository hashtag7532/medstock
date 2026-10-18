import '../models/medicine.dart';
import '../models/schedule.dart';
import 'claude_client.dart';

/// One medicine line read from a prescription.
class PrescriptionItem {
  const PrescriptionItem({
    required this.name,
    this.strength = '',
    this.form = DosageForm.other,
    this.activeIngredients = '',
    this.dosePerIntake = 1,
    this.times = const [],
    this.durationDays,
    this.asNeeded = false,
    this.instructions = '',
  });

  final String name;
  final String strength;
  final DosageForm form;

  /// Generic names if written on the prescription, e.g. "Paracetamol".
  final String activeIngredients;
  final int dosePerIntake;
  final List<DoseTime> times;

  /// Null when the prescription gives no duration.
  final int? durationDays;

  /// "SOS" medicines: no fixed schedule.
  final bool asNeeded;
  final String instructions;

  String get displayName => strength.isEmpty || name.contains(strength) ? name : '$name $strength';
}

/// Reads a doctor's prescription (handwritten or printed) with Claude.
class PrescriptionReader {
  PrescriptionReader(this._claude);

  final ClaudeClient _claude;

  static const _prompt = '''
This is a photo of a doctor's prescription from India (printed or handwritten).
List every medicine prescribed, in the schema.

- name: the medicine as written, without "Tab"/"Cap"/"Syp" prefixes (e.g. "Dolo 650", "Azithromycin").
- strength: e.g. "650 mg", "" if not written.
- active_ingredients: generic names if written on the prescription, else "".
- dose_per_intake: units per dose (tablets, capsules; ml for syrups, e.g. 5).
- morning / afternoon / night: from notation like "1-0-1" (morning-afternoon-night), "OD" (once: morning), "BD" (twice: morning and night), "TDS" (three times), "HS" (night only).
- times_per_day: total doses per day (e.g. QID = 4).
- duration_days: from "x 5 days", "for 1 week" (7), "1 month" (30). 0 if not written.
- as_needed: true for "SOS" or "as needed".
- instructions: e.g. "After food", "Before breakfast", "" if none.
Do not include the patient's name, age or other personal details. If a line is illegible, give your best reading of the name and leave other fields at their defaults.''';

  static final _schema = strictObject({
    'medicines': {
      'type': 'array',
      'items': strictObject({
        'name': jsonString,
        'strength': jsonString,
        'dosage_form': {'type': 'string', 'enum': DosageForm.values.map((f) => f.name).toList()},
        'active_ingredients': jsonString,
        'dose_per_intake': jsonInt,
        'morning': jsonBool,
        'afternoon': jsonBool,
        'night': jsonBool,
        'times_per_day': jsonInt,
        'duration_days': jsonInt,
        'as_needed': jsonBool,
        'instructions': jsonString,
      }),
    },
  });

  Future<List<PrescriptionItem>> read(List<String> imagePaths) async {
    final data = await _claude.extract(
      content: [
        for (final path in imagePaths) await ClaudeClient.fileBlock(path),
        {'type': 'text', 'text': _prompt},
      ],
      schema: _schema,
      // Handwriting benefits from a little more care.
      effort: 'medium',
      timeout: const Duration(seconds: 150),
    );
    return [
      for (final m in (data['medicines'] as List? ?? []).cast<Map<String, dynamic>>())
        if ((m['name'] as String? ?? '').trim().isNotEmpty) _toItem(m),
    ];
  }

  PrescriptionItem _toItem(Map<String, dynamic> m) {
    final times = <DoseTime>[
      if (m['morning'] == true) DoseTime.morning,
      if (m['afternoon'] == true) DoseTime.afternoon,
      if (m['night'] == true) DoseTime.night,
    ];
    final perDay = m['times_per_day'] as int? ?? 0;
    final days = m['duration_days'] as int? ?? 0;
    final dose = m['dose_per_intake'] as int? ?? 1;
    return PrescriptionItem(
      name: (m['name'] as String).trim(),
      strength: (m['strength'] as String? ?? '').trim(),
      form: DosageForm.parse(m['dosage_form'] as String?),
      activeIngredients: (m['active_ingredients'] as String? ?? '').trim(),
      dosePerIntake: dose < 1 ? 1 : dose,
      times: times.length >= perDay || perDay == 0 ? times : DoseTime.defaultsFor(perDay),
      durationDays: days > 0 ? days : null,
      asNeeded: m['as_needed'] == true,
      instructions: (m['instructions'] as String? ?? '').trim(),
    );
  }
}

/// Finds the cabinet medicine a prescription line refers to: same brand, or
/// a single-ingredient medicine whose ingredient and strength match.
Medicine? matchPrescriptionItem(PrescriptionItem item, List<Medicine> cabinet) {
  String key(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  final draft = Medicine(brandName: item.displayName, form: item.form, createdAt: DateTime.now());
  for (final m in cabinet) {
    if (m.brandKey.isNotEmpty && (m.brandKey == draft.brandKey || m.brandKey == key(item.name))) return m;
  }
  final digits = RegExp(r'\d+(\.\d+)?').firstMatch(item.displayName)?.group(0);
  final haystack = key('${item.name} ${item.activeIngredients}');
  for (final m in cabinet) {
    if (m.ingredients.length != 1) continue;
    final ingredient = m.ingredients.first;
    final name = key(ingredient.name.replaceAll(RegExp(r'\b(IP|BP|USP)\b'), ''));
    final sameStrength = digits == null || ingredient.strength.contains(digits);
    if (name.length >= 4 && haystack.contains(name) && sameStrength) return m;
  }
  return null;
}
