import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/lab_report.dart';
import 'app_database.dart';
import 'ids.dart';

class ReportRepository {
  ReportRepository(this._storage);

  final AppStorage _storage;
  Database get _db => _storage.db;
  Directory get _filesDir => _storage.reportFiles;

  /// All reports, newest first, with their results.
  Future<List<LabReport>> all() async {
    final reports = await _db.query('lab_reports', orderBy: 'report_date DESC, id DESC');
    final results = await _db.query('lab_results', orderBy: 'id');
    final byReport = <int, List<LabResult>>{};
    for (final r in results) {
      byReport.putIfAbsent(r['report_id'] as int, () => []).add(LabResult.fromMap(r));
    }
    return [for (final r in reports) LabReport.fromMap(r, byReport[r['id']] ?? const [])];
  }

  Future<LabReport> save(LabReport report) async {
    final files = [for (final f in report.filePaths) await _persistFile(f)];
    final toSave = report.copyWith(filePaths: files);
    final sync = {'updated_at': nowStamp(), 'dirty': 1};
    final saved = await _db.transaction((txn) async {
      var id = toSave.id;
      if (id == null) {
        id = await txn.insert('lab_reports', {...toSave.toMap(), ...sync, 'uid': newUuid()});
      } else {
        await txn.update('lab_reports', {...toSave.toMap(), ...sync}, where: 'id = ?', whereArgs: [id]);
        await txn.delete('lab_results', where: 'report_id = ?', whereArgs: [id]);
      }
      for (final result in toSave.results) {
        await txn.insert('lab_results', result.toMap(id));
      }
      return toSave.copyWith(id: id);
    });
    _storage.markChanged();
    return saved;
  }

  Future<void> delete(LabReport report) async {
    await _db.transaction((txn) async {
      await txn.rawInsert(
          "INSERT OR IGNORE INTO sync_deletes(table_name, uid) SELECT 'lab_reports', uid FROM lab_reports WHERE id = ? AND uid IS NOT NULL",
          [report.id]);
      await txn.delete('lab_results', where: 'report_id = ?', whereArgs: [report.id]);
      await txn.delete('lab_reports', where: 'id = ?', whereArgs: [report.id]);
    });
    _storage.markChanged();
    for (final path in report.filePaths) {
      final file = File(path);
      if (p.isWithin(_filesDir.path, path) && await file.exists()) await file.delete();
    }
  }

  /// Every value of one test across all reports, oldest first.
  Future<List<TrendPoint>> trend(String testKey) async {
    final rows = await _db.rawQuery('''
      SELECT r.*, l.report_date FROM lab_results r
      JOIN lab_reports l ON l.id = r.report_id
      WHERE r.test_key = ?
      ORDER BY l.report_date ASC, l.id ASC
    ''', [testKey]);
    return [
      for (final row in rows)
        TrendPoint(DateTime.parse(row['report_date'] as String), LabResult.fromMap(row), row['report_id'] as int),
    ];
  }

  /// Every test seen across reports with its latest value, most-tracked first.
  Future<List<TestSummary>> tests() async {
    final rows = await _db.rawQuery('''
      SELECT r.*, l.report_date FROM lab_results r
      JOIN lab_reports l ON l.id = r.report_id
      ORDER BY l.report_date DESC, l.id DESC
    ''');
    final latest = <String, TrendPoint>{};
    final counts = <String, int>{};
    for (final row in rows) {
      final key = row['test_key'] as String;
      counts[key] = (counts[key] ?? 0) + 1;
      latest.putIfAbsent(
        key,
        () => TrendPoint(DateTime.parse(row['report_date'] as String), LabResult.fromMap(row), row['report_id'] as int),
      );
    }
    return [for (final key in latest.keys) TestSummary(key, latest[key]!, counts[key]!)]
      ..sort((a, b) => b.count != a.count ? b.count - a.count : a.latest.result.name.compareTo(b.latest.result.name));
  }

  /// The most recent earlier value of each test, for "vs last time".
  Future<Map<String, TrendPoint>> previousValues(LabReport report) async {
    final rows = await _db.rawQuery('''
      SELECT r.*, l.report_date FROM lab_results r
      JOIN lab_reports l ON l.id = r.report_id
      WHERE l.report_date < ? AND l.id != ?
      ORDER BY l.report_date DESC
    ''', [report.reportDate.toIso8601String(), report.id ?? -1]);
    final previous = <String, TrendPoint>{};
    for (final row in rows) {
      previous.putIfAbsent(
        row['test_key'] as String,
        () => TrendPoint(DateTime.parse(row['report_date'] as String), LabResult.fromMap(row), row['report_id'] as int),
      );
    }
    return previous;
  }

  Future<String> _persistFile(String path) async {
    if (p.isWithin(_filesDir.path, path)) return path;
    final target = p.join(_filesDir.path, '${DateTime.now().microsecondsSinceEpoch}${p.extension(path)}');
    await File(path).copy(target);
    return target;
  }
}
