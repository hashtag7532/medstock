import 'package:sqflite/sqflite.dart';

import '../models/schedule.dart';

class ScheduleRepository {
  ScheduleRepository(this._db);

  final Database _db;

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
    if (schedule.id == null) {
      final id = await _db.insert('schedules', schedule.toMap());
      return schedule.copyWith(id: id);
    }
    await _db.update('schedules', schedule.toMap(), where: 'id = ?', whereArgs: [schedule.id]);
    return schedule;
  }

  Future<void> setStatus(int scheduleId, ScheduleStatus status) =>
      _db.update('schedules', {'status': status.name}, where: 'id = ?', whereArgs: [scheduleId]);

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
  Future<bool> recordDose(DoseSchedule schedule, DateTime at, DoseStatus status) {
    return _db.transaction((txn) async {
      final id = await txn.insert(
        'dose_logs',
        {
          'schedule_id': schedule.id,
          'scheduled_at': doseKey(at),
          'status': status.name,
          'responded_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      if (id == 0) return false;
      if (status == DoseStatus.taken) {
        await txn.rawUpdate(
          'UPDATE medicines SET quantity = MAX(0, quantity - ?) WHERE id = ?',
          [schedule.dosePerIntake, schedule.medicineId],
        );
      }
      return true;
    });
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
