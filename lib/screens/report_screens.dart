import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app_services.dart';
import '../models/lab_report.dart';
import '../models/medicine.dart';
import '../services/claude_client.dart' show parseNumber;
import '../widgets/report_widgets.dart';

class _ResultRow {
  _ResultRow(LabResult r)
      : panel = r.panel,
        name = TextEditingController(text: r.name),
        value = TextEditingController(text: r.displayValue),
        unit = TextEditingController(text: r.unit),
        low = TextEditingController(text: r.refLow == null ? '' : formatNumber(r.refLow!)),
        high = TextEditingController(text: r.refHigh == null ? '' : formatNumber(r.refHigh!));

  final String panel;
  final TextEditingController name, value, unit, low, high;

  LabResult toResult() {
    final number = parseNumber(value.text);
    return LabResult(
      name: name.text.trim(),
      value: number,
      valueText: number == null ? value.text.trim() : '',
      unit: unit.text.trim(),
      refLow: parseNumber(low.text),
      refHigh: parseNumber(high.text),
      panel: panel,
    );
  }

  void dispose() {
    for (final c in [name, value, unit, low, high]) {
      c.dispose();
    }
  }
}

/// Check (or type in) a report's values before saving.
class ReportReviewScreen extends StatefulWidget {
  const ReportReviewScreen({super.key, required this.services, required this.initial});

  final AppServices services;
  final LabReport initial;

  @override
  State<ReportReviewScreen> createState() => _ReportReviewScreenState();
}

class _ReportReviewScreenState extends State<ReportReviewScreen> {
  late final _title = TextEditingController(text: widget.initial.title);
  late final _lab = TextEditingController(text: widget.initial.labName);
  late DateTime _date = widget.initial.reportDate;
  late final _rows = widget.initial.results.map(_ResultRow.new).toList();
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _lab.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.services.reports.save(widget.initial.copyWith(
      title: _title.text.trim().isEmpty ? 'Lab report' : _title.text.trim(),
      labName: _lab.text.trim(),
      reportDate: _date,
      results: _rows.map((r) => r.toResult()).where((r) => r.name.isNotEmpty).toList(),
    ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.initial.id == null ? 'Check report' : 'Edit report')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          if (widget.initial.id == null && widget.initial.results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Read automatically. Check the values against the report before saving.',
                  style: theme.textTheme.bodySmall),
            ),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Report name')),
          const SizedBox(height: 8),
          TextField(controller: _lab, decoration: const InputDecoration(labelText: 'Lab or hospital')),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: const Text('Sample date'),
            subtitle: Text(formatDay(_date)),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text('Results (${_rows.length})', style: theme.textTheme.titleSmall)),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add test'),
              onPressed: () => setState(() => _rows.add(_ResultRow(const LabResult(name: '')))),
            ),
          ]),
          for (final row in _rows)
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 12),
                child: Column(children: [
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: row.name,
                        decoration: const InputDecoration(labelText: 'Test', isDense: true),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() => _rows.remove(row));
                        WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
                      },
                    ),
                  ]),
                  Row(children: [
                    Expanded(flex: 3, child: _small(row.value, 'Result')),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: _small(row.unit, 'Unit')),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: _small(row.low, 'Low')),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: _small(row.high, 'High')),
                    const SizedBox(width: 8),
                  ]),
                ]),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(onPressed: _saving ? null : _save, child: const Text('Save report')),
        ),
      ),
    );
  }

  Widget _small(TextEditingController c, String label) =>
      TextField(controller: c, decoration: InputDecoration(labelText: label, isDense: true));
}

/// One report: its values by section, each compared with the previous report.
class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({super.key, required this.services, required this.report});

  final AppServices services;
  final LabReport report;

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  Map<String, TrendPoint> _previous = {};

  @override
  void initState() {
    super.initState();
    widget.services.reports.previousValues(widget.report).then((p) {
      if (mounted) setState(() => _previous = p);
    });
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this report?'),
        content: const Text('Its values and files will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.services.reports.delete(widget.report);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.report;
    final panels = <String, List<LabResult>>{};
    for (final result in r.results) {
      panels.putIfAbsent(result.panel.isEmpty ? 'Results' : result.panel, () => []).add(result);
    }
    final images = r.filePaths.where((f) => !f.toLowerCase().endsWith('.pdf')).toList();
    final pdfs = r.filePaths.where((f) => f.toLowerCase().endsWith('.pdf')).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(r.title),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ReportReviewScreen(services: widget.services, initial: r),
              ));
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          ListTile(
            title: Text(formatDay(r.reportDate)),
            subtitle: Text([
              if (r.labName.isNotEmpty) r.labName,
              if (images.isNotEmpty) '${images.length} photo${images.length == 1 ? '' : 's'}',
              if (pdfs > 0) '$pdfs PDF',
            ].join(' · ')),
          ),
          if (images.isNotEmpty)
            SizedBox(
              height: 96,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(),
                      body: InteractiveViewer(maxScale: 5, child: Center(child: Image.file(File(images[i])))),
                    ),
                  )),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(images[i]), width: 72, height: 96, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          for (final entry in panels.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Text(entry.key, style: theme.textTheme.titleSmall),
            ),
            for (final result in entry.value) _resultTile(result),
          ],
        ],
      ),
    );
  }

  Widget _resultTile(LabResult result) {
    final prev = _previous[result.key];
    String? change;
    if (prev != null && prev.result.value != null && result.value != null) {
      final diff = result.value! - prev.result.value!;
      final arrow = diff > 0 ? '↑' : (diff < 0 ? '↓' : '→');
      change = '$arrow from ${prev.result.displayValue} on ${formatDay(prev.date)}';
    }
    return ListTile(
      dense: true,
      title: Text(result.name),
      subtitle: Text([
        if (result.rangeLabel.isNotEmpty) 'Range ${result.rangeLabel}',
        if (change != null) change,
      ].join('\n')),
      isThreeLine: change != null && result.rangeLabel.isNotEmpty,
      trailing: ResultValue(result),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => TrendScreen(services: widget.services, testKey: result.key, testName: result.name),
      )),
    );
  }
}

/// One test over time: a chart with the normal range shaded, and every value.
class TrendScreen extends StatefulWidget {
  const TrendScreen({super.key, required this.services, required this.testKey, required this.testName});

  final AppServices services;
  final String testKey;
  final String testName;

  @override
  State<TrendScreen> createState() => _TrendScreenState();
}

class _TrendScreenState extends State<TrendScreen> {
  List<TrendPoint>? _points;

  @override
  void initState() {
    super.initState();
    widget.services.reports.trend(widget.testKey).then((p) {
      if (mounted) setState(() => _points = p);
    });
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    return Scaffold(
      appBar: AppBar(title: Text(widget.testName)),
      body: points == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (points.where((p) => p.result.value != null).length >= 2) ...[
                  SizedBox(height: 240, child: _chart(context, points)),
                  const SizedBox(height: 8),
                  if (points.map((p) => p.result.unit).toSet().length > 1)
                    Text('Note: these reports use different units, so values may not be directly comparable.',
                        style: TextStyle(color: Colors.orange.shade900)),
                  const SizedBox(height: 16),
                ] else
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text('Add another report with this test to see a trend.'),
                  ),
                for (final p in points.reversed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(formatDay(p.date)),
                    subtitle: p.result.rangeLabel.isEmpty ? null : Text('Range ${p.result.rangeLabel}'),
                    trailing: ResultValue(p.result),
                  ),
              ],
            ),
    );
  }

  Widget _chart(BuildContext context, List<TrendPoint> points) {
    final scheme = Theme.of(context).colorScheme;
    final numeric = points.where((p) => p.result.value != null).toList();
    final first = numeric.first.date;
    double x(DateTime d) => d.difference(first).inHours / 24;
    final spots = [for (final p in numeric) FlSpot(x(p.date), p.result.value!)];
    final latest = numeric.last.result;
    final values = [
      ...spots.map((s) => s.y),
      if (latest.refLow != null) latest.refLow!,
      if (latest.refHigh != null) latest.refHigh!,
    ];
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    final pad = (hi - lo) == 0 ? (hi.abs() * 0.1 + 1) : (hi - lo) * 0.15;
    final maxX = spots.last.x == 0 ? 1.0 : spots.last.x;

    return LineChart(LineChartData(
      minX: 0,
      maxX: maxX,
      minY: (lo - pad) < 0 && lo >= 0 ? 0 : lo - pad,
      maxY: hi + pad,
      gridData: const FlGridData(drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      rangeAnnotations: RangeAnnotations(horizontalRangeAnnotations: [
        if (latest.refLow != null || latest.refHigh != null)
          HorizontalRangeAnnotation(
            y1: latest.refLow ?? (lo - pad),
            y2: latest.refHigh ?? (hi + pad),
            color: Colors.green.withValues(alpha: 0.12),
          ),
      ]),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 52,
            getTitlesWidget: (value, meta) =>
                SideTitleWidget(meta: meta, child: Text(_compact(value), style: const TextStyle(fontSize: 11))),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: maxX / 3 < 1 ? 1 : maxX / 3,
            getTitlesWidget: (value, meta) {
              final d = first.add(Duration(hours: (value * 24).round()));
              final label = maxX > 300 ? '${monthNames[d.month - 1]} ${d.year % 100}' : '${d.day} ${monthNames[d.month - 1]}';
              return SideTitleWidget(meta: meta, child: Text(label, style: const TextStyle(fontSize: 11)));
            },
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          color: scheme.primary,
          barWidth: 2.5,
          dotData: const FlDotData(show: true),
        ),
      ],
    ));
  }

  static String _compact(double v) {
    if (v.abs() >= 100000) return '${formatNumber(v / 100000)}L';
    if (v.abs() >= 1000) return '${formatNumber(v / 1000)}k';
    return formatNumber(double.parse(v.toStringAsFixed(1)));
  }
}
