import 'package:flutter/foundation.dart' show listEquals;
import 'package:sqflite/sqflite.dart';

import '../data/database.dart';
import 'sync_backend.dart';
import 'sync_models.dart';
import 'sync_schema.dart';

/// Offline-first synchronization of all the data with an online account.
///
/// The app always works on its local SQLite database. When an account is
/// connected, [sync] sends the local changes recorded in `sync_log` and
/// applies the changes made on the other devices:
/// * rows are identified by their global uid (a day is `day:YYYY-MM-DD` on
///   every device, so the same day clocked on the phone and on the computer
///   is merged);
/// * edits are merged column by column; when the same column was changed on
///   both sides, the most recent change wins;
/// * a deletion wins over older edits, a newer edit wins over a deletion.
///
/// See docs/SYNC.md at the repository root.
/// A local change to send and the last `sync_log` entry it covers.
class PendingChange {
  final SyncChange change;
  final int lastSeq;
  const PendingChange(this.change, this.lastSeq);
}

class SyncEngine {
  final Database db;
  final SyncBackend backend;

  SyncEngine(this.db, this.backend);

  // ------------------------------------------------------------ meta / state
  Future<String?> _meta(String key) async {
    final r = await db.query('sync_meta', where: 'key = ?', whereArgs: [key]);
    return r.isEmpty ? null : r.first['value'] as String?;
  }

  Future<void> _setMeta(DatabaseExecutor ex, String key, String? value) => value == null
      ? ex.delete('sync_meta', where: 'key = ?', whereArgs: [key])
      : ex.insert('sync_meta', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);

  /// Identifier of this device (created once).
  Future<String> deviceId() async {
    final id = await _meta('device_id');
    if (id != null) return id;
    final r = await db.rawQuery('SELECT ${SyncSchema.randomUid} AS id');
    final created = r.first['id']! as String;
    await _setMeta(db, 'device_id', created);
    return created;
  }

  Future<bool> get isEnabled async => await _meta('enabled') == '1';

  /// Connected account, or null.
  Future<SyncSession?> session() async {
    final token = await _meta('token');
    final email = await _meta('email');
    final account = await _meta('account_id');
    if (token == null || email == null || account == null) return null;
    return SyncSession(accountId: account, email: email, token: token);
  }

  // ---------------------------------------------------------------- account
  /// Signs in and enables the synchronization. The local data is then sent
  /// to the account at the next [sync] (merged with the data already there).
  Future<SyncSession> signIn(String email, String password) async =>
      _connect(await backend.signIn(email.trim(), password));

  Future<SyncSession> signUp(String email, String password) async =>
      _connect(await backend.signUp(email.trim(), password));

  Future<SyncSession> _connect(SyncSession s) async {
    await db.transaction((txn) async {
      await _setMeta(txn, 'account_id', s.accountId);
      await _setMeta(txn, 'email', s.email);
      await _setMeta(txn, 'token', s.token);
      await _setMeta(txn, 'cursor', null);
      await txn.delete('sync_log');
      // Everything existing has to be sent once.
      for (final t in SyncSchema.tables) {
        await txn.execute(SyncSchema.snapshotSql(t));
      }
      await txn.execute(
        'INSERT INTO sync_log (tbl, uid, op, columns, at) '
        "SELECT 'attachments', uid, 'upsert', 'data', modified_at FROM attachments",
      );
      await _setMeta(txn, 'enabled', '1');
    });
    return s;
  }

  /// Signs out: the local data stays on the device, nothing is recorded anymore.
  /// Works offline (the server session then simply expires).
  Future<void> signOut() async {
    final s = await session();
    if (s != null) {
      try {
        await backend.signOut(s);
      } on SyncNetworkException {
        // Offline: the session expires on the server.
      } on SyncAuthException {
        // Already expired.
      }
    }
    await forgetAccount();
  }

  /// Deletes the online account and its data; the data stays on this device.
  Future<void> deleteAccount(String password) async {
    final s = await session();
    if (s == null) throw const SyncAuthException('unauthorized');
    await backend.deleteAccount(s, password);
    await forgetAccount();
  }

  /// Local part of signing out (also used when the session has expired).
  Future<void> forgetAccount() async {
    await db.transaction((txn) async {
      for (final k in ['enabled', 'account_id', 'token', 'cursor', 'last_sync']) {
        await _setMeta(txn, k, null);
      }
      await txn.delete('sync_log');
    });
  }

  // ------------------------------------------------------------------- sync
  /// Limits of one request sent to the server.
  static const maxChangesPerPush = 200;
  static const maxBytesPerPush = 16 * 1024 * 1024;

  /// Receives the changes of the other devices, then sends the local ones.
  ///
  /// Receiving first matters: the local changes not sent yet protect the
  /// columns edited here more recently than the remote changes.
  /// Throws if the server cannot be reached: nothing is lost, the local
  /// changes stay in `sync_log` until the next successful sync.
  Future<SyncReport> sync() async {
    final s = await session();
    if (s == null || !await isEnabled) throw const SyncAuthException('unauthorized');
    final device = await deviceId();

    // 1. Receive.
    var pulled = 0;
    var changed = 0;
    PullResult page;
    do {
      page = await backend.pull(s, device, await _meta('cursor'));
      changed += await _applyAll(page);
      pulled += page.changes.length;
    } while (page.hasMore);

    // 2. Send, in batches.
    final pending = await pendingChanges();
    var pushed = 0;
    while (pushed < pending.length) {
      final batch = <PendingChange>[];
      var bytes = 0;
      while (pushed + batch.length < pending.length && batch.length < maxChangesPerPush) {
        final next = pending[pushed + batch.length];
        final size = next.change.data?.length ?? 0;
        if (batch.isNotEmpty && bytes + size > maxBytesPerPush) break;
        batch.add(next);
        bytes += size;
      }
      await backend.push(s, device, [for (final p in batch) p.change]);
      // Only what was sent is removed (a newer edit of the same row stays).
      await db.transaction((txn) async {
        for (final p in batch) {
          await txn.delete(
            'sync_log',
            where: 'tbl = ? AND uid = ? AND seq <= ?',
            whereArgs: [p.change.table, p.change.uid, p.lastSeq],
          );
        }
      });
      pushed += batch.length;
    }
    await _setMeta(db, 'last_sync', DateTime.now().toIso8601String());
    return SyncReport(pushed: pushed, pulled: pulled, changed: changed);
  }

  /// E-mail of the last account used on this device (to fill the login form).
  Future<String?> lastEmail() => _meta('email');

  /// Address of the server (kept on this device after signing out).
  Future<String?> serverUrl() => _meta('server_url');

  Future<void> setServerUrl(String url) => _setMeta(db, 'server_url', url);

  /// Date of the last successful synchronization.
  Future<DateTime?> lastSync() async => DateTime.tryParse(await _meta('last_sync') ?? '');

  /// Number of local rows changed and not sent yet.
  Future<int> pendingCount() async =>
      Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(DISTINCT tbl || uid) FROM sync_log')) ?? 0;

  /// Applies a page of changes and returns how many really changed the local data.
  Future<int> _applyAll(PullResult page) async {
    final order = {for (var i = 0; i < SyncSchema.tables.length; i++) SyncSchema.tables[i].name: i};
    final sorted = [...page.changes.where((c) => order.containsKey(c.table))]
      // Parents first for creations, children first for deletions.
      ..sort((a, b) {
        if (a.deleted != b.deleted) return a.deleted ? 1 : -1;
        final c = order[a.table]!.compareTo(order[b.table]!);
        return a.deleted ? -c : c;
      });
    return db.transaction((txn) async {
      var changed = 0;
      await _setMeta(txn, 'applying', '1');
      try {
        for (final c in sorted) {
          if (await _apply(txn, c)) changed++;
        }
        await _setMeta(txn, 'cursor', page.cursor);
      } finally {
        await _setMeta(txn, 'applying', null);
      }
      return changed;
    });
  }

  /// Local changes not sent yet, one per row, oldest first.
  Future<List<PendingChange>> pendingChanges() async {
    final device = await deviceId();
    final groups = await db.rawQuery('''
      SELECT tbl, uid, MAX(seq) AS seq, MAX(at) AS at, GROUP_CONCAT(columns, ',') AS cols
      FROM sync_log GROUP BY tbl, uid ORDER BY MIN(seq)''');
    final changes = <PendingChange>[];
    for (final g in groups) {
      final table = SyncSchema.table(g['tbl']! as String);
      final uid = g['uid']! as String;
      final at = g['at']! as int;
      final seq = g['seq']! as int;
      final rows = await db.query(table.name, where: 'uid = ?', whereArgs: [uid]);
      if (rows.isEmpty) {
        changes.add(
          PendingChange(SyncChange(table: table.name, uid: uid, deleted: true, modifiedAt: at, deviceId: device), seq),
        );
        continue;
      }
      final row = rows.first;
      final cols = {...(g['cols']! as String).split(',').where((c) => c.isNotEmpty)};
      final values = <String, Object?>{};
      for (final c in table.columns) {
        final ref = table.references[c];
        values[c] = ref == null ? row[c] : await _uidOf(db, ref, row[c] as int?);
      }
      changes.add(
        PendingChange(
          SyncChange(
            table: table.name,
            uid: uid,
            values: values,
            columns: cols.difference({'data'}),
            modifiedAt: (row['modified_at'] as int?) ?? at,
            deviceId: device,
            data: cols.contains('data') ? await AppDatabase.readChunks(db, row['id']! as int) : null,
          ),
          seq,
        ),
      );
    }
    return changes;
  }

  // ------------------------------------------------------------------ apply
  /// Applies one change. Returns whether the local data is different afterwards.
  Future<bool> _apply(Transaction txn, SyncChange c) async {
    final table = SyncSchema.table(c.table);
    final rows = await txn.query(table.name, where: 'uid = ?', whereArgs: [c.uid]);
    final local = rows.isEmpty ? null : rows.first;

    // Local changes not sent yet: column -> time.
    final pending = <String, int>{};
    var pendingDelete = 0;
    for (final p in await txn.query('sync_log', where: 'tbl = ? AND uid = ?', whereArgs: [table.name, c.uid])) {
      final at = p['at']! as int;
      if (p['op'] == 'delete') pendingDelete = at > pendingDelete ? at : pendingDelete;
      for (final col in (p['columns']! as String).split(',').where((x) => x.isNotEmpty)) {
        pending[col] = (pending[col] ?? 0) > at ? pending[col]! : at;
      }
    }
    final newestLocalEdit = pending.values.fold(0, (a, b) => a > b ? a : b);

    if (c.deleted) {
      // A newer local edit wins over the remote deletion.
      if (local != null && newestLocalEdit <= c.modifiedAt) {
        await txn.delete(table.name, where: 'uid = ?', whereArgs: [c.uid]);
        return true;
      }
      return false;
    }

    // References are exchanged as uids.
    final values = <String, Object?>{};
    for (final col in table.columns) {
      if (!c.values.containsKey(col)) continue;
      final ref = table.references[col];
      values[col] = ref == null ? c.values[col] : await _idOf(txn, ref, c.values[col] as String?);
    }
    // An attachment whose note does not exist (anymore) is ignored.
    if (table.name == 'attachments' && values['note_id'] == null) return false;

    int? id;
    var changed = false;
    if (local == null) {
      if (pendingDelete > c.modifiedAt) return false; // deleted here after the remote edit
      await txn.insert(table.name, {...values, 'uid': c.uid, 'modified_at': c.modifiedAt});
      changed = true;
      if (table.name == 'attachments') {
        id =
            (await txn.query('attachments', columns: ['id'], where: 'uid = ?', whereArgs: [c.uid])).first['id']! as int;
      }
    } else {
      // A column changed here more recently (not sent yet) is kept.
      final update = <String, Object?>{
        for (final col in c.columns)
          if (values.containsKey(col) && (pending[col] ?? 0) <= c.timeOf(col)) col: values[col],
      };
      changed = update.entries.any((e) => local[e.key] != e.value);
      final localAt = (local['modified_at'] as int?) ?? 0;
      update['modified_at'] = localAt > c.modifiedAt ? localAt : c.modifiedAt;
      await txn.update(table.name, update, where: 'uid = ?', whereArgs: [c.uid]);
      id = local['id'] as int?;
    }
    final data = c.data;
    if (data != null &&
        id != null &&
        (pending['data'] ?? 0) <= c.timeOf('data') &&
        (local == null || !listEquals(await AppDatabase.readChunks(txn, id), data))) {
      await txn.delete('attachment_chunks', where: 'attachment_id = ?', whereArgs: [id]);
      await AppDatabase.writeChunks(txn, id, data);
      changed = true;
    }
    return changed;
  }

  // ---------------------------------------------------------------- helpers
  static Future<String?> _uidOf(DatabaseExecutor ex, String table, int? id) async {
    if (id == null) return null;
    final r = await ex.query(table, columns: ['uid'], where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : r.first['uid'] as String?;
  }

  static Future<int?> _idOf(DatabaseExecutor ex, String table, String? uid) async {
    if (uid == null) return null;
    final r = await ex.query(table, columns: ['id'], where: 'uid = ?', whereArgs: [uid]);
    return r.isEmpty ? null : r.first['id'] as int?;
  }
}
