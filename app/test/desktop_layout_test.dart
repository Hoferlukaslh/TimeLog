import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timelog/data/database.dart';
import 'package:timelog/main.dart';
import 'package:timelog/services/categories_store.dart';
import 'package:timelog/services/settings.dart';
import 'package:timelog/sync/http_sync_backend.dart';
import 'package:timelog/sync/sync_controller.dart';
import 'package:timelog/widgets/responsive.dart';

/// Starts the app on an empty database, in a window of [size] (logical pixels).
Future<Future<void> Function()> _start(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late AppSettings settings;
  late CategoriesStore cats;
  late SyncController sync;
  await tester.runAsync(() async {
    sqfliteFfiInit();
    await AppDatabase.instance.close();
    await AppDatabase.instance.open(overridePath: inMemoryDatabasePath);
    settings = AppSettings();
    await settings.load();
    await settings.setLanguage('fr');
    cats = CategoriesStore();
    await cats.load();
    sync = SyncController(AppDatabase.instance.db);
  });
  addTearDown(() => tester.runAsync(AppDatabase.instance.close));
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
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  await settle();
  return settle;
}

void main() {
  testWidgets('computer: permanent menu, every section without layout error', (tester) async {
    final settle = await _start(tester, const Size(1400, 900));
    expect(find.byIcon(Icons.menu), findsNothing, reason: 'no drawer button next to the sidebar');
    for (final s in [
      'Vacances',
      'Journal de travail',
      'Notes',
      'Catégories',
      'Export / sauvegarde',
      'Synchronisation',
      'Paramètres',
      'Heures',
    ]) {
      await tester.tap(find.text(s).first);
      await settle();
      expect(tester.takeException(), isNull, reason: s);
      expect(find.byIcon(Icons.menu), findsNothing, reason: s);
    }
    for (final p in ['Semaine', 'Mois', 'Année', 'Jour']) {
      await tester.tap(find.text(p).first);
      await settle();
      expect(tester.takeException(), isNull, reason: p);
    }
  });

  testWidgets('computer: the journal form keeps its text when the window shrinks', (tester) async {
    final settle = await _start(tester, const Size(1400, 900));
    await tester.tap(find.text('Journal de travail').first);
    await settle();
    await tester.tap(find.text('Ajout'));
    await settle();
    await tester.enterText(find.byType(TextField).first, 'En cours');
    await settle();
    tester.view.physicalSize = const Size(700, 900);
    await settle();
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.text('En cours'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('telephone: drawer, also in landscape where the screen is wide', (tester) async {
    await _start(tester, const Size(915, 412));
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.byType(VerticalDivider), findsNothing);
  });

  testWidgets('telephone: content is not centered in a narrow column', (tester) async {
    await _start(tester, const Size(915, 412));
    final context = tester.element(find.byType(Scaffold).first);
    expect(Responsive.showsSidebar(context), isFalse);
    expect(Responsive.twoColumns(context, 915), isFalse);
  });

  test('server address: the address of a web page gives the same API', () {
    expect(HttpSyncBackend.normalizeUrl('https://timelog.example.ch').toString(), 'https://timelog.example.ch/api/v1/');
    expect(HttpSyncBackend.normalizeUrl('http://192.168.1.10:8787/').toString(), 'http://192.168.1.10:8787/api/v1/');
  });
}
