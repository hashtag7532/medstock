import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/medicine.dart';

/// Local, on-device store for the medicine cabinet.
class MedicineRepository {
  MedicineRepository(this._db, this._imagesDir);

  final Database _db;
  final Directory _imagesDir;

  /// All medicines, soonest expiry first (unknown expiry last).
  Future<List<Medicine>> all() async {
    final rows = await _db.query('medicines', orderBy: 'expiry IS NULL, expiry ASC, brand COLLATE NOCASE');
    return rows.map(Medicine.fromMap).toList();
  }

  Future<Medicine?> byId(int id) async {
    final rows = await _db.query('medicines', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Medicine.fromMap(rows.first);
  }

  Future<Medicine> save(Medicine medicine) async {
    final withImage = medicine.copyWith(imagePath: await _persistImage(medicine.imagePath));
    if (withImage.id == null) {
      final id = await _db.insert('medicines', withImage.toMap());
      return withImage.copyWith(id: id);
    }
    await _db.update('medicines', withImage.toMap(), where: 'id = ?', whereArgs: [withImage.id]);
    return withImage;
  }

  Future<void> delete(Medicine medicine) async {
    await _db.transaction((txn) async {
      // sqflite doesn't enforce foreign keys by default, so clean up by hand.
      await txn.rawDelete(
          'DELETE FROM dose_logs WHERE schedule_id IN (SELECT id FROM schedules WHERE medicine_id = ?)', [medicine.id]);
      await txn.delete('schedules', where: 'medicine_id = ?', whereArgs: [medicine.id]);
      await txn.delete('medicines', where: 'id = ?', whereArgs: [medicine.id]);
    });
    final path = medicine.imagePath;
    if (path != null && p.isWithin(_imagesDir.path, path)) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  /// Medicines at home that are the same brand, or the exact same composition
  /// and dosage form under a different brand.
  Future<List<StockMatch>> findMatches(Medicine scanned) async {
    final brandKey = scanned.brandKey;
    final compositionKey = scanned.compositionKey;
    final matches = <StockMatch>[];
    for (final m in await all()) {
      if (scanned.id != null && m.id == scanned.id) continue;
      if (brandKey.isNotEmpty && m.brandKey == brandKey) {
        matches.add(StockMatch(m, MatchKind.sameBrand));
      } else if (compositionKey.isNotEmpty && m.compositionKey == compositionKey) {
        matches.add(StockMatch(m, MatchKind.sameComposition));
      }
    }
    return matches;
  }

  /// image_picker returns temp files that the OS may clear, so keep a copy.
  Future<String?> _persistImage(String? path) async {
    if (path == null || p.isWithin(_imagesDir.path, path)) return path;
    final source = File(path);
    if (!await source.exists()) return null;
    final target = p.join(_imagesDir.path, '${DateTime.now().millisecondsSinceEpoch}${p.extension(path)}');
    await source.copy(target);
    return target;
  }
}
