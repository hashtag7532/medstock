import 'dart:convert';

enum DosageForm {
  tablet('Tablet', 'tablets'),
  capsule('Capsule', 'capsules'),
  syrup('Syrup', 'ml'),
  suspension('Suspension', 'ml'),
  drops('Drops', 'ml'),
  cream('Cream', 'g'),
  ointment('Ointment', 'g'),
  gel('Gel', 'g'),
  injection('Injection', 'ml'),
  inhaler('Inhaler', 'doses'),
  powder('Powder / Sachet', 'sachets'),
  other('Other', 'units');

  const DosageForm(this.label, this.unit);

  final String label;

  /// Default unit used to count what's left.
  final String unit;

  static DosageForm parse(String? value) => DosageForm.values.firstWhere(
        (f) => f.name == value,
        orElse: () => DosageForm.other,
      );
}

class Ingredient {
  const Ingredient(this.name, this.strength);

  /// e.g. "Paracetamol"
  final String name;

  /// e.g. "650 mg"
  final String strength;

  Map<String, String> toJson() => {'name': name, 'strength': strength};

  factory Ingredient.fromJson(Map<String, dynamic> json) =>
      Ingredient(json['name'] as String? ?? '', json['strength'] as String? ?? '');

  @override
  String toString() => strength.isEmpty ? name : '$name $strength';
}

enum ExpiryStatus { expired, soon, ok, unknown }

class Medicine {
  const Medicine({
    this.id,
    required this.brandName,
    this.ingredients = const [],
    this.form = DosageForm.other,
    this.expiry,
    this.batchNumber = '',
    this.manufacturer = '',
    this.quantity = 0,
    this.unit = 'units',
    this.imagePath,
    this.uses = '',
    required this.createdAt,
  });

  final int? id;
  final String brandName;
  final List<Ingredient> ingredients;
  final DosageForm form;

  /// Indian packs print expiry as month + year; we store the first day of
  /// that month. The medicine is usable until the end of the month.
  final DateTime? expiry;
  final String batchNumber;
  final String manufacturer;
  final int quantity;
  final String unit;
  final String? imagePath;

  /// What the medicine is commonly used for, e.g. "Fever and mild pain".
  /// General information only, shown with a "not medical advice" note.
  final String uses;
  final DateTime createdAt;

  static const soonThresholdDays = 60;

  ExpiryStatus get expiryStatus {
    final e = expiry;
    if (e == null) return ExpiryStatus.unknown;
    final firstDayAfter = DateTime(e.year, e.month + 1, 1);
    final now = DateTime.now();
    if (!now.isBefore(firstDayAfter)) return ExpiryStatus.expired;
    if (firstDayAfter.difference(now).inDays <= soonThresholdDays) {
      return ExpiryStatus.soon;
    }
    return ExpiryStatus.ok;
  }

  String get compositionSummary => ingredients.join(' + ');

  /// Normalised brand, so "DOLO-650 Tablets" and "Dolo 650" compare equal.
  String get brandKey => brandName
      .toLowerCase()
      .replaceAll(
          RegExp(r'\b(tablets?|tabs?|capsules?|caps?|syrup|suspension|drops|cream|ointment|gel|injection|i\.?p|b\.?p|u\.?s\.?p)\b'),
          '')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Exact composition (ingredients + strengths) and dosage form. Two medicines
  /// with the same key are the same drug under different brand names.
  String get compositionKey {
    if (ingredients.isEmpty) return '';
    final parts = ingredients
        .map((i) {
          final name = i.name
              .toLowerCase()
              .replaceAll(RegExp(r'\b(i\.?p|b\.?p|u\.?s\.?p)\b\.?'), '')
              .replaceAll(RegExp(r'[^a-z]'), '');
          final strength = i.strength.toLowerCase().replaceAll(RegExp(r'\s'), '');
          return '$name@$strength';
        })
        .where((p) => !p.startsWith('@'))
        .toList()
      ..sort();
    if (parts.isEmpty) return '';
    return '${form.name}:${parts.join('+')}';
  }

  Medicine copyWith({
    int? id,
    String? brandName,
    List<Ingredient>? ingredients,
    DosageForm? form,
    DateTime? expiry,
    bool clearExpiry = false,
    String? batchNumber,
    String? manufacturer,
    int? quantity,
    String? unit,
    String? imagePath,
    String? uses,
  }) =>
      Medicine(
        id: id ?? this.id,
        brandName: brandName ?? this.brandName,
        ingredients: ingredients ?? this.ingredients,
        form: form ?? this.form,
        expiry: clearExpiry ? null : (expiry ?? this.expiry),
        batchNumber: batchNumber ?? this.batchNumber,
        manufacturer: manufacturer ?? this.manufacturer,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        imagePath: imagePath ?? this.imagePath,
        uses: uses ?? this.uses,
        createdAt: createdAt,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'brand': brandName,
        'ingredients': jsonEncode(ingredients.map((i) => i.toJson()).toList()),
        'form': form.name,
        'expiry': expiry == null ? null : formatYearMonth(expiry!),
        'batch': batchNumber,
        'manufacturer': manufacturer,
        'quantity': quantity,
        'unit': unit,
        'image_path': imagePath,
        'uses': uses,
        'created_at': createdAt.toIso8601String(),
      };

  factory Medicine.fromMap(Map<String, Object?> map) => Medicine(
        id: map['id'] as int?,
        brandName: map['brand'] as String? ?? '',
        ingredients: (jsonDecode(map['ingredients'] as String? ?? '[]') as List)
            .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
            .toList(),
        form: DosageForm.parse(map['form'] as String?),
        expiry: parseYearMonth(map['expiry'] as String?),
        batchNumber: map['batch'] as String? ?? '',
        manufacturer: map['manufacturer'] as String? ?? '',
        quantity: map['quantity'] as int? ?? 0,
        unit: map['unit'] as String? ?? 'units',
        imagePath: map['image_path'] as String?,
        uses: map['uses'] as String? ?? '',
        createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String formatYearMonth(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

DateTime? parseYearMonth(String? value) {
  final m = RegExp(r'^(\d{4})-(\d{1,2})').firstMatch(value ?? '');
  if (m == null) return null;
  final month = int.parse(m.group(2)!);
  if (month < 1 || month > 12) return null;
  return DateTime(int.parse(m.group(1)!), month);
}

/// "1 tablet", "3 tablets", "5 ml".
String qty(int n, String unit) => '$n ${n == 1 && unit.endsWith('s') ? unit.substring(0, unit.length - 1) : unit}';

String formatDay(DateTime d) => '${d.day} ${monthNames[d.month - 1]} ${d.year}';

String formatExpiry(DateTime? d) => d == null ? 'No expiry' : '${monthNames[d.month - 1]} ${d.year}';

enum MatchKind { sameBrand, sameComposition }

/// A medicine already at home that matches one being scanned.
class StockMatch {
  const StockMatch(this.medicine, this.kind);

  final Medicine medicine;
  final MatchKind kind;
}
