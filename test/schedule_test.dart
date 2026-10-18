import 'package:flutter_test/flutter_test.dart';
import 'package:medstock/models/lab_report.dart';
import 'package:medstock/models/medicine.dart';
import 'package:medstock/models/schedule.dart';
import 'package:medstock/services/prescription_reader.dart';

void main() {
  final course = DoseSchedule(
    id: 7,
    medicineId: 1,
    times: const [DoseTime.morning, DoseTime.night],
    startDate: DateTime(2026, 10, 18),
    durationDays: 5,
  );

  group('DoseSchedule', () {
    test('twice a day for 5 days is 10 doses ending on day 6', () {
      expect(course.totalDoses, 10);
      expect(course.endDate, DateTime(2026, 10, 23));
      final all = course.occurrencesBetween(DateTime(2026, 10, 1), DateTime(2026, 11, 1));
      expect(all.length, 10);
      expect(all.first, DateTime(2026, 10, 18, 8));
      expect(all.last, DateTime(2026, 10, 22, 21));
    });

    test('occurrences respect the window start', () {
      final rest = course.occurrencesBetween(DateTime(2026, 10, 20, 12), DateTime(2026, 11, 1));
      expect(rest.first, DateTime(2026, 10, 20, 21));
      expect(rest.length, 5);
    });

    test('a course started mid-morning skips that morning\'s dose', () {
      final late = course.copyWith(startDate: DateTime(2026, 10, 18, 11, 18));
      final all = late.occurrencesBetween(DateTime(2026, 10, 18), DateTime(2026, 11, 1));
      expect(all.first, DateTime(2026, 10, 18, 21));
      expect(all.length, 9);
      expect(late.dayNumber(DateTime(2026, 10, 19, 8)), 2);
    });

    test('quantity labels are singular for one', () {
      expect(qty(1, 'tablets'), '1 tablet');
      expect(qty(2, 'tablets'), '2 tablets');
      expect(qty(5, 'ml'), '5 ml');
    });

    test('ongoing schedules have no end', () {
      final daily = course.copyWith(ongoing: true);
      expect(daily.endDate, isNull);
      expect(daily.occurrencesBetween(DateTime(2026, 10, 18), DateTime(2026, 12, 18)).length, 122);
    });

    test('day number and notification ids are stable and distinct', () {
      expect(course.dayNumber(DateTime(2026, 10, 20, 21)), 3);
      final ids = course
          .occurrencesBetween(DateTime(2026, 10, 1), DateTime(2026, 11, 1))
          .map(course.notificationId)
          .toSet();
      expect(ids.length, 10);
    });

    test('round-trips through the database map', () {
      final back = DoseSchedule.fromMap({...course.toMap(), 'id': 7});
      expect(back.times, course.times);
      expect(back.durationDays, 5);
      expect(back.startDate, DateTime(2026, 10, 18));
    });

    test('default times per day', () {
      expect(DoseTime.defaultsFor(3), [DoseTime.morning, DoseTime.afternoon, DoseTime.night]);
      expect(DoseTime.night.label, '9:00 pm');
    });
  });

  group('matchPrescriptionItem', () {
    final dolo = Medicine(
      id: 1,
      brandName: 'Dolo 650',
      ingredients: const [Ingredient('Paracetamol', '650 mg')],
      form: DosageForm.tablet,
      createdAt: DateTime(2026),
    );
    final azee = Medicine(id: 2, brandName: 'Azee 500', form: DosageForm.tablet, createdAt: DateTime(2026));

    test('matches by brand', () {
      expect(matchPrescriptionItem(const PrescriptionItem(name: 'DOLO-650'), [azee, dolo])?.id, 1);
    });

    test('matches a generic name to a single-ingredient medicine of the same strength', () {
      expect(matchPrescriptionItem(const PrescriptionItem(name: 'Paracetamol', strength: '650 mg'), [dolo])?.id, 1);
      expect(matchPrescriptionItem(const PrescriptionItem(name: 'Paracetamol', strength: '500 mg'), [dolo]), isNull);
    });
  });

  group('LabResult', () {
    test('flags values outside the reference range', () {
      const low = LabResult(name: 'Platelet count', value: 85000, unit: '/uL', refLow: 150000, refHigh: 410000);
      expect(low.flag, ResultFlag.low);
      expect(low.rangeLabel, '150000 - 410000');
      expect(const LabResult(name: 'HbA1c', value: 5.4, refHigh: 5.7).flag, ResultFlag.normal);
      expect(const LabResult(name: 'Dengue NS1', valueText: 'Positive').flag, ResultFlag.unknown);
    });

    test('same test lines up across labs by name key', () {
      expect(const LabResult(name: 'Platelet Count').key, const LabResult(name: 'platelet count').key);
    });
  });
}
