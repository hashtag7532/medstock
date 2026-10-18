import 'dart:convert';

/// One lab report (a blood test, an annual check-up...), with its files.
class LabReport {
  const LabReport({
    this.id,
    required this.title,
    required this.reportDate,
    this.labName = '',
    this.filePaths = const [],
    this.results = const [],
  });

  final int? id;

  /// e.g. "Complete Blood Count" or "Annual health check-up"
  final String title;
  final DateTime reportDate;
  final String labName;

  /// Photos or PDFs of the report, stored in the app's folder.
  final List<String> filePaths;
  final List<LabResult> results;

  LabReport copyWith({int? id, String? title, DateTime? reportDate, String? labName, List<String>? filePaths, List<LabResult>? results}) =>
      LabReport(
        id: id ?? this.id,
        title: title ?? this.title,
        reportDate: reportDate ?? this.reportDate,
        labName: labName ?? this.labName,
        filePaths: filePaths ?? this.filePaths,
        results: results ?? this.results,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'report_date': reportDate.toIso8601String(),
        'lab_name': labName,
        'file_paths': jsonEncode(filePaths),
      };

  factory LabReport.fromMap(Map<String, Object?> map, List<LabResult> results) => LabReport(
        id: map['id'] as int?,
        title: map['title'] as String? ?? '',
        reportDate: DateTime.parse(map['report_date'] as String),
        labName: map['lab_name'] as String? ?? '',
        filePaths: (jsonDecode(map['file_paths'] as String? ?? '[]') as List).cast<String>(),
        results: results,
      );
}

enum ResultFlag { low, normal, high, unknown }

/// One test value in a report, e.g. Platelet count 85,000 /µL (150,000-410,000).
class LabResult {
  const LabResult({
    required this.name,
    this.value,
    this.valueText = '',
    this.unit = '',
    this.refLow,
    this.refHigh,
    this.panel = '',
  });

  /// Standard test name, used to line up the same test across reports and labs.
  final String name;
  final double? value;

  /// For non-numeric results ("Negative", "Reactive").
  final String valueText;
  final String unit;
  final double? refLow;
  final double? refHigh;

  /// Group on the report, e.g. "Complete Blood Count", "Lipid Profile".
  final String panel;

  /// Key that matches the same test across reports.
  String get key => name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  ResultFlag get flag {
    final v = value;
    if (v == null || (refLow == null && refHigh == null)) return ResultFlag.unknown;
    if (refLow != null && v < refLow!) return ResultFlag.low;
    if (refHigh != null && v > refHigh!) return ResultFlag.high;
    return ResultFlag.normal;
  }

  String get displayValue => value == null ? valueText : formatNumber(value!);

  String get rangeLabel {
    if (refLow != null && refHigh != null) return '${formatNumber(refLow!)} - ${formatNumber(refHigh!)}';
    if (refLow != null) return '> ${formatNumber(refLow!)}';
    if (refHigh != null) return '< ${formatNumber(refHigh!)}';
    return '';
  }

  Map<String, Object?> toMap(int reportId) => {
        'report_id': reportId,
        'name': name,
        'test_key': key,
        'value': value,
        'value_text': valueText,
        'unit': unit,
        'ref_low': refLow,
        'ref_high': refHigh,
        'panel': panel,
      };

  factory LabResult.fromMap(Map<String, Object?> map) => LabResult(
        name: map['name'] as String? ?? '',
        value: (map['value'] as num?)?.toDouble(),
        valueText: map['value_text'] as String? ?? '',
        unit: map['unit'] as String? ?? '',
        refLow: (map['ref_low'] as num?)?.toDouble(),
        refHigh: (map['ref_high'] as num?)?.toDouble(),
        panel: map['panel'] as String? ?? '',
      );
}

/// A test's value on one report date, for trend charts.
class TrendPoint {
  const TrendPoint(this.date, this.result, this.reportId);

  final DateTime date;
  final LabResult result;
  final int reportId;
}

/// One test across all reports, for the Trends list.
class TestSummary {
  const TestSummary(this.key, this.latest, this.count);

  final String key;
  final TrendPoint latest;

  /// Number of reports with this test.
  final int count;
}

String formatNumber(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  final s = v.toStringAsFixed(2);
  return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}
