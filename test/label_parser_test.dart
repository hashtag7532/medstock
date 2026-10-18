import 'package:flutter_test/flutter_test.dart';
import 'package:medstock/models/medicine.dart';
import 'package:medstock/services/label_parser.dart';

void main() {
  const parser = LabelParser();

  group('parseMonthYear', () {
    test('handles common Indian label formats', () {
      expect(LabelParser.parseMonthYear('03/2027'), DateTime(2027, 3));
      expect(LabelParser.parseMonthYear('3-27'), DateTime(2027, 3));
      expect(LabelParser.parseMonthYear('MAR.2027'), DateTime(2027, 3));
      expect(LabelParser.parseMonthYear("Dt. NOV'26"), DateTime(2026, 11));
      expect(LabelParser.parseMonthYear('12/03/2027'), DateTime(2027, 3));
    });

    test('ignores prices and doses', () {
      expect(LabelParser.parseMonthYear('M.R.P. Rs. 35.50'), isNull);
      expect(LabelParser.parseMonthYear('650 mg'), isNull);
    });
  });

  test('parses a paracetamol strip', () {
    final m = parser.parse(const [
      OcrLine('Dolo 650', 60),
      OcrLine('Paracetamol Tablets IP', 20),
      OcrLine('Each uncoated tablet contains:', 12),
      OcrLine('Paracetamol IP 650 mg', 12),
      OcrLine('B.No. DOBS3975 MFG.05/2025', 10),
      OcrLine('EXP.04/2028', 10),
      OcrLine('M.R.P. Rs. 33.60 for 15 Tablets', 10),
      OcrLine('Mfd. by: Micro Labs Ltd.', 10),
    ]);
    expect(m.brandName, 'Dolo 650');
    expect(m.form, DosageForm.tablet);
    expect(m.ingredients.map((i) => i.toString()), ['Paracetamol 650 mg']);
    expect(m.expiry, DateTime(2028, 4));
    expect(m.batchNumber, 'DOBS3975');
    expect(m.quantity, 15);
    expect(m.manufacturer, 'Micro Labs Ltd.');
  });

  test('parses a cough syrup with expiry on the next line', () {
    final m = parser.parse(const [
      OcrLine('Ascoril D Plus', 50),
      OcrLine('Cough Syrup', 20),
      OcrLine('Each 5 ml contains:', 12),
      OcrLine('Dextromethorphan Hydrobromide IP 10 mg', 12),
      OcrLine('Phenylephrine Hydrochloride IP 5 mg', 12),
      OcrLine('Exp. Date', 10),
      OcrLine('JAN 2027', 10),
      OcrLine('100 ml', 14),
    ]);
    expect(m.form, DosageForm.syrup);
    expect(m.ingredients.map((i) => i.name), ['Dextromethorphan Hydrobromide', 'Phenylephrine Hydrochloride']);
    expect(m.expiry, DateTime(2027, 1));
    expect(m.quantity, 100);
    expect(m.unit, 'ml');
  });

  test('same composition matches across brands, same brand across spellings', () {
    Medicine med(String brand, String strength) => Medicine(
          brandName: brand,
          ingredients: [Ingredient('Paracetamol IP', strength)],
          form: DosageForm.tablet,
          createdAt: DateTime(2026),
        );
    expect(med('DOLO-650 Tablets', '650 mg').brandKey, med('Dolo 650', '650 mg').brandKey);
    expect(med('Dolo 650', '650 mg').compositionKey, med('Calpol 650', '650mg').compositionKey);
    expect(med('Dolo 650', '650 mg').compositionKey, isNot(med('Crocin', '500 mg').compositionKey));
  });
}
