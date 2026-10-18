import 'package:flutter/foundation.dart';

import '../data/medicine_repository.dart';
import '../data/schedule_repository.dart';
import '../models/medicine.dart';
import '../models/schedule.dart';
import 'dose_notifications.dart';

/// One dose on the "Doses" screen.
class DoseOccurrence {
  const DoseOccurrence(this.schedule, this.medicine, this.at, this.status);

  final DoseSchedule schedule;
  final Medicine medicine;
  final DateTime at;

  /// Null = not answered yet.
  final DoseStatus? status;
}

/// Course progress for one schedule.
class CourseProgress {
  const CourseProgress(this.schedule, this.medicine, this.taken, this.skipped, this.remainingDoses);

  final DoseSchedule schedule;
  final Medicine medicine;
  final int taken;
  final int skipped;

  /// Doses still to come (null for ongoing courses).
  final int? remainingDoses;

  /// Units needed to finish the course, vs [Medicine.quantity].
  int? get unitsNeeded => remainingDoses == null ? null : remainingDoses! * schedule.dosePerIntake;
  bool get runsShort => unitsNeeded != null && unitsNeeded! > medicine.quantity;
}

/// Ties schedules, stock and reminders together: a "Yes" reduces stock,
/// "Skipped" just records it, "Stopped" ends the course and its reminders.
class DoseService {
  DoseService(this._schedules, this._medicines, this._notifications) {
    _notifications.onResponse = processResponses;
  }

  final ScheduleRepository _schedules;
  final MedicineRepository _medicines;
  final DoseNotifications _notifications;

  /// Bumped whenever doses or stock change, so screens can refresh.
  final changes = ValueNotifier<int>(0);

  /// How far ahead reminders are scheduled; topped up on every app start.
  static const window = Duration(days: 7);

  Future<void> start() async {
    await _notifications.init();
    await _schedules.completeEnded();
    await processResponses();
    await rescheduleAll();
  }

  Future<bool> requestPermission() => _notifications.requestPermission();

  /// After sync brought in changes from another device.
  Future<void> refreshAfterSync() async {
    await _schedules.completeEnded();
    await rescheduleAll();
    changes.value++;
  }

  /// On sign-out: this user's reminders must not fire for the next user.
  Future<void> shutdown() => _notifications.cancelAllPending();

  /// Applies reminder button presses queued while the app was closed.
  Future<void> processResponses() async {
    final queued = await _notifications.drainQueue();
    if (queued.isEmpty) return;
    for (final q in queued) {
      final schedule = await _schedules.byId(q.scheduleId);
      if (schedule == null) continue;
      final at = DateTime.parse(q.doseKey);
      switch (q.action) {
        case actionTaken:
          await _schedules.recordDose(schedule, at, DoseStatus.taken);
        case actionSkipped:
          await _schedules.recordDose(schedule, at, DoseStatus.skipped);
        case actionStopped:
          await _schedules.setStatus(schedule.id!, ScheduleStatus.stopped);
      }
    }
    await rescheduleAll();
    changes.value++;
  }

  Future<void> respond(DoseOccurrence dose, DoseStatus status) async {
    await _schedules.recordDose(dose.schedule, dose.at, status);
    await _notifications.cancel(dose.schedule.notificationId(dose.at));
    changes.value++;
  }

  Future<void> stop(DoseSchedule schedule) async {
    await _schedules.setStatus(schedule.id!, ScheduleStatus.stopped);
    await rescheduleAll();
    changes.value++;
  }

  Future<DoseSchedule> save(DoseSchedule schedule) async {
    final saved = await _schedules.save(schedule);
    await rescheduleAll();
    changes.value++;
    return saved;
  }

  Future<List<DoseSchedule>> forMedicine(int medicineId) => _schedules.forMedicine(medicineId);

  /// Re-creates all pending reminders from the active schedules.
  Future<void> rescheduleAll() async {
    await _notifications.cancelAllPending();
    final answered = await _answeredKeys();
    final now = DateTime.now();
    for (final s in await _schedules.all(activeOnly: true)) {
      final medicine = await _medicines.byId(s.medicineId);
      if (medicine == null) continue;
      for (final at in s.occurrencesBetween(now, now.add(window))) {
        if (answered.contains(_key(s.id!, at))) continue;
        await _notifications.scheduleDose(
          id: s.notificationId(at),
          at: at,
          title: 'Time for ${medicine.brandName}',
          body: _reminderBody(s, medicine, at),
          scheduleId: s.id!,
          doseKey: doseKey(at),
        );
      }
    }
  }

  /// Today's doses plus unanswered ones from the last 2 days.
  Future<List<DoseOccurrence>> dosesForToday() async {
    final logs = {for (final l in await _schedules.logs()) _key(l.scheduleId, l.scheduledAt): l.status};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final from = DateTime(now.year, now.month, now.day - 2);
    final result = <DoseOccurrence>[];
    for (final s in await _schedules.all()) {
      final medicine = await _medicines.byId(s.medicineId);
      if (medicine == null) continue;
      for (final at in s.occurrencesBetween(from, tomorrow)) {
        final status = logs[_key(s.id!, at)];
        final isToday = !at.isBefore(today);
        // Stopped/finished courses: only show doses that were answered today.
        if (s.status != ScheduleStatus.active && status == null) continue;
        if (isToday || status == null) result.add(DoseOccurrence(s, medicine, at, status));
      }
    }
    result.sort((a, b) => a.at.compareTo(b.at));
    return result;
  }

  Future<List<CourseProgress>> courses({bool activeOnly = true}) async {
    final logs = await _schedules.logs();
    final answered = {for (final l in logs) _key(l.scheduleId, l.scheduledAt)};
    final now = DateTime.now();
    final result = <CourseProgress>[];
    for (final s in await _schedules.all(activeOnly: activeOnly)) {
      final medicine = await _medicines.byId(s.medicineId);
      if (medicine == null) continue;
      final mine = logs.where((l) => l.scheduleId == s.id);
      final end = s.endDate;
      final remaining = end == null
          ? null
          : s.occurrencesBetween(now.subtract(const Duration(days: 2)), end)
              .where((at) => !answered.contains(_key(s.id!, at)))
              .length;
      result.add(CourseProgress(
        s,
        medicine,
        mine.where((l) => l.status == DoseStatus.taken).length,
        mine.where((l) => l.status == DoseStatus.skipped).length,
        remaining,
      ));
    }
    return result;
  }

  Future<Set<String>> _answeredKeys() async =>
      {for (final l in await _schedules.logs()) _key(l.scheduleId, l.scheduledAt)};

  static String _key(int scheduleId, DateTime at) => '$scheduleId|${doseKey(at)}';

  static String _reminderBody(DoseSchedule s, Medicine m, DateTime at) {
    final unit = s.dosePerIntake == 1 && m.unit.endsWith('s') ? m.unit.substring(0, m.unit.length - 1) : m.unit;
    return [
      'Take ${s.dosePerIntake} $unit',
      if (s.instructions.isNotEmpty) s.instructions,
      if (s.durationDays != null) 'Day ${s.dayNumber(at)} of ${s.durationDays}',
    ].join(' · ');
  }
}
