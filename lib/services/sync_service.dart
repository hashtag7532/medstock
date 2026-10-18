import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';
import 'api_client.dart';

enum SyncState { idle, syncing, synced, offline, error }

/// Keeps this phone's database and the user's data on the server in step.
///
/// Rows changed on the phone (dirty = 1) are sent up; the server keeps the
/// newest version of each row and replies with everything changed since our
/// last sync (the cursor), which is applied here. The phone keeps working
/// offline; sync catches up whenever the server is reachable.
class SyncService {
  SyncService(this._storage, this._api, {required this.onRemoteChanges}) {
    _storage.changes.addListener(requestSync);
  }

  final AppStorage _storage;
  final ApiClient _api;

  /// Called after rows from the server changed local data.
  final Future<void> Function() onRemoteChanges;

  final state = ValueNotifier<SyncState>(SyncState.idle);
  DateTime? lastSynced;
  String? lastError;

  Database get _db => _storage.db;
  Timer? _debounce;
  bool _running = false;
  bool _again = false;
  bool _disposed = false;

  /// Syncs shortly after local changes stop (batches quick edits).
  void requestSync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), sync);
  }

  Future<void> sync() async {
    if (_disposed) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    state.value = SyncState.syncing;
    try {
      do {
        _again = false;
        await _syncOnce();
      } while (_again && !_disposed);
      lastSynced = DateTime.now();
      lastError = null;
      if (!_disposed) state.value = SyncState.synced;
    } on ApiException catch (e) {
      lastError = e.toString();
      if (!_disposed) state.value = e.status == 0 ? SyncState.offline : SyncState.error;
    } catch (e) {
      lastError = e.toString();
      if (!_disposed) state.value = SyncState.error;
    } finally {
      _running = false;
    }
  }

  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _storage.changes.removeListener(requestSync);
  }

  Future<void> _syncOnce() async {
    final cursor = int.tryParse(await _stateValue('cursor') ?? '') ?? 0;
    final outgoing = await _collectChanges();
    final deletes = await _db.query('sync_deletes');

    final reply = await _api.post('/v1/sync', {
      'cursor': cursor,
      'changes': outgoing.payload,
      'deletes': [for (final d in deletes) {'table': d['table_name'], 'id': d['uid']}],
    });
    if (_disposed) return;

    var changedLocally = false;
    await _db.transaction((txn) async {
      // What we sent is now on the server, unless it was edited again meanwhile.
      for (final sent in outgoing.sent) {
        await txn.update(sent.table, {'dirty': 0},
            where: 'uid = ? AND updated_at = ?', whereArgs: [sent.uid, sent.updatedAt]);
      }
      for (final d in deletes) {
        await txn.delete('sync_deletes', where: 'table_name = ? AND uid = ?', whereArgs: [d['table_name'], d['uid']]);
      }
      changedLocally = await _apply(txn, reply);
      await txn.insert('sync_state', {'key': 'cursor', 'value': '${reply['cursor']}'},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
    if (changedLocally) await onRemoteChanges();
  }

  Future<String?> _stateValue(String key) async {
    final rows = await _db.query('sync_state', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<_Outgoing> _collectChanges() async {
    final out = _Outgoing();

    for (final m in await _db.query('medicines', where: 'dirty = 1 AND uid IS NOT NULL')) {
      out.add('medicines', m, {
        'id': m['uid'],
        'brand_name': m['brand'],
        'ingredients': jsonDecode(m['ingredients'] as String? ?? '[]'),
        'form': m['form'],
        'expiry': m['expiry'],
        'batch_number': m['batch'] ?? '',
        'manufacturer': m['manufacturer'] ?? '',
        'quantity': m['quantity'],
        'unit': m['unit'],
        'uses': m['uses'] ?? '',
        'created_at': DateTime.parse(m['created_at'] as String).toUtc().toIso8601String(),
        'updated_at': m['updated_at'],
      });
    }

    for (final s in await _db.rawQuery('''
        SELECT s.*, m.uid AS medicine_uid FROM schedules s JOIN medicines m ON m.id = s.medicine_id
        WHERE s.dirty = 1 AND s.uid IS NOT NULL''')) {
      out.add('schedules', s, {
        'id': s['uid'],
        'medicine_id': s['medicine_uid'],
        'dose': s['dose'],
        'times': jsonDecode(s['times'] as String),
        'start_date': s['start_date'],
        'duration_days': s['duration_days'],
        'instructions': s['instructions'] ?? '',
        'status': s['status'],
        'updated_at': s['updated_at'],
      });
    }

    for (final l in await _db.rawQuery('''
        SELECT l.*, s.uid AS schedule_uid FROM dose_logs l JOIN schedules s ON s.id = l.schedule_id
        WHERE l.dirty = 1 AND l.uid IS NOT NULL''')) {
      out.add('dose_logs', l, {
        'id': l['uid'],
        'schedule_id': l['schedule_uid'],
        'scheduled_at': l['scheduled_at'],
        'status': l['status'],
        'responded_at': DateTime.parse(l['responded_at'] as String).toUtc().toIso8601String(),
        'updated_at': l['updated_at'],
      });
    }

    for (final r in await _db.query('lab_reports', where: 'dirty = 1 AND uid IS NOT NULL')) {
      final results = await _db.query('lab_results', where: 'report_id = ?', whereArgs: [r['id']], orderBy: 'id');
      out.add('lab_reports', r, {
        'id': r['uid'],
        'title': r['title'],
        'report_date': r['report_date'],
        'lab_name': r['lab_name'] ?? '',
        'updated_at': r['updated_at'],
        'results': [
          for (final x in results)
            {
              'name': x['name'],
              'test_key': x['test_key'],
              'value': x['value'],
              'value_text': x['value_text'],
              'unit': x['unit'],
              'ref_low': x['ref_low'],
              'ref_high': x['ref_high'],
              'panel': x['panel'],
            },
        ],
      });
    }
    return out;
  }

  /// Applies the server's reply. Returns true if any local row changed.
  Future<bool> _apply(Transaction txn, Map<String, dynamic> reply) async {
    final changes = (reply['changes'] as Map?)?.cast<String, dynamic>() ?? const {};
    var changed = false;

    Future<Map<String, Object?>?> local(String table, Object? uid) async {
      final rows = await txn.query(table, where: 'uid = ?', whereArgs: [uid]);
      return rows.isEmpty ? null : rows.first;
    }

    Future<int?> localId(String table, Object? uid) async => (await local(table, uid))?['id'] as int?;

    /// Our unsent edit is newer than the server's copy: keep ours, it goes up next sync.
    bool keepLocal(Map<String, Object?> row, Map server) =>
        row['dirty'] == 1 && DateTime.parse(row['updated_at'] as String).isAfter(DateTime.parse(server['updated_at'] as String));

    bool same(Map<String, Object?> row, Map server) =>
        row['updated_at'] != null &&
        DateTime.parse(row['updated_at'] as String).isAtSameMomentAs(DateTime.parse(server['updated_at'] as String));

    for (final m in (changes['medicines'] as List? ?? []).cast<Map>()) {
      final row = await local('medicines', m['id']);
      if (row != null && (keepLocal(row, m) || same(row, m))) continue;
      final values = {
        'brand': m['brand_name'],
        'ingredients': jsonEncode(m['ingredients'] ?? []),
        'form': m['form'],
        'expiry': m['expiry'],
        'batch': m['batch_number'] ?? '',
        'manufacturer': m['manufacturer'] ?? '',
        'quantity': m['quantity'] ?? 0,
        'unit': m['unit'],
        'uses': m['uses'] ?? '',
        'updated_at': m['updated_at'],
        'dirty': 0,
      };
      if (row == null) {
        await txn.insert('medicines', {...values, 'uid': m['id'], 'created_at': m['created_at']});
      } else {
        await txn.update('medicines', values, where: 'id = ?', whereArgs: [row['id']]);
      }
      changed = true;
    }

    for (final s in (changes['schedules'] as List? ?? []).cast<Map>()) {
      final medicineId = await localId('medicines', s['medicine_id']);
      if (medicineId == null) continue;
      final row = await local('schedules', s['id']);
      if (row != null && (keepLocal(row, s) || same(row, s))) continue;
      final values = {
        'medicine_id': medicineId,
        'dose': s['dose'],
        'times': jsonEncode(s['times']),
        'start_date': s['start_date'],
        'duration_days': s['duration_days'],
        'instructions': s['instructions'] ?? '',
        'status': s['status'],
        'updated_at': s['updated_at'],
        'dirty': 0,
      };
      if (row == null) {
        await txn.insert('schedules', {...values, 'uid': s['id']});
      } else {
        await txn.update('schedules', values, where: 'id = ?', whereArgs: [row['id']]);
      }
      changed = true;
    }

    for (final l in (changes['dose_logs'] as List? ?? []).cast<Map>()) {
      final scheduleId = await localId('schedules', l['schedule_id']);
      if (scheduleId == null) continue;
      // Stock comes down via the medicine row, so a pulled log never changes quantity.
      final id = await txn.insert(
        'dose_logs',
        {
          'uid': l['id'],
          'schedule_id': scheduleId,
          'scheduled_at': l['scheduled_at'],
          'status': l['status'],
          'responded_at': l['responded_at'],
          'updated_at': l['updated_at'],
          'dirty': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      if (id != 0) changed = true;
    }

    for (final r in (changes['lab_reports'] as List? ?? []).cast<Map>()) {
      final row = await local('lab_reports', r['id']);
      if (row != null && (keepLocal(row, r) || same(row, r))) continue;
      final values = {
        'title': r['title'],
        'report_date': DateTime.parse(r['report_date'] as String).toIso8601String(),
        'lab_name': r['lab_name'] ?? '',
        'updated_at': r['updated_at'],
        'dirty': 0,
      };
      int reportId;
      if (row == null) {
        reportId = await txn.insert('lab_reports', {...values, 'uid': r['id'], 'file_paths': '[]'});
      } else {
        reportId = row['id'] as int;
        await txn.update('lab_reports', values, where: 'id = ?', whereArgs: [reportId]);
        await txn.delete('lab_results', where: 'report_id = ?', whereArgs: [reportId]);
      }
      for (final x in (r['results'] as List? ?? []).cast<Map>()) {
        await txn.insert('lab_results', {
          'report_id': reportId,
          'name': x['name'],
          'test_key': x['test_key'],
          'value': x['value'],
          'value_text': x['value_text'] ?? '',
          'unit': x['unit'] ?? '',
          'ref_low': x['ref_low'],
          'ref_high': x['ref_high'],
          'panel': x['panel'] ?? '',
        });
      }
      changed = true;
    }

    for (final d in (reply['deletes'] as List? ?? []).cast<Map>()) {
      final table = d['table'] as String;
      final row = await local(table, d['id']);
      if (row == null) continue;
      final id = row['id'];
      switch (table) {
        case 'medicines':
          await txn.rawDelete(
              'DELETE FROM dose_logs WHERE schedule_id IN (SELECT id FROM schedules WHERE medicine_id = ?)', [id]);
          await txn.delete('schedules', where: 'medicine_id = ?', whereArgs: [id]);
        case 'schedules':
          await txn.delete('dose_logs', where: 'schedule_id = ?', whereArgs: [id]);
        case 'lab_reports':
          await txn.delete('lab_results', where: 'report_id = ?', whereArgs: [id]);
      }
      await txn.delete(table, where: 'id = ?', whereArgs: [id]);
      changed = true;
    }
    return changed;
  }
}

class _Sent {
  const _Sent(this.table, this.uid, this.updatedAt);

  final String table;
  final Object? uid;
  final Object? updatedAt;
}

class _Outgoing {
  final payload = <String, List<Map<String, Object?>>>{};
  final sent = <_Sent>[];

  void add(String table, Map<String, Object?> row, Map<String, Object?> apiRow) {
    payload.putIfAbsent(table, () => []).add(apiRow);
    sent.add(_Sent(table, row['uid'], row['updated_at']));
  }
}
