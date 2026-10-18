import '../models/lab_report.dart';
import 'claude_client.dart';

/// Reads lab reports (photos or PDF, one or many pages) with Claude.
class LabReportReader {
  LabReportReader(this._claude);

  final ClaudeClient _claude;

  static const _prompt = '''
These are the pages of one medical lab report from India (blood test, health check-up, etc.).
Extract every test result in the schema.

- title: a short name for the report, e.g. "Complete Blood Count", "Dengue panel", "Annual health check-up".
- lab_name: the laboratory or hospital name, "" if not shown.
- report_date: the date the sample was collected (or else the report date) as YYYY-MM-DD, "" if not shown.
- results: one entry per test.
  - test_name: a standard, commonly used name so the same test lines up across different labs, e.g. "Hemoglobin", "Platelet count", "Total leukocyte count (WBC)", "Hematocrit (PCV)", "HbA1c", "Fasting blood glucose", "TSH", "LDL cholesterol", "Serum creatinine", "Vitamin D (25-OH)", "Dengue NS1 antigen".
  - value: the numeric result as plain digits ("85000", "13.4"), or "" if the result is not a number. Convert lakhs to the full number (1.5 lakh = 150000). For cell counts reported as x10^3/uL or thousands/cumm, give the full number per uL (150 x10^3/uL = 150000).
  - value_text: the result as printed when it is not a number ("Negative", "Reactive"), else "".
  - unit: the unit after any conversion above, e.g. "/uL", "g/dL", "mg/dL", "%".
  - ref_low / ref_high: the reference range bounds as plain digits in the same unit as value, "" if not given.
  - panel: the section heading the test is under, e.g. "Complete Blood Count", "Lipid Profile".
Do not include the patient's name, age, ID or other personal details. Only report what is printed.''';

  static final _schema = strictObject({
    'title': jsonString,
    'lab_name': jsonString,
    'report_date': jsonString,
    'results': {
      'type': 'array',
      'items': strictObject({
        'test_name': jsonString,
        'value': jsonString,
        'value_text': jsonString,
        'unit': jsonString,
        'ref_low': jsonString,
        'ref_high': jsonString,
        'panel': jsonString,
      }),
    },
  });

  Future<LabReport> read(List<String> filePaths) async {
    final data = await _claude.extract(
      content: [
        for (final path in filePaths) await ClaudeClient.fileBlock(path),
        {'type': 'text', 'text': _prompt},
      ],
      schema: _schema,
      // Tables with many rows: accuracy matters more than speed here.
      effort: 'medium',
      timeout: const Duration(seconds: 240),
    );
    return LabReport(
      title: (data['title'] as String? ?? '').trim(),
      labName: (data['lab_name'] as String? ?? '').trim(),
      reportDate: DateTime.tryParse(data['report_date'] as String? ?? '') ?? DateTime.now(),
      filePaths: filePaths,
      results: [
        for (final r in (data['results'] as List? ?? []).cast<Map<String, dynamic>>())
          if ((r['test_name'] as String? ?? '').trim().isNotEmpty)
            LabResult(
              name: (r['test_name'] as String).trim(),
              value: parseNumber(r['value']),
              valueText: (r['value_text'] as String? ?? '').trim(),
              unit: (r['unit'] as String? ?? '').trim(),
              refLow: parseNumber(r['ref_low']),
              refHigh: parseNumber(r['ref_high']),
              panel: (r['panel'] as String? ?? '').trim(),
            ),
      ],
    );
  }
}
