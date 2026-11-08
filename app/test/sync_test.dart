import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' show Sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timelog/data/database.dart';
import 'package:timelog/sync/sync_engine.dart';
import 'package:timelog/sync/sync_models.dart';

import 'support/memory_sync_backend.dart';

/// A simulated device: its own database file and sync engine.
class Device {
  final Database db;
  final SyncEngine sync;
  Device(this.db, this.sync);

  Future<Map<String, Object?>?> day(String date) async {
    final r = await db.query('time_entries', where: 'date = ?', whereArgs: [date]);
    return r.isEmpty ? null : r.first;
  }

  /// Same SQL as the app (upsert on the date) / the Android widget.
  Future<void> clock(String date, String column, int minutes) => db.rawInsert(
    'INSERT INTO time_entries (date, $column) VALUES (?, ?) ON CONFLICT(date) DO UPDATE SET $column = excluded.$column',
    [date, minutes],
  );

  Future<int> logCount() async => Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM sync_log'))!;
}

void main() {
  late Directory dir;
  late MemorySyncBackend server;
  var n = 0;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('timelog_sync');
    server = MemorySyncBackend();
  });

  tearDown(() => dir.delete(recursive: true));

  Future<Device> device() async {
    final db = await AppDatabase.openFile('${dir.path}/device${n++}.db');
    addTearDown(db.close);
    return Device(db, SyncEngine(db, server));
  }

  test('every row gets a global id and a modification date, nothing is logged while disabled', () async {
    final a = await device();
    await a.clock('2026-11-09', 'arrival', 480);
    final day = (await a.day('2026-11-09'))!;
    expect(day['uid'], 'day:2026-11-09');
    expect(day['modified_at'], isA<int>());
    final cat = await a.db.insert('categories', {'name': 'Client', 'color': 1});
    final c = (await a.db.query('categories', where: 'id = ?', whereArgs: [cat])).first;
    expect((c['uid']! as String).length, 32);
    expect(await a.logCount(), 0);
  });

  test('account: wrong password is refused, the password is not stored', () async {
    final a = await device();
    await a.sync.signUp('lukas@example.com', 'secret-123');
    final b = await device();
    await expectLater(b.sync.signIn('lukas@example.com', 'wrong'), throwsA(isA<SyncAuthException>()));
    await b.sync.signIn(' lukas@example.com ', 'secret-123');
    final meta = await b.db.query('sync_meta');
    expect(meta.map((m) => m['value']), isNot(contains('secret-123')));
    expect((await b.sync.session())!.email, 'lukas@example.com');
  });

  test('clock arrival on the phone and departure on the computer (offline), then merge', () async {
    final phone = await device();
    final pc = await device();
    await phone.sync.signUp('l@x.ch', 'pw');
    await pc.sync.signIn('l@x.ch', 'pw');

    server.online = false;
    await phone.clock('2026-11-09', 'arrival', 480);
    await pc.clock('2026-11-09', 'departure', 1020);
    await expectLater(phone.sync.sync(), throwsA(isA<SyncNetworkException>()));
    // Offline: the app keeps working, the changes wait in the log.
    expect(await phone.logCount(), greaterThan(0));

    server.online = true;
    await phone.sync.sync();
    await pc.sync.sync();
    await phone.sync.sync();
    for (final d in [phone, pc]) {
      final day = (await d.day('2026-11-09'))!;
      expect(day['arrival'], 480);
      expect(day['departure'], 1020);
    }
    expect(await phone.logCount(), 0);
  });

  test('same column changed on both devices: the most recent change wins', () async {
    final a = await device();
    final b = await device();
    await a.sync.signUp('l@x.ch', 'pw');
    await b.sync.signIn('l@x.ch', 'pw');
    await a.clock('2026-11-09', 'arrival', 480);
    await a.sync.sync();
    await b.sync.sync();

    await a.clock('2026-11-09', 'arrival', 485);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await b.clock('2026-11-09', 'arrival', 490); // later
    await a.sync.sync();
    await b.sync.sync();
    await a.sync.sync();
    expect((await a.day('2026-11-09'))!['arrival'], 490);
    expect((await b.day('2026-11-09'))!['arrival'], 490);
  });

  test('existing data, journal with category, note with attachment and deletions', () async {
    final a = await device();
    // Data created before the account is connected is sent too.
    final cat = await a.db.insert('categories', {'name': 'Client A', 'color': 0xFF00FF00});
    await a.db.insert('journal_entries', {
      'date': '2026-11-09',
      'title': 'Réunion',
      'content': '**ok**',
      'duration_minutes': 60,
      'category_id': cat,
      'created_at': '2026-11-09T09:00:00',
      'updated_at': '2026-11-09T09:00:00',
    });
    final note = await a.db.insert('notes', {
      'date': '2026-11-09',
      'title': 'Plan',
      'created_at': '2026-11-09T09:00:00',
      'updated_at': '2026-11-09T09:00:00',
    });
    final bytes = Uint8List.fromList(List.generate(AppDatabase.chunkSize + 1000, (i) => i % 251));
    final att = await a.db.insert('attachments', {
      'note_id': note,
      'kind': 'document',
      'file_name': 'plan.pdf',
      'size': bytes.length,
      'created_at': '2026-11-09T09:00:00',
    });
    await AppDatabase.writeChunks(a.db, att, bytes);
    await a.db.insert('settings', {'key': 'dailyTargetMinutes', 'value': '480'});
    await a.db.insert('settings', {'key': 'themeMode', 'value': 'dark'}); // stays on the device

    await a.sync.signUp('l@x.ch', 'pw');
    await a.sync.sync();
    final b = await device();
    await b.sync.signIn('l@x.ch', 'pw');
    await b.sync.sync();

    final j = (await b.db.query('journal_entries')).single;
    final bCat = (await b.db.query('categories')).single;
    expect(j['title'], 'Réunion');
    expect(j['category_id'], bCat['id']);
    expect(bCat['name'], 'Client A');
    final bAtt = (await b.db.query('attachments')).single;
    expect(await AppDatabase.readChunks(b.db, bAtt['id']! as int), bytes);
    final settings = {for (final s in await b.db.query('settings')) s['key']: s['value']};
    expect(settings['dailyTargetMinutes'], '480');
    expect(settings.containsKey('themeMode'), isFalse);

    // Deleting the note on B deletes it (and its attachment) on A.
    await b.db.delete('notes');
    await b.sync.sync();
    await a.sync.sync();
    expect(await a.db.query('notes'), isEmpty);
    expect(await a.db.query('attachments'), isEmpty);
    expect(await a.db.query('journal_entries'), hasLength(1));
  });

  test('sign out: local data kept, nothing recorded anymore', () async {
    final a = await device();
    await a.sync.signUp('l@x.ch', 'pw');
    await a.clock('2026-11-09', 'arrival', 480);
    await a.sync.signOut();
    await a.clock('2026-11-09', 'departure', 1000);
    expect(await a.logCount(), 0);
    expect(await a.sync.session(), isNull);
    expect((await a.day('2026-11-09'))!['departure'], 1000);
    await expectLater(a.sync.sync(), throwsA(isA<SyncAuthException>()));
  });
}
