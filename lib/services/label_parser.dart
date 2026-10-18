import '../models/medicine.dart';

/// A line of text from OCR. [height] is the bounding-box height in pixels and
/// is used to guess the brand name (usually the largest text on the pack).
class OcrLine {
  const OcrLine(this.text, [this.height = 0]);

  final String text;
  final double height;
}

/// Turns raw OCR text from an Indian medicine strip/box into a draft
/// [Medicine]. Heuristic: the user always confirms the result.
class LabelParser {
  const LabelParser();

  static const _monthsByName = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  static final _expiryKeyword =
      RegExp(r'\b(?:exp(?:iry)?(?:\.|\b)|use\s+before|best\s+before)', caseSensitive: false);
  static final _mfgKeyword = RegExp(r'\b(?:mfg|mfd|mfg\.?\s*dt|manufactured)\b', caseSensitive: false);

  Medicine parse(List<OcrLine> lines, {String? imagePath}) {
    final texts = lines.map((l) => l.text.trim()).where((t) => t.isNotEmpty).toList();
    final all = texts.join('\n');
    final form = _dosageForm(all);
    final ingredients = _ingredients(texts);
    final (quantity, unit) = _quantity(all, form);
    return Medicine(
      brandName: _brand(lines),
      ingredients: ingredients,
      form: form,
      expiry: _expiry(texts),
      batchNumber: _batch(all),
      manufacturer: _manufacturer(texts),
      quantity: quantity,
      unit: unit,
      imagePath: imagePath,
      createdAt: DateTime.now(),
    );
  }

  /// Parses the first month/year in [s]: "03/2027", "3-27", "MAR.2027",
  /// "12/03/2027" (day/month/year).
  static DateTime? parseMonthYear(String s) {
    DateTime? build(int month, int year) {
      if (year < 100) year += 2000;
      if (month < 1 || month > 12 || year < 2010 || year > 2050) return null;
      return DateTime(year, month);
    }

    final dmy = RegExp(r'(?<!\d)\d{1,2}\s*[/\-.]\s*(\d{1,2})\s*[/\-.]\s*(\d{4}|\d{2})(?!\d)').firstMatch(s);
    if (dmy != null) {
      final d = build(int.parse(dmy.group(1)!), int.parse(dmy.group(2)!));
      if (d != null) return d;
    }
    for (final m in RegExp(r'(?<!\d)(\d{1,2})\s*[/\-.]\s*(\d{4}|\d{2})(?!\d)').allMatches(s)) {
      final d = build(int.parse(m.group(1)!), int.parse(m.group(2)!));
      if (d != null) return d;
    }
    for (final m in RegExp(r"\b([A-Za-z]{3})[A-Za-z]*\.?\s*[/\-.,']?\s*(\d{4}|\d{2})(?!\d)").allMatches(s)) {
      final month = _monthsByName[m.group(1)!.toLowerCase()];
      if (month == null) continue;
      final d = build(month, int.parse(m.group(2)!));
      if (d != null) return d;
    }
    return null;
  }

  DateTime? _expiry(List<String> texts) {
    for (var i = 0; i < texts.length; i++) {
      final match = _expiryKeyword.firstMatch(texts[i]);
      if (match == null) continue;
      final after = parseMonthYear(texts[i].substring(match.end));
      if (after != null) return after;
      // Label and value are often printed on separate lines.
      if (i + 1 < texts.length) {
        final next = parseMonthYear(texts[i + 1]);
        if (next != null) return next;
      }
    }
    // No "EXP" keyword found: expiry is the latest date on the pack
    // (the other one is usually the manufacturing date).
    DateTime? latest;
    for (final t in texts) {
      final d = parseMonthYear(t);
      if (d == null) continue;
      if (_mfgKeyword.hasMatch(t) && !_expiryKeyword.hasMatch(t)) continue;
      if (latest == null || d.isAfter(latest)) latest = d;
    }
    return latest;
  }

  String _batch(String all) {
    final m = RegExp(
      r'(?:\bb\.?\s*no\b\.?|\bbatch\s*(?:no\b\.?|number)?|\blot\s*(?:no\b\.?)?)\s*[:.\-]?\s*([A-Z0-9][A-Z0-9\-/]{2,15})',
      caseSensitive: false,
    ).firstMatch(all);
    final value = m?.group(1) ?? '';
    return RegExp(r'^(mfg|mfd|exp)', caseSensitive: false).hasMatch(value) ? '' : value.toUpperCase();
  }

  String _manufacturer(List<String> texts) {
    final byLine = RegExp(r'\b(?:mfd|manufactured|mktd|marketed)\.?\s*by\s*[:\-]?\s*(.*)', caseSensitive: false);
    for (var i = 0; i < texts.length; i++) {
      final m = byLine.firstMatch(texts[i]);
      if (m == null) continue;
      final rest = m.group(1)!.trim();
      if (rest.length > 2) return rest;
      if (i + 1 < texts.length) return texts[i + 1];
    }
    final company = RegExp(r'\b(ltd|limited|pvt|pharma|laboratories|labs|healthcare)\b', caseSensitive: false);
    return texts.firstWhere((t) => company.hasMatch(t), orElse: () => '');
  }

  DosageForm _dosageForm(String all) {
    const keywords = [
      (r'syrups?|linctus', DosageForm.syrup),
      (r'suspensions?', DosageForm.suspension),
      (r'drops', DosageForm.drops),
      (r'creams?', DosageForm.cream),
      (r'ointments?', DosageForm.ointment),
      (r'gels?', DosageForm.gel),
      (r'injections?|vials?|ampoules?', DosageForm.injection),
      (r'inhalers?|rotacaps?', DosageForm.inhaler),
      (r'sachets?|powder', DosageForm.powder),
      (r'capsules?|caps', DosageForm.capsule),
      (r'tablets?|tabs?', DosageForm.tablet),
    ];
    for (final (pattern, form) in keywords) {
      if (RegExp('\\b(?:$pattern)\\b', caseSensitive: false).hasMatch(all)) return form;
    }
    return DosageForm.other;
  }

  static final _ingredientPattern = RegExp(
    r'([A-Za-z][A-Za-z\s\-,()]{2,60}?)\s*(?:I\.?P\.?|B\.?P\.?|U\.?S\.?P\.?|Ph\.?\s*Eur\.?)?\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*(mg|mcg|µg|g|ml|iu|%)(?![a-z])',
    caseSensitive: false,
  );
  static final _notAnIngredient = RegExp(
    r'\b(each|contains?|tablets?|capsules?|ml|per|dose|spoon|colou?rs?|excipients?|q\.?s|store|mrp|rs|net|vol|syrup|strip|pack|approved|weight)\b',
    caseSensitive: false,
  );

  List<Ingredient> _ingredients(List<String> texts) {
    final found = <String, Ingredient>{};
    for (final line in texts) {
      for (final m in _ingredientPattern.allMatches(line)) {
        var name = m.group(1)!;
        // Drop "Each film coated tablet contains:" style prefixes.
        if (name.contains(':')) name = name.substring(name.lastIndexOf(':') + 1);
        name = name
            .replaceAll(RegExp(r'\b(equivalent|eq\.?)\s+to\b.*', caseSensitive: false), '')
            .replaceAll(RegExp(r'^[\s,\-()]+|[\s,\-(]+$'), '')
            .replaceAll(RegExp(r'\s+'), ' ');
        if (name.length < 3 || _notAnIngredient.hasMatch(name)) continue;
        final strength = '${m.group(2)} ${m.group(3)!.toLowerCase()}';
        found.putIfAbsent(name.toLowerCase(), () => Ingredient(_titleCase(name), strength));
      }
    }
    return found.values.toList();
  }

  (int, String) _quantity(String all, DosageForm form) {
    final strip = RegExp(r'(?<!\d)(\d{1,3})\s*[xX×]\s*(\d{1,3})(?!\d)').firstMatch(all);
    if (strip != null && (form == DosageForm.tablet || form == DosageForm.capsule)) {
      // "10 x 15" = 10 strips of 15; a single scanned strip holds the second number.
      return (int.parse(strip.group(2)!), form.unit);
    }
    final count = RegExp(r'(?:strip\s+of\s+)?(\d{1,3})\s*(?:tablets|tabs|capsules|caps)\b', caseSensitive: false)
            .firstMatch(all) ??
        RegExp(r'strip\s+of\s+(\d{1,3})', caseSensitive: false).firstMatch(all);
    if (count != null) return (int.parse(count.group(1)!), form.unit);
    if (form.unit == 'ml') {
      // Bottle size is the largest ml value ("5 ml contains..." is a dose).
      final volumes = RegExp(r'(\d{2,4})\s*ml\b', caseSensitive: false)
          .allMatches(all)
          .map((m) => int.parse(m.group(1)!))
          .toList();
      if (volumes.isNotEmpty) return (volumes.reduce((a, b) => a > b ? a : b), 'ml');
    }
    return (0, form.unit);
  }

  static final _noiseLine = RegExp(
    r'^(rx|schedule|each|composition|contains|mfd|mfg|exp|b\.?\s*no|batch|m\.?r\.?p|store|keep|dosage|warning|manufactured|marketed|mktd)',
    caseSensitive: false,
  );

  String _brand(List<OcrLine> lines) {
    final candidates = lines
        .where((l) => RegExp(r'[A-Za-z]{3,}').hasMatch(l.text) && !_noiseLine.hasMatch(l.text.trim()))
        .toList();
    if (candidates.isEmpty) return '';
    final best = candidates.reduce((a, b) => b.height > a.height ? b : a);
    return best.text
        .replaceAll(RegExp(r'\b(tablets?|capsules?)\s*(i\.?p\.?|b\.?p\.?|u\.?s\.?p\.?)?$', caseSensitive: false), '')
        .trim();
  }

  static String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');
}
