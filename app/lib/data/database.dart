import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../platform/platform.dart';
import '../sync/sync_schema.dart';

/// Single access point to the SQLite database.
///
/// Everything (settings, hours, journal, notes and attachment files) is
/// stored in this database.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const int _version = 4;

  /// Attachment files are split in chunks so that big files can be read on
  /// Android (cursor windows are limited to ~2 MB per row).
  static const int chunkSize = 512 * 1024;

  Database? _db;

  Database get db {
    final d = _db;
    if (d == null) throw StateError('Database not opened');
    return d;
  }

  Future<void> open({String? overridePath}) async {
    if (_db != null) return;
    prepareDatabaseFactory();
    _db = await openFile(overridePath ?? await defaultDatabasePath());
  }

  /// Opens (creating / migrating if needed) a TimeLog database file.
  /// Used by [open]; tests use it to simulate several devices.
  static Future<Database> openFile(String path) => openDatabase(
    path,
    version: _version,
    onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
    onCreate: _onCreate,
    onUpgrade: _onUpgrade,
  );

  /// Writes the content of an attachment, split in [chunkSize] blocks.
  static Future<void> writeChunks(DatabaseExecutor ex, int attachmentId, Uint8List data) async {
    var idx = 0;
    var off = 0;
    do {
      final end = (off + chunkSize).clamp(0, data.length);
      await ex.insert('attachment_chunks', {
        'attachment_id': attachmentId,
        'idx': idx++,
        'data': Uint8List.fromList(Uint8List.sublistView(data, off, end)),
      });
      off = end;
    } while (off < data.length);
  }

  /// Reads the content of an attachment (one block per query, see [chunkSize]).
  static Future<Uint8List> readChunks(DatabaseExecutor ex, int attachmentId) async {
    final idx = await ex.query(
      'attachment_chunks',
      columns: ['idx'],
      where: 'attachment_id = ?',
      whereArgs: [attachmentId],
      orderBy: 'idx',
    );
    final b = BytesBuilder(copy: false);
    for (final r in idx) {
      final c = await ex.query(
        'attachment_chunks',
        columns: ['data'],
        where: 'attachment_id = ? AND idx = ?',
        whereArgs: [attachmentId, r['idx']],
      );
      b.add(c.first['data']! as Uint8List);
    }
    return b.takeBytes();
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Vacation entitlement per year (days, halves allowed).
  static const _vacationYearsTable = '''
      CREATE TABLE vacation_years (
        year INTEGER PRIMARY KEY,
        entitlement REAL NOT NULL,
        carry_over REAL NOT NULL DEFAULT 0
      )''';

  static Future<void> _onUpgrade(Database db, int from, int to) async {
    if (from < 2) {
      // v2: half-day / partial absences.
      await db.execute("ALTER TABLE time_entries ADD COLUMN absence_part TEXT NOT NULL DEFAULT 'full'");
      await db.execute('ALTER TABLE time_entries ADD COLUMN absence_minutes INTEGER');
    }
    if (from < 3) await db.execute(_vacationYearsTable);
    // v4: preparation of the online synchronization (uid, modified_at, sync_log).
    if (from < 4) await SyncSchema.install(db);
  }

  static Future<void> _onCreate(Database db, int version) async {
    final b = db.batch();
    b.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )''');
    b.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color INTEGER NOT NULL
      )''');
    b.execute('''
      CREATE TABLE time_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL UNIQUE,
        day_type TEXT NOT NULL DEFAULT 'work',
        absence_part TEXT NOT NULL DEFAULT 'full',
        absence_minutes INTEGER,
        arrival INTEGER,
        lunch_start INTEGER,
        lunch_end INTEGER,
        departure INTEGER,
        comment TEXT
      )''');
    b.execute(_vacationYearsTable);
    b.execute('''
      CREATE TABLE journal_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        title TEXT NOT NULL DEFAULT '',
        content TEXT NOT NULL DEFAULT '',
        duration_minutes INTEGER,
        category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''');
    b.execute('CREATE INDEX idx_journal_date ON journal_entries(date)');
    b.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        title TEXT NOT NULL DEFAULT '',
        content TEXT NOT NULL DEFAULT '',
        category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )''');
    b.execute('CREATE INDEX idx_notes_date ON notes(date)');
    b.execute('''
      CREATE TABLE attachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        note_id INTEGER NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
        kind TEXT NOT NULL,
        file_name TEXT NOT NULL,
        mime TEXT,
        size INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )''');
    b.execute('''
      CREATE TABLE attachment_chunks (
        attachment_id INTEGER NOT NULL REFERENCES attachments(id) ON DELETE CASCADE,
        idx INTEGER NOT NULL,
        data BLOB NOT NULL,
        PRIMARY KEY (attachment_id, idx)
      )''');
    await b.commit(noResult: true);
    await SyncSchema.install(db);
  }
}
