import 'package:sqflite/sqflite.dart';

/// How the global id (`uid`) of a row is built.
enum UidKind {
  /// Random id: rows created on two devices are different rows.
  random,

  /// Derived from a natural key (date, year, setting key): the same day
  /// clocked on two devices is the same row, and its columns are merged.
  natural,
}

/// Synchronized table: its business columns and references to other tables.
class SyncTable {
  final String name;
  final UidKind uidKind;

  /// SQL expression of the natural uid (for [UidKind.natural]), using `NEW.`.
  final String? naturalUid;

  /// Columns exchanged with other devices (local `id`, `uid`, `modified_at` excluded).
  final List<String> columns;

  /// Foreign keys: local column -> referenced table. Exchanged as uids.
  final Map<String, String> references;

  /// Optional SQL condition on `NEW.` rows that must not be synchronized.
  final String? localOnlyCondition;

  const SyncTable(
    this.name, {
    required this.uidKind,
    this.naturalUid,
    required this.columns,
    this.references = const {},
    this.localOnlyCondition,
  });

  String get primaryKey => switch (name) {
    'settings' => 'key',
    'vacation_years' => 'year',
    _ => 'id',
  };
}

/// Database structures that prepare TimeLog for an online synchronization
/// (offline first). See docs/SYNC.md.
///
/// * Every synchronized row has a global `uid` and a `modified_at` timestamp
///   (milliseconds since epoch), maintained by triggers, so that every writer
///   (the app, the Android widget, a backup restore) is covered.
/// * When synchronization is enabled, triggers record each change (table, uid,
///   changed columns) in `sync_log`, the outbox read by the sync engine.
/// * Synchronization is disabled by default: nothing is recorded then.
abstract final class SyncSchema {
  /// Settings that stay on each device (appearance, language, time format).
  static const deviceLocalSettings = {'themeMode', 'accentColor', 'language', 'use24h'};

  /// Synchronized tables, parents first (order used to apply remote changes).
  static final tables = <SyncTable>[
    SyncTable(
      'settings',
      uidKind: UidKind.natural,
      naturalUid: "'setting:' || NEW.key",
      columns: const ['key', 'value'],
      localOnlyCondition: 'NEW.key IN (${deviceLocalSettings.map((k) => "'$k'").join(', ')})',
    ),
    const SyncTable('categories', uidKind: UidKind.random, columns: ['name', 'color']),
    const SyncTable(
      'time_entries',
      uidKind: UidKind.natural,
      naturalUid: "'day:' || NEW.date",
      columns: [
        'date',
        'day_type',
        'absence_part',
        'absence_minutes',
        'arrival',
        'lunch_start',
        'lunch_end',
        'departure',
        'comment',
      ],
    ),
    const SyncTable(
      'vacation_years',
      uidKind: UidKind.natural,
      naturalUid: "'year:' || NEW.year",
      columns: ['year', 'entitlement', 'carry_over'],
    ),
    const SyncTable(
      'journal_entries',
      uidKind: UidKind.random,
      columns: ['date', 'title', 'content', 'duration_minutes', 'category_id', 'created_at', 'updated_at'],
      references: {'category_id': 'categories'},
    ),
    const SyncTable(
      'notes',
      uidKind: UidKind.random,
      columns: ['date', 'title', 'content', 'category_id', 'created_at', 'updated_at'],
      references: {'category_id': 'categories'},
    ),
    const SyncTable(
      'attachments',
      uidKind: UidKind.random,
      columns: ['note_id', 'kind', 'file_name', 'mime', 'size', 'created_at'],
      references: {'note_id': 'notes'},
    ),
  ];

  static SyncTable table(String name) => tables.firstWhere((t) => t.name == name);

  /// Current time in milliseconds since epoch, in SQL.
  static const nowMs = "CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER)";

  /// Random uid (32 hex characters), in SQL.
  static const randomUid = 'lower(hex(randomblob(16)))';

  // COALESCE: a missing key must give false, not NULL (NOT NULL is NULL in SQL).
  static const _isEnabled = "COALESCE((SELECT value FROM sync_meta WHERE key = 'enabled'), '0') = '1'";
  static const _isApplyingRemote = "COALESCE((SELECT value FROM sync_meta WHERE key = 'applying'), '0') = '1'";

  /// Adds the sync columns / tables / triggers (database version 4).
  /// Safe to call on a database that already has them.
  static Future<void> install(Database db) async {
    await db.execute('CREATE TABLE IF NOT EXISTS sync_meta (key TEXT PRIMARY KEY, value TEXT)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_log (
        seq INTEGER PRIMARY KEY AUTOINCREMENT,
        tbl TEXT NOT NULL,
        uid TEXT NOT NULL,
        op TEXT NOT NULL,
        columns TEXT NOT NULL,
        at INTEGER NOT NULL
      )''');
    final present = await _existingTables(db);
    for (final t in tables.where((t) => present.contains(t.name))) {
      final existing = {for (final c in await db.rawQuery('PRAGMA table_info(${t.name})')) c['name']! as String};
      if (!existing.contains('uid')) await db.execute('ALTER TABLE ${t.name} ADD COLUMN uid TEXT');
      if (!existing.contains('modified_at')) {
        await db.execute('ALTER TABLE ${t.name} ADD COLUMN modified_at INTEGER');
      }
      // Existing rows get their uid and a modification date.
      final uid = t.uidKind == UidKind.natural ? t.naturalUid!.replaceAll('NEW.', '') : randomUid;
      await db.execute('UPDATE ${t.name} SET uid = $uid WHERE uid IS NULL');
      await db.execute('UPDATE ${t.name} SET modified_at = $nowMs WHERE modified_at IS NULL');
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_${t.name}_uid ON ${t.name}(uid)');
    }
    await installTriggers(db);
  }

  /// (Re)creates the triggers. Must be called again after a schema change of
  /// a synchronized table (the column lists are part of the triggers).
  static Future<void> installTriggers(Database db) async {
    final present = await _existingTables(db);
    for (final t in tables.where((t) => present.contains(t.name))) {
      for (final suffix in ['ins', 'upd', 'del']) {
        await db.execute('DROP TRIGGER IF EXISTS sync_${t.name}_$suffix');
      }
      final key = t.primaryKey;
      final logIf = [
        _isEnabled,
        'NOT $_isApplyingRemote',
        if (t.localOnlyCondition != null) 'NOT (${t.localOnlyCondition})',
      ].join(' AND ');
      // Non-null columns of a new row / columns changed by an update.
      final insertedCols = _columnList(t.columns, (c) => 'NEW.$c IS NOT NULL');
      final updatedCols = _columnList(t.columns, (c) => 'OLD.$c IS NOT NEW.$c');
      final uid = t.uidKind == UidKind.natural ? t.naturalUid! : randomUid;

      await db.execute('''
        CREATE TRIGGER sync_${t.name}_ins AFTER INSERT ON ${t.name}
        BEGIN
          UPDATE ${t.name} SET
            uid = COALESCE(NEW.uid, $uid),
            modified_at = CASE WHEN $_isApplyingRemote THEN COALESCE(NEW.modified_at, $nowMs) ELSE $nowMs END
          WHERE $key = NEW.$key;
          INSERT INTO sync_log (tbl, uid, op, columns, at)
          SELECT '${t.name}', uid, 'upsert', $insertedCols, modified_at FROM ${t.name}
          WHERE $key = NEW.$key AND $logIf;
        END''');

      final changed = t.columns.map((c) => 'OLD.$c IS NOT NEW.$c').join(' OR ');
      await db.execute('''
        CREATE TRIGGER sync_${t.name}_upd AFTER UPDATE ON ${t.name}
        WHEN ($changed) AND NOT $_isApplyingRemote
        BEGIN
          UPDATE ${t.name} SET modified_at = $nowMs WHERE $key = NEW.$key;
          INSERT INTO sync_log (tbl, uid, op, columns, at)
          SELECT '${t.name}', NEW.uid, 'upsert', $updatedCols, $nowMs WHERE $logIf;
        END''');

      final deleteIf = [
        _isEnabled,
        'NOT $_isApplyingRemote',
        if (t.localOnlyCondition != null) 'NOT (${t.localOnlyCondition!.replaceAll('NEW.', 'OLD.')})',
      ].join(' AND ');
      await db.execute('''
        CREATE TRIGGER sync_${t.name}_del AFTER DELETE ON ${t.name}
        WHEN $deleteIf AND OLD.uid IS NOT NULL
        BEGIN
          INSERT INTO sync_log (tbl, uid, op, columns, at) VALUES ('${t.name}', OLD.uid, 'delete', '', $nowMs);
        END''');
    }

    // New content of an attachment file (chunks are written after the row).
    await db.execute('DROP TRIGGER IF EXISTS sync_attachment_data');
    if (!present.contains('attachment_chunks') || !present.contains('attachments')) return;
    await db.execute('''
      CREATE TRIGGER sync_attachment_data AFTER INSERT ON attachment_chunks
      WHEN NEW.idx = 0 AND $_isEnabled AND NOT $_isApplyingRemote
      BEGIN
        INSERT INTO sync_log (tbl, uid, op, columns, at)
        SELECT 'attachments', uid, 'upsert', 'data', $nowMs FROM attachments WHERE id = NEW.attachment_id;
      END''');
  }

  /// SQL recording every existing row of [t] in `sync_log` (first sync).
  static String snapshotSql(SyncTable t) {
    final cols = _columnList(t.columns, (c) => '$c IS NOT NULL');
    final where = t.localOnlyCondition == null ? '' : 'WHERE NOT (${t.localOnlyCondition!.replaceAll('NEW.', '')})';
    return 'INSERT INTO sync_log (tbl, uid, op, columns, at) '
        "SELECT '${t.name}', uid, 'upsert', $cols, modified_at FROM ${t.name} $where";
  }

  static Future<Set<String>> _existingTables(Database db) async => {
    for (final r in await db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'")) r['name']! as String,
  };

  /// SQL building "a,b,c" from the columns matching [condition].
  static String _columnList(List<String> columns, String Function(String) condition) {
    final parts = columns.map((c) => "CASE WHEN ${condition(c)} THEN '$c,' ELSE '' END").join(' || ');
    return "rtrim($parts, ',')";
  }
}
