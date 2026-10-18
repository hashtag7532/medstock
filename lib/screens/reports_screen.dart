import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_services.dart';
import '../models/lab_report.dart';
import '../models/medicine.dart';
import '../widgets/report_widgets.dart';
import 'report_screens.dart';

enum _View { reports, trends }

/// All lab reports, and every test's trend across them.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<LabReport> _reports = [];
  List<TestSummary> _tests = [];
  bool _loading = true;
  _View _view = _View.reports;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final reports = await widget.services.reports.all();
    final tests = await widget.services.reports.tests();
    if (!mounted) return;
    setState(() {
      _reports = reports;
      _tests = tests;
      _loading = false;
    });
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    await _load();
  }

  Future<void> _add() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(context, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose photos (one per page)'),
            onTap: () => Navigator.pop(context, 'gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Upload PDF'),
            onTap: () => Navigator.pop(context, 'pdf'),
          ),
        ]),
      ),
    );
    if (source == null) return;

    final files = <String>[];
    switch (source) {
      case 'camera':
        final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 2400, imageQuality: 90);
        if (x != null) files.add(x.path);
      case 'gallery':
        files.addAll((await ImagePicker().pickMultiImage(maxWidth: 2400, imageQuality: 90)).map((x) => x.path));
      case 'pdf':
        final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
        files.addAll(picked.map((f) => f.path).whereType<String>());
    }
    if (files.isEmpty || !mounted) return;

    var draft = LabReport(title: '', reportDate: DateTime.now(), filePaths: files);
    final reader = widget.services.labReports;
    if (reader != null) {
      final result = await showDialog<Object>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _ReadingDialog(future: reader.read(files)),
      );
      if (!mounted) return;
      if (result is LabReport) {
        draft = result;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not read the report ($result). Enter values by hand.')),
        );
      }
    }
    await _open(ReportReviewScreen(services: widget.services, initial: draft));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Health reports')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SegmentedButton<_View>(
            segments: [
              ButtonSegment(value: _View.reports, label: Text('Reports (${_reports.length})')),
              ButtonSegment(value: _View.trends, label: Text('Trends (${_tests.length})')),
            ],
            selected: {_view},
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _reports.isEmpty
                  ? const _EmptyReports()
                  : _view == _View.reports
                      ? _reportList()
                      : _trendList(),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Add report'),
        onPressed: _add,
      ),
    );
  }

  Widget _reportList() => ListView.separated(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: _reports.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final r = _reports[i];
          final flagged = r.results.where((x) => x.flag == ResultFlag.low || x.flag == ResultFlag.high).length;
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.description_outlined)),
            title: Text(r.title.isEmpty ? 'Report' : r.title),
            subtitle: Text([
              formatDay(r.reportDate),
              if (r.labName.isNotEmpty) r.labName,
              '${r.results.length} tests',
            ].join(' · ')),
            trailing: flagged == 0 ? null : Chip(label: Text('$flagged outside range')),
            onTap: () => _open(ReportDetailScreen(services: widget.services, report: r)),
          );
        },
      );

  Widget _trendList() => ListView.separated(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: _tests.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final t = _tests[i];
          final r = t.latest.result;
          return ListTile(
            title: Text(r.name),
            subtitle: Text('${t.count} ${t.count == 1 ? 'report' : 'reports'} · latest ${formatDay(t.latest.date)}'),
            trailing: ResultValue(r),
            onTap: () => _open(TrendScreen(services: widget.services, testKey: t.key, testName: r.name)),
          );
        },
      );
}

class _ReadingDialog extends StatefulWidget {
  const _ReadingDialog({required this.future});

  final Future<LabReport> future;

  @override
  State<_ReadingDialog> createState() => _ReadingDialogState();
}

class _ReadingDialogState extends State<_ReadingDialog> {
  @override
  void initState() {
    super.initState();
    // Close with the report, or with the error text.
    widget.future.then(
      (report) {
        if (mounted) Navigator.of(context).pop(report);
      },
      onError: (Object e) {
        if (mounted) Navigator.of(context).pop(e.toString());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Row(children: [
        CircularProgressIndicator(),
        SizedBox(width: 20),
        Expanded(child: Text('Reading the report. This can take a minute for long reports.')),
      ]),
    );
  }
}

class _EmptyReports extends StatelessWidget {
  const _EmptyReports();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.monitor_heart_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text('No reports yet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Add blood test or check-up reports as photos or PDFs. Values are read automatically, '
            'so you can compare them over days (e.g. platelets in dengue) or years.',
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }
}
