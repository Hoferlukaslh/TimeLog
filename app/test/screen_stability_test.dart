// The screen must never change by itself: synchronization and typing.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timelog/data/database.dart';
import 'package:timelog/data/repository.dart';
import 'package:timelog/main.dart';
import 'package:timelog/models/models.dart';
import 'package:timelog/services/categories_store.dart';
import 'package:timelog/services/settings.dart';
import 'package:timelog/sync/sync_controller.dart';
import 'package:timelog/sync/sync_engine.dart';
import 'package:timelog/sync/sync_models.dart';
import 'package:timelog/utils/dates.dart';

import 'support/memory_sync_backend.dart';

const _mail = 'a@example.com';
const _password = 'motdepasse';

class _Harness {
  final WidgetTester tester;
  final MemorySyncBackend backend;
  final SyncController sync;
  final SyncEngine other;
  _Harness(this.tester, this.backend, this.sync, this.other);

  Future<void> settle() async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> syncApp() async {
    await tester.runAsync(sync.syncNow);
    await settle();
  }

  /// A journal entry written today on another device.
  Future<void> remoteJournal(String title) => tester.runAsync(() async {
    final now = DateTime.now().toIso8601String();
    await other.db.insert('journal_entries', {
      'date': Dates.key(Dates.today()),
      'title': title,
      'content': '',
      'created_at': now,
      'updated_at': now,
    });
    await other.sync();
  });
}

Future<_Harness> _start(WidgetTester tester, Directory dir) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final backend = MemorySyncBackend();
  late AppSettings settings;
  late CategoriesStore cats;
  late SyncController sync;
  late SyncEngine other;
  await tester.runAsync(() async {
    await AppDatabase.instance.close();
    await AppDatabase.instance.open(overridePath: inMemoryDatabasePath);
    settings = AppSettings();
    await settings.load();
    await settings.setLanguage('fr');
    cats = CategoriesStore();
    await cats.load();
    other = SyncEngine(await AppDatabase.openFile('${dir.path}/other.db'), backend);
    await other.signUp(_mail, _password);
    sync = SyncController(AppDatabase.instance.db, backendFactory: (_) => backend);
    await sync.signIn('memory', _mail, _password);
  });
  addTearDown(
    () => tester.runAsync(() async {
      await other.db.close();
      await AppDatabase.instance.close();
    }),
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: cats),
        ChangeNotifierProvider.value(value: sync),
      ],
      child: const TimeLogApp(),
    ),
  );
  final h = _Harness(tester, backend, sync, other);
  await h.settle();
  return h;
}

void main() {
  late Directory dir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async => dir = await Directory.systemTemp.createTemp('timelog_stability'));
  tearDown(() async {
    try {
      await dir.delete(recursive: true);
    } on FileSystemException {
      // Windows may still hold the database file for a moment.
    }
  });

  group('sync engine', () {
    Future<SyncEngine> device(MemorySyncBackend b, String name) async {
      final db = await AppDatabase.openFile('${dir.path}/$name.db');
      addTearDown(db.close);
      return SyncEngine(db, b);
    }

    Future<void> addDay(SyncEngine e, String date) => e.db.insert('time_entries', {'date': date, 'arrival': 480});

    test('what this device pushed comes back without counting as a change', () async {
      final b = MemorySyncBackend();
      final a = await device(b, 'a');
      await a.signUp(_mail, _password);
      await addDay(a, '2026-11-09');
      await a.sync();
      final echo = await a.sync();
      expect(echo.pulled, 1);
      expect(echo.changed, 0);
    });

    test('a change from another device counts', () async {
      final b = MemorySyncBackend();
      final a = await device(b, 'a');
      final c = await device(b, 'c');
      await a.signUp(_mail, _password);
      await c.signIn(_mail, _password);
      await addDay(a, '2026-11-09');
      await a.sync();
      expect((await c.sync()).changed, 1);
    });

    test('a new installation keeps the tracking start of the account', () async {
      final b = MemorySyncBackend();
      final phone = await device(b, 'phone');
      await phone.signUp(_mail, _password);
      await phone.db.insert('settings', {'key': 'trackingStart', 'value': '2025-01-01'});
      await phone.sync();

      await AppDatabase.instance.close();
      await AppDatabase.instance.open(overridePath: inMemoryDatabasePath);
      addTearDown(AppDatabase.instance.close);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await AppSettings().load(); // first launch: the default is today
      final pc = SyncEngine(AppDatabase.instance.db, b);
      await pc.signIn(_mail, _password);
      await pc.sync();
      await phone.sync();

      Future<String?> value(SyncEngine e) async =>
          (await e.db.query('settings', where: "key = 'trackingStart'")).first['value'] as String?;
      expect(await value(pc), '2025-01-01');
      expect(await value(phone), '2025-01-01');
    });
  });

  test('an unexpected error does not leave the status on "syncing"', () async {
    final db = await AppDatabase.openFile('${dir.path}/err.db');
    addTearDown(db.close);
    final sync = SyncController(db, backendFactory: (_) => _BrokenBackend());
    await expectLater(sync.signIn('x', _mail, _password), throwsStateError);
    expect(sync.status, SyncStatus.error);
    await sync.syncNow(silent: true);
    expect(sync.status, SyncStatus.error);
  });

  test('saving an entry deleted meanwhile on another device keeps its text', () async {
    await AppDatabase.instance.close();
    await AppDatabase.instance.open(overridePath: inMemoryDatabasePath);
    addTearDown(AppDatabase.instance.close);
    final repo = Repository.instance;
    final now = DateTime.now();
    final n = Note(date: Dates.today(), title: 't', content: 'c', createdAt: now, updatedAt: now);
    final id = await repo.saveNote(n);
    await repo.deleteNote(id);
    final again = await repo.saveNote(
      Note(id: id, date: Dates.today(), title: 't', content: 'gardé', createdAt: now, updatedAt: now),
    );
    expect((await repo.note(again))?.content, 'gardé');
  });

  testWidgets('the period chosen survives data arriving from another device', (tester) async {
    final h = await _start(tester, dir);
    await tester.tap(find.text('Mois').first);
    await h.settle();
    expect(find.textContaining('Aucune saisie'), findsWidgets);
    await h.remoteJournal('du téléphone');
    await h.syncApp();
    expect(h.sync.dataVersion, greaterThan(0), reason: 'data really arrived');
    expect(find.textContaining('Aucune saisie'), findsWidgets, reason: 'still on the month view');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the text being typed survives, and the list refreshes in place', (tester) async {
    final h = await _start(tester, dir);
    await tester.tap(find.text('Journal de travail').first);
    await h.settle();
    await tester.tap(find.text('Ajout'));
    await h.settle();
    await tester.enterText(find.byType(TextField).first, 'En cours');
    await h.settle();
    await h.remoteJournal('du téléphone');
    await h.syncApp();
    expect(find.text('En cours'), findsOneWidget);
    expect(find.text('du téléphone'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('own changes coming back do not touch the screen', (tester) async {
    final h = await _start(tester, dir);
    final version = h.sync.dataVersion;
    await tester.runAsync(() => Repository.instance.saveTimeEntry(TimeEntry(date: Dates.today(), arrival: 480)));
    await h.syncApp(); // sent
    await h.syncApp(); // received back
    expect(h.sync.dataVersion, version);
  });

  testWidgets('a comment being typed survives a reload and is saved when leaving', (tester) async {
    final h = await _start(tester, dir);
    await tester.enterText(find.byType(TextField), 'à moitié écrit');
    await h.settle();
    await tester.runAsync(() async {
      await h.other.db.insert('time_entries', {'date': Dates.key(Dates.today()), 'arrival': 480});
      await h.other.sync();
    });
    await h.syncApp();
    expect(find.text('à moitié écrit'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget, reason: 'the remote time is shown');
    // By keyboard: nothing taps outside the field, which would save it too.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await h.settle();
    final e = (await tester.runAsync(() => Repository.instance.timeEntry(Dates.today())))!;
    expect(e.comment, 'à moitié écrit');
    expect(e.arrival, 480);
  });

  testWidgets('today has no balance before the departure', (tester) async {
    final h = await _start(tester, dir);
    await tester.runAsync(() => Repository.instance.saveTimeEntry(TimeEntry(date: Dates.today(), arrival: 480)));
    await tester.tap(find.text('Vacances').first);
    await h.settle();
    await tester.tap(find.text('Heures').first);
    await h.settle();
    expect(find.textContaining('-8h'), findsNothing);
  });

  group('section shortcuts', () {
    Future<void> combo(WidgetTester t, List<LogicalKeyboardKey> keys) async {
      for (final k in keys) {
        await t.sendKeyDownEvent(k);
      }
      for (final k in keys.reversed) {
        await t.sendKeyUpEvent(k);
      }
      await t.pump();
    }

    testWidgets('AltGr + digit (Windows: Ctrl + Alt) types a character', (tester) async {
      final h = await _start(tester, dir);
      await combo(tester, [LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.altRight, LogicalKeyboardKey.digit2]);
      await h.settle();
      expect(find.text('Solde total'), findsOneWidget, reason: 'still on Hours');
    });

    testWidgets('Ctrl + digit still changes section', (tester) async {
      final h = await _start(tester, dir);
      await combo(tester, [LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.digit2]);
      await h.settle();
      expect(find.text('Solde total'), findsNothing);
      expect(find.text('Poser des vacances'), findsOneWidget);
    });
  });
}

class _BrokenBackend extends MemorySyncBackend {
  @override
  Future<PullResult> pull(SyncSession session, String deviceId, String? cursor) async =>
      throw StateError('unexpected reply');

  @override
  Future<SyncSession> signIn(String email, String password) async =>
      const SyncSession(accountId: 'a', email: _mail, token: 't');
}
