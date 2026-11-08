// End-to-end test of the synchronization with a real server (server/ folder):
//   cd server && docker compose up -d --build
//   TIMELOG_SERVER=http://localhost:8787 flutter test test/server_e2e_test.dart
// Skipped when TIMELOG_SERVER is not set.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timelog/data/database.dart';
import 'package:timelog/sync/http_sync_backend.dart';
import 'package:timelog/sync/sync_engine.dart';
import 'package:timelog/sync/sync_models.dart';

void main() {
  final server = Platform.environment['TIMELOG_SERVER'];
  late Directory dir;
  var n = 0;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async => dir = await Directory.systemTemp.createTemp('timelog_e2e'));
  tearDown(() => dir.delete(recursive: true));

  Future<SyncEngine> device() async {
    final db = await AppDatabase.openFile('${dir.path}/d${n++}.db');
    addTearDown(db.close);
    return SyncEngine(db, HttpSyncBackend(server!));
  }

  Future<Map<String, Object?>?> day(SyncEngine e, String date) async {
    final r = await e.db.query('time_entries', where: 'date = ?', whereArgs: [date]);
    return r.isEmpty ? null : r.first;
  }

  Future<void> clock(SyncEngine e, String date, String col, int v) => e.db.rawInsert(
    'INSERT INTO time_entries (date, $col) VALUES (?, ?) ON CONFLICT(date) DO UPDATE SET $col = excluded.$col',
    [date, v],
  );

  test('phone + computer through the real server', () async {
    final email = 'e2e-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}@example.com';
    final phone = await device();
    final pc = await device();

    await expectLater(phone.signUp(email, 'court'), throwsA(isA<SyncAuthException>()));
    await phone.signUp(email, 'motdepasse-e2e');
    await expectLater(pc.signIn(email, 'mauvais-mdp'), throwsA(isA<SyncAuthException>()));
    await pc.signIn(email, 'motdepasse-e2e');

    // Phone: arrival + a note with a 1.2 MB attachment; computer: departure.
    await clock(phone, '2026-11-09', 'arrival', 480);
    final note = await phone.db.insert('notes', {
      'date': '2026-11-09',
      'title': 'Facture',
      'created_at': '2026-11-09T09:00:00',
      'updated_at': '2026-11-09T09:00:00',
    });
    final bytes = Uint8List.fromList(List.generate(1200000, (i) => i % 253));
    final att = await phone.db.insert('attachments', {
      'note_id': note,
      'kind': 'document',
      'file_name': 'facture.pdf',
      'size': bytes.length,
      'created_at': '2026-11-09T09:00:00',
    });
    await AppDatabase.writeChunks(phone.db, att, bytes);
    await clock(pc, '2026-11-09', 'departure', 1020);

    await phone.sync();
    await pc.sync();
    await phone.sync();

    for (final d in [phone, pc]) {
      final r = (await day(d, '2026-11-09'))!;
      expect(r['arrival'], 480);
      expect(r['departure'], 1020);
    }
    final a = (await pc.db.query('attachments')).single;
    expect(await AppDatabase.readChunks(pc.db, a['id']! as int), bytes);
    expect((await pc.db.query('notes')).single['title'], 'Facture');

    // Same column on both: the most recent wins; deletion propagates.
    await clock(phone, '2026-11-09', 'arrival', 485);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await clock(pc, '2026-11-09', 'arrival', 490);
    await pc.db.delete('notes');
    await phone.sync();
    await pc.sync();
    await phone.sync();
    expect((await day(phone, '2026-11-09'))!['arrival'], 490);
    expect((await day(pc, '2026-11-09'))!['arrival'], 490);
    expect(await phone.db.query('notes'), isEmpty);
    expect(await phone.db.query('attachments'), isEmpty);

    // A third device gets the current state at once.
    final tablet = await device();
    await tablet.signIn(email, 'motdepasse-e2e');
    await tablet.sync();
    expect((await day(tablet, '2026-11-09'))!['departure'], 1020);

    // Delete the account: everything is removed from the server.
    await phone.deleteAccount('motdepasse-e2e');
    await expectLater(pc.sync(), throwsA(isA<SyncAuthException>()));
  }, skip: server == null ? 'set TIMELOG_SERVER to run' : false);
}
