import 'package:sqflite/sqflite.dart';

import '../models/schedule.dart';
import 'app_database.dart';
import 'ids.dart';

class ScheduleRepository {
  ScheduleRepository(this._storage);

  final AppStorage _storage;
  Database get _db => _storage.db;

  Future<List<DoseSchedule>> all({bool activeOnly = false}) async {
    final rows = await _db.query(
      'schedules',
      where: activeOnly ? 'status = ?' : null,
      whereArgs: activeOnly ? [ScheduleStatus.active.name] : null,
      orderBy: 'id DESC',
    );
    return rows.map(DoseSchedule.fromMap).toList();
  }

  Future<DoseSchedule?> byId(int id) async {
    final rows = await _db.query('schedules', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : DoseSchedule.fromMap(rows.first);
  }

  Future<List<DoseSchedule>> forMedicine(int medicineId) async {
    final rows = await _db.query('schedules', where: 'medicine_id = ?', whereArgs: [medicineId], orderBy: 'id DESC');
    return rows.map(DoseSchedule.fromMap).toList();
  }

  Future<DoseSchedule> save(DoseSchedule schedule) async {
    final sync = {'updated_at': nowStamp(), 'dirty': 1};
    if (schedule.id == null) {
      final id = await _db.insert('schedules', {...schedule.toMap(), ...sync, 'uid': newUuid()});
      _storage.markChanged();
      return schedule.copyWith(id: id);
    }
    await _db.update('schedules', {...schedule.toMap(), ...sync}, where: 'id = ?', whereArgs: [schedule.id]);
    _storage.markChanged();
    return schedule;
  }

  Future<void> setStatus(int scheduleId, ScheduleStatus status) async {
    await _db.update('schedules', {'status': status.name, 'updated_at': nowStamp(), 'dirty': 1},
        where: 'id = ?', whereArgs: [scheduleId]);
    _storage.markChanged();
  }

  Future<List<DoseLog>> logs({int? scheduleId}) async {
    final rows = await _db.query(
      'dose_logs',
      where: scheduleId == null ? null : 'schedule_id = ?',
      whereArgs: scheduleId == null ? null : [scheduleId],
    );
    return rows.map(DoseLog.fromMap).toList();
  }

  /// Records a response to one dose. "Taken" also reduces the medicine's
  /// stock. Returns false if this dose was already answered.
  Future<bool> recordDose(DoseSchedule schedule, DateTime at, DoseStatus status) async {
    final stamp = nowStamp();
    final recorded = await _db.transaction((txn) async {
      final id = await txn.insert(
        'dose_logs',
        {
          'schedule_id': schedule.id,
          'scheduled_at': doseKey(at),
          'status': status.name,
          'responded_at': DateTime.now().toIso8601String(),
          'uid': newUuid(),
          'updated_at': stamp,
          'dirty': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      if (id == 0) return false;
      if (status == DoseStatus.taken) {
        await txn.rawUpdate(
          'UPDATE medicines SET quantity = MAX(0, quantity - ?), updated_at = ?, dirty = 1 WHERE id = ?',
          [schedule.dosePerIntake, stamp, schedule.medicineId],
        );
      }
      return true;
    });
    if (recorded) _storage.markChanged();
    return recorded;
  }

  /// Marks finished courses as completed.
  Future<void> completeEnded() async {
    final now = DateTime.now();
    for (final s in await all(activeOnly: true)) {
      final end = s.endDate;
      if (end != null && !now.isBefore(end)) await setStatus(s.id!, ScheduleStatus.completed);
    }
  }
}
