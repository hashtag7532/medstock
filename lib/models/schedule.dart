import 'dart:convert';

/// A time of day for a dose, e.g. 08:00.
class DoseTime implements Comparable<DoseTime> {
  const DoseTime(this.hour, this.minute);

  final int hour;
  final int minute;

  static const morning = DoseTime(8, 0);
  static const afternoon = DoseTime(14, 0);
  static const evening = DoseTime(18, 0);
  static const night = DoseTime(21, 0);

  factory DoseTime.parse(String s) {
    final parts = s.split(':');
    return DoseTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  /// Default times for a number of doses per day.
  static List<DoseTime> defaultsFor(int timesPerDay) => switch (timesPerDay) {
        <= 1 => [morning],
        2 => [morning, night],
        3 => [morning, afternoon, night],
        _ => [morning, const DoseTime(12, 0), evening, night],
      };

  String get hhmm => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// "8:00 am"
  String get label {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h:${minute.toString().padLeft(2, '0')} ${hour < 12 ? 'am' : 'pm'}';
  }

  DateTime on(DateTime day) => DateTime(day.year, day.month, day.day, hour, minute);

  @override
  int compareTo(DoseTime other) => (hour * 60 + minute) - (other.hour * 60 + other.minute);

  @override
  bool operator ==(Object other) => other is DoseTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => hour * 60 + minute;
}

enum ScheduleStatus { active, stopped, completed }

/// A course of a medicine: e.g. 1 tablet at 8 am and 9 pm for 5 days.
class DoseSchedule {
  const DoseSchedule({
    this.id,
    required this.medicineId,
    this.dosePerIntake = 1,
    required this.times,
    required this.startDate,
    this.durationDays,
    this.instructions = '',
    this.status = ScheduleStatus.active,
  });

  final int? id;
  final int medicineId;

  /// Units taken each time (tablets, ml...), in the medicine's unit.
  final int dosePerIntake;
  final List<DoseTime> times;

  /// When the course starts. Doses before this moment are never due, so a
  /// schedule created at 11 am doesn't ask about that morning's 8 am dose.
  final DateTime startDate;

  /// Null means ongoing (e.g. a daily BP tablet).
  final int? durationDays;

  /// e.g. "After food"
  final String instructions;
  final ScheduleStatus status;

  bool get isOngoing => durationDays == null;

  /// First day after the course ends.
  DateTime? get endDate => durationDays == null
      ? null
      : DateTime(startDate.year, startDate.month, startDate.day + durationDays!);

  int? get totalDoses => durationDays == null ? null : durationDays! * times.length;

  /// 1-based day of the course for [when].
  int dayNumber(DateTime when) =>
      DateTime(when.year, when.month, when.day)
          .difference(DateTime(startDate.year, startDate.month, startDate.day))
          .inDays +
      1;

  /// Every dose time in [from, to), within the course.
  List<DateTime> occurrencesBetween(DateTime from, DateTime to) {
    final result = <DateTime>[];
    final end = endDate;
    var day = DateTime(from.year, from.month, from.day);
    final first = DateTime(startDate.year, startDate.month, startDate.day);
    if (day.isBefore(first)) day = first;
    while (day.isBefore(to) && (end == null || day.isBefore(end))) {
      for (final t in times) {
        final at = t.on(day);
        if (!at.isBefore(from) && at.isBefore(to) && !at.isBefore(startDate)) result.add(at);
      }
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return result;
  }

  /// Stable notification id for one dose of this schedule.
  int notificationId(DateTime at) {
    final dayIndex = dayNumber(at) - 1;
    final timeIndex = times.indexWhere((t) => t.hour == at.hour && t.minute == at.minute);
    return (id! % 20000) * 100000 + (dayIndex % 10000) * 10 + (timeIndex < 0 ? 9 : timeIndex);
  }

  DoseSchedule copyWith({
    int? id,
    int? dosePerIntake,
    List<DoseTime>? times,
    DateTime? startDate,
    int? durationDays,
    bool ongoing = false,
    String? instructions,
    ScheduleStatus? status,
  }) =>
      DoseSchedule(
        id: id ?? this.id,
        medicineId: medicineId,
        dosePerIntake: dosePerIntake ?? this.dosePerIntake,
        times: times ?? this.times,
        startDate: startDate ?? this.startDate,
        durationDays: ongoing ? null : (durationDays ?? this.durationDays),
        instructions: instructions ?? this.instructions,
        status: status ?? this.status,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'medicine_id': medicineId,
        'dose': dosePerIntake,
        'times': jsonEncode(times.map((t) => t.hhmm).toList()),
        'start_date': startDate.toIso8601String(),
        'duration_days': durationDays,
        'instructions': instructions,
        'status': status.name,
      };

  factory DoseSchedule.fromMap(Map<String, Object?> map) => DoseSchedule(
        id: map['id'] as int?,
        medicineId: map['medicine_id'] as int,
        dosePerIntake: map['dose'] as int? ?? 1,
        times: (jsonDecode(map['times'] as String) as List).map((t) => DoseTime.parse(t as String)).toList()
          ..sort(),
        startDate: DateTime.parse(map['start_date'] as String),
        durationDays: map['duration_days'] as int?,
        instructions: map['instructions'] as String? ?? '',
        status: ScheduleStatus.values.byName(map['status'] as String? ?? 'active'),
      );
}

enum DoseStatus { taken, skipped }

class DoseLog {
  const DoseLog({required this.scheduleId, required this.scheduledAt, required this.status});

  final int scheduleId;
  final DateTime scheduledAt;
  final DoseStatus status;

  factory DoseLog.fromMap(Map<String, Object?> map) => DoseLog(
        scheduleId: map['schedule_id'] as int,
        scheduledAt: DateTime.parse(map['scheduled_at'] as String),
        status: DoseStatus.values.byName(map['status'] as String),
      );
}


/// Local time as an ISO string without a zone, used as the dose key.
String doseKey(DateTime at) => DateTime(at.year, at.month, at.day, at.hour, at.minute).toIso8601String();
