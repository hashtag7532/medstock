import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Opens the app's SQLite database and file folders.
class AppStorage {
  AppStorage._(this.db, this.labelPhotos, this.reportFiles, this.supportDir);

  final Database db;
  final Directory labelPhotos;
  final Directory reportFiles;

  /// App-private folder for small state files (e.g. the dose response queue).
  final Directory supportDir;

  static Future<AppStorage> open() async {
    final db = await openDatabase(
      p.join(await getDatabasesPath(), 'medstock.db'),
      version: 2,
      onCreate: (db, version) async {
        await _createV1(db);
        await _upgradeToV2(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _upgradeToV2(db);
      },
    );
    final docs = await getApplicationDocumentsDirectory();
    final photos = await Directory(p.join(docs.path, 'label_photos')).create(recursive: true);
    final reports = await Directory(p.join(docs.path, 'lab_reports')).create(recursive: true);
    final support = await getApplicationSupportDirectory();
    await support.create(recursive: true);
    return AppStorage._(db, photos, reports, support);
  }

  static Future<void> _createV1(Database db) => db.execute('''
    CREATE TABLE medicines(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      brand TEXT NOT NULL,
      ingredients TEXT NOT NULL,
      form TEXT NOT NULL,
      expiry TEXT,
      batch TEXT,
      manufacturer TEXT,
      quantity INTEGER NOT NULL,
      unit TEXT NOT NULL,
      image_path TEXT,
      created_at TEXT NOT NULL
    )
  ''');

  static Future<void> _upgradeToV2(Database db) async {
    final batch = db.batch()
      ..execute("ALTER TABLE medicines ADD COLUMN uses TEXT NOT NULL DEFAULT ''")
      ..execute('''
        CREATE TABLE schedules(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          medicine_id INTEGER NOT NULL REFERENCES medicines(id) ON DELETE CASCADE,
          dose INTEGER NOT NULL,
          times TEXT NOT NULL,
          start_date TEXT NOT NULL,
          duration_days INTEGER,
          instructions TEXT NOT NULL DEFAULT '',
          status TEXT NOT NULL
        )
      ''')
      ..execute('''
        CREATE TABLE dose_logs(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          schedule_id INTEGER NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
          scheduled_at TEXT NOT NULL,
          status TEXT NOT NULL,
          responded_at TEXT NOT NULL,
          UNIQUE(schedule_id, scheduled_at)
        )
      ''')
      ..execute('''
        CREATE TABLE lab_reports(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          report_date TEXT NOT NULL,
          lab_name TEXT NOT NULL DEFAULT '',
          file_paths TEXT NOT NULL DEFAULT '[]'
        )
      ''')
      ..execute('''
        CREATE TABLE lab_results(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          report_id INTEGER NOT NULL REFERENCES lab_reports(id) ON DELETE CASCADE,
          name TEXT NOT NULL,
          test_key TEXT NOT NULL,
          value REAL,
          value_text TEXT NOT NULL DEFAULT '',
          unit TEXT NOT NULL DEFAULT '',
          ref_low REAL,
          ref_high REAL,
          panel TEXT NOT NULL DEFAULT ''
        )
      ''')
      ..execute('CREATE INDEX lab_results_key ON lab_results(test_key)');
    await batch.commit(noResult: true);
  }
}
