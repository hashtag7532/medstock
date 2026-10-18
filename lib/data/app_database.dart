import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'ids.dart';

/// Tables that sync with the server. Each row has a `uid` (UUID shared with
/// the server), `updated_at` (UTC, newest edit wins) and `dirty` (1 = not yet
/// sent to the server).
const syncedTables = ['medicines', 'schedules', 'dose_logs', 'lab_reports'];

/// One signed-in user's SQLite database and file folders on this phone.
class AppStorage {
  AppStorage._(this.db, this.labelPhotos, this.reportFiles, this.supportDir);

  final Database db;
  final Directory labelPhotos;
  final Directory reportFiles;

  /// App-private folder for small state files (e.g. the dose response queue).
  final Directory supportDir;

  /// Bumped after every local write, so sync knows there is something to send.
  final changes = ValueNotifier<int>(0);

  void markChanged() => changes.value++;

  static Future<AppStorage> open(String userId) async {
    final dbDir = await getDatabasesPath();
    final path = p.join(dbDir, 'medstock_$userId.db');
    await _adoptPreLoginData(dbDir, path);
    final db = await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await _createV1(db);
        await _upgradeToV2(db);
        await _upgradeToV3(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _upgradeToV2(db);
        if (oldVersion < 3) await _upgradeToV3(db);
      },
    );
    final docs = await getApplicationDocumentsDirectory();
    final userDir = p.join(docs.path, 'users', userId);
    final photos = await Directory(p.join(userDir, 'label_photos')).create(recursive: true);
    final reports = await Directory(p.join(userDir, 'lab_reports')).create(recursive: true);
    final support = await Directory(p.join((await getApplicationSupportDirectory()).path, userId)).create(recursive: true);
    return AppStorage._(db, photos, reports, support);
  }

  Future<void> close() => db.close();

  /// Medicines saved before login existed belong to whoever signs in first
  /// on this phone: their database takes over the old file.
  static Future<void> _adoptPreLoginData(String dbDir, String userPath) async {
    final legacy = File(p.join(dbDir, 'medstock.db'));
    if (!await legacy.exists() || await File(userPath).exists()) return;
    await legacy.rename(userPath);
    for (final suffix in ['-journal', '-wal', '-shm']) {
      final extra = File('${legacy.path}$suffix');
      if (await extra.exists()) await extra.rename('$userPath$suffix');
    }
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

  /// Sync bookkeeping: row identity shared with the server, change tracking,
  /// pending deletes and the server cursor.
  static Future<void> _upgradeToV3(Database db) async {
    final batch = db.batch();
    for (final table in syncedTables) {
      batch
        ..execute('ALTER TABLE $table ADD COLUMN uid TEXT')
        ..execute('ALTER TABLE $table ADD COLUMN updated_at TEXT')
        ..execute('ALTER TABLE $table ADD COLUMN dirty INTEGER NOT NULL DEFAULT 1')
        ..execute('CREATE UNIQUE INDEX ${table}_uid ON $table(uid)');
    }
    batch
      ..execute('CREATE TABLE sync_deletes(table_name TEXT NOT NULL, uid TEXT NOT NULL, PRIMARY KEY(table_name, uid))')
      ..execute('CREATE TABLE sync_state(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    await batch.commit(noResult: true);

    // Existing rows get an identity and are queued for upload.
    final stamp = nowStamp();
    for (final table in syncedTables) {
      for (final row in await db.query(table, columns: ['id'])) {
        await db.update(table, {'uid': newUuid(), 'updated_at': stamp, 'dirty': 1}, where: 'id = ?', whereArgs: [row['id']]);
      }
    }
  }
}
