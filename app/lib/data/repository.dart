import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../services/widget_sync.dart';
import '../utils/dates.dart';
import 'database.dart';

/// Data access for every table of the application.
class Repository {
  Repository._();
  static final Repository instance = Repository._();

  Database get _db => AppDatabase.instance.db;

  // ---------------------------------------------------------------- settings
  Future<Map<String, String>> loadSettings() async {
    final rows = await _db.query('settings');
    return {for (final r in rows) r['key'] as String: (r['value'] as String?) ?? ''};
  }

  // Writes use "upsert" (INSERT ... ON CONFLICT DO UPDATE) instead of REPLACE:
  // the row keeps its identity and only the changed columns are recorded for
  // the synchronization (see SyncSchema).
  Future<void> _upsert(String table, Map<String, Object?> values, String conflictKey) {
    final cols = values.keys.toList();
    final updates = cols.where((c) => c != conflictKey).map((c) => '$c = excluded.$c').join(', ');
    return _db.rawInsert(
      'INSERT INTO $table (${cols.join(', ')}) VALUES (${List.filled(cols.length, '?').join(', ')}) '
      'ON CONFLICT($conflictKey) DO UPDATE SET $updates',
      values.values.toList(),
    );
  }

  Future<void> saveSetting(String key, String value) => _upsert('settings', {'key': key, 'value': value}, 'key');

  /// Saves a value chosen by the app. Dated "never", so that any value already
  /// in the online account wins when this device signs in.
  Future<void> saveDefaultSetting(String key, String value) async {
    await saveSetting(key, value);
    await _db.update('settings', {'modified_at': 0}, where: 'key = ?', whereArgs: [key]);
  }

  // -------------------------------------------------------------- categories
  Future<List<Category>> categories() async {
    final rows = await _db.query('categories', orderBy: 'name COLLATE NOCASE');
    return rows.map(Category.fromMap).toList();
  }

  Future<int> saveCategory(Category c) async {
    if (c.id == null) {
      final m = c.toMap()..remove('id');
      return _db.insert('categories', m);
    }
    await _db.update('categories', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
    return c.id!;
  }

  Future<void> deleteCategory(int id) => _db.delete('categories', where: 'id = ?', whereArgs: [id]);

  // ------------------------------------------------------------ time entries
  Future<TimeEntry?> timeEntry(DateTime day) async {
    final rows = await _db.query('time_entries', where: 'date = ?', whereArgs: [Dates.key(day)]);
    return rows.isEmpty ? null : TimeEntry.fromMap(rows.first);
  }

  Future<List<TimeEntry>> timeEntries(DateTime from, DateTime to) async {
    final rows = await _db.query(
      'time_entries',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [Dates.key(from), Dates.key(to)],
      orderBy: 'date',
    );
    return rows.map(TimeEntry.fromMap).toList();
  }

  Future<void> saveTimeEntry(TimeEntry e) async {
    await _upsert('time_entries', e.toMap()..remove('id'), 'date');
    await WidgetSync.refresh();
  }

  Future<void> deleteTimeEntry(DateTime day) async {
    await _db.delete('time_entries', where: 'date = ?', whereArgs: [Dates.key(day)]);
    await WidgetSync.refresh();
  }

  // --------------------------------------------------------------- vacation
  /// Returns (entitlement, carryOver) for [year], or null if never set.
  Future<(double, double)?> vacationYear(int year) async {
    final r = await _db.query('vacation_years', where: 'year = ?', whereArgs: [year]);
    if (r.isEmpty) return null;
    return ((r.first['entitlement'] as num).toDouble(), (r.first['carry_over'] as num).toDouble());
  }

  Future<void> saveVacationYear(int year, double entitlement, double carryOver) =>
      _upsert('vacation_years', {'year': year, 'entitlement': entitlement, 'carry_over': carryOver}, 'year');

  Future<List<TimeEntry>> vacationEntries(int year) async {
    final rows = await _db.query(
      'time_entries',
      where: 'day_type = ? AND date BETWEEN ? AND ?',
      whereArgs: ['vacation', '$year-01-01', '$year-12-31'],
      orderBy: 'date',
    );
    return rows.map(TimeEntry.fromMap).toList();
  }

  // ----------------------------------------------------------------- journal
  Future<List<JournalEntry>> journal(DateTime from, DateTime to) async {
    final rows = await _db.query(
      'journal_entries',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [Dates.key(from), Dates.key(to)],
      orderBy: 'date DESC, created_at DESC',
    );
    return rows.map(JournalEntry.fromMap).toList();
  }

  Future<int> saveJournal(JournalEntry e) async {
    if (e.id == null) {
      final m = e.toMap()..remove('id');
      return _db.insert('journal_entries', m);
    }
    final updated = await _db.update('journal_entries', e.toMap(), where: 'id = ?', whereArgs: [e.id]);
    // Deleted on another device while it was being edited: the text is kept.
    if (updated == 0) return _db.insert('journal_entries', e.toMap()..remove('id'));
    return e.id!;
  }

  Future<void> deleteJournal(int id) => _db.delete('journal_entries', where: 'id = ?', whereArgs: [id]);

  // ------------------------------------------------------------------- notes
  Future<List<Attachment>> _attachmentsFor(List<int> noteIds) async {
    if (noteIds.isEmpty) return [];
    final rows = await _db.query(
      'attachments',
      where: 'note_id IN (${List.filled(noteIds.length, '?').join(',')})',
      whereArgs: noteIds,
      orderBy: 'created_at',
    );
    return rows.map(Attachment.fromMap).toList();
  }

  Future<List<Note>> _withAttachments(List<Map<String, Object?>> rows) async {
    final ids = rows.map((r) => r['id'] as int).toList();
    final att = await _attachmentsFor(ids);
    return rows.map((r) => Note.fromMap(r, att.where((a) => a.noteId == r['id']).toList())).toList();
  }

  Future<List<Note>> notes(DateTime from, DateTime to) async {
    final rows = await _db.query(
      'notes',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [Dates.key(from), Dates.key(to)],
      orderBy: 'date DESC, created_at DESC',
    );
    return _withAttachments(rows);
  }

  /// Searches notes by title, text, attachment file name and category name.
  /// Escapes the LIKE wildcards so that "50%" or "a_b" are searched literally.
  static String likePattern(String query) =>
      '%${query.trim().replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%';

  Future<List<Note>> searchNotes(String query, {int? categoryId}) async {
    final q = likePattern(query);
    final where = StringBuffer(r'''
      (n.title LIKE ? ESCAPE '\' OR n.content LIKE ? ESCAPE '\' OR c.name LIKE ? ESCAPE '\'
       OR EXISTS (SELECT 1 FROM attachments a WHERE a.note_id = n.id AND a.file_name LIKE ? ESCAPE '\'))''');
    final args = <Object?>[q, q, q, q];
    if (categoryId != null) {
      where.write(' AND n.category_id = ?');
      args.add(categoryId);
    }
    final rows = await _db.rawQuery('''
      SELECT n.* FROM notes n
      LEFT JOIN categories c ON c.id = n.category_id
      WHERE $where
      ORDER BY n.date DESC, n.created_at DESC''', args);
    return _withAttachments(rows);
  }

  Future<Note?> note(int id) async {
    final rows = await _db.query('notes', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return (await _withAttachments(rows)).first;
  }

  Future<int> saveNote(Note n) async {
    if (n.id == null) {
      final m = n.toMap()..remove('id');
      return _db.insert('notes', m);
    }
    final updated = await _db.update('notes', n.toMap(), where: 'id = ?', whereArgs: [n.id]);
    // Deleted on another device while it was being edited: the text is kept.
    if (updated == 0) return _db.insert('notes', n.toMap()..remove('id'));
    return n.id!;
  }

  Future<void> deleteNote(int id) => _db.delete('notes', where: 'id = ?', whereArgs: [id]);

  // ------------------------------------------------------------- attachments
  Future<int> addAttachment({
    required int noteId,
    required AttachmentKind kind,
    required String fileName,
    String? mime,
    required Uint8List data,
  }) {
    return _db.transaction((txn) async {
      final id = await txn.insert('attachments', {
        'note_id': noteId,
        'kind': kind.name,
        'file_name': fileName,
        'mime': mime,
        'size': data.length,
        'created_at': DateTime.now().toIso8601String(),
      });
      await AppDatabase.writeChunks(txn, id, data);
      return id;
    });
  }

  Future<Uint8List> attachmentData(int id) => AppDatabase.readChunks(_db, id);

  /// Replaces the content of an attachment (e.g. an edited drawing).
  Future<void> updateAttachmentData(int id, Uint8List data) => _db.transaction((txn) async {
    await txn.delete('attachment_chunks', where: 'attachment_id = ?', whereArgs: [id]);
    await AppDatabase.writeChunks(txn, id, data);
    await txn.update('attachments', {'size': data.length}, where: 'id = ?', whereArgs: [id]);
  });

  Future<void> renameAttachment(int id, String name) =>
      _db.update('attachments', {'file_name': name}, where: 'id = ?', whereArgs: [id]);

  Future<void> deleteAttachment(int id) => _db.delete('attachments', where: 'id = ?', whereArgs: [id]);

  // ------------------------------------------------------------ raw (export)
  Future<List<Map<String, Object?>>> rawTable(String table) => _db.query(table);

  /// Tables restored from a backup, in insertion order (parents first).
  static const restorableTables = [
    'settings',
    'categories',
    'time_entries',
    'vacation_years',
    'journal_entries',
    'notes',
    'attachments',
  ];

  /// Replaces all data with the content of a backup (see ExportService).
  ///
  /// Only known tables and columns are written: column names come from the
  /// backup file and must never reach the SQL unchecked.
  Future<void> restore(Map<String, List<Map<String, Object?>>> tables, Map<int, Uint8List> attachmentData) async {
    await _db.transaction((txn) async {
      await txn.delete('attachment_chunks');
      for (final t in restorableTables.reversed) {
        await txn.delete(t);
      }
      for (final t in restorableTables) {
        final columns = {for (final c in await txn.rawQuery('PRAGMA table_info($t)')) c['name']! as String};
        for (final row in tables[t] ?? const <Map<String, Object?>>[]) {
          await txn.insert(t, {
            for (final e in row.entries)
              if (columns.contains(e.key)) e.key: e.value,
          });
        }
      }
      for (final e in attachmentData.entries) {
        await AppDatabase.writeChunks(txn, e.key, e.value);
      }
    });
    await WidgetSync.refresh();
  }
}
