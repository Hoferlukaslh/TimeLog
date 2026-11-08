import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timelog/data/database.dart';
import 'package:timelog/main.dart';
import 'package:timelog/services/categories_store.dart';
import 'package:timelog/services/settings.dart';
import 'package:timelog/sync/sync_controller.dart';

void main() {
  testWidgets('navigates through every section', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    late AppSettings settings;
    late CategoriesStore cats;
    late SyncController sync;
    await tester.runAsync(() async {
      sqfliteFfiInit();
      await AppDatabase.instance.open(overridePath: inMemoryDatabasePath);
      settings = AppSettings()..languageCode = 'fr';
      await settings.load();
      await settings.setLanguage('fr');
      cats = CategoriesStore();
      await cats.load();
      sync = SyncController(AppDatabase.instance.db);
    });
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
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await settle();
    expect(find.text('Heures'), findsWidgets);
    for (final p in ['Semaine', 'Mois', 'Année', 'Jour']) {
      await tester.tap(find.text(p).first);
      await settle();
    }
    // Half-day vacation on today.
    await tester.tap(find.text('Travail'));
    await settle();
    await tester.tap(find.text('Vacances').last);
    await settle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Matin'));
    await settle();
    expect(find.text('Arrivée'), findsOneWidget);
    expect(find.text('Début pause midi'), findsNothing);
    expect(tester.takeException(), isNull);
    // Multi-day absence dialog.
    await tester.tap(find.byIcon(Icons.event_busy));
    await settle();
    expect(find.text('Absence sur plusieurs jours'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Annuler'));
    await settle();

    for (final s in [
      'Vacances',
      'Journal de travail',
      'Notes',
      'Catégories',
      'Export / sauvegarde',
      'Synchronisation',
      'Paramètres',
      'À propos',
      'Heures',
    ]) {
      await tester.tap(find.byTooltip('Ouvrir le menu de navigation'));
      await settle();
      if (s == 'À propos') {
        // Second part of the menu is pinned at the bottom.
        final screenH = tester.view.physicalSize.height / tester.view.devicePixelRatio;
        final about = find.descendant(of: find.byType(Drawer), matching: find.text(s));
        final notes = find.descendant(of: find.byType(Drawer), matching: find.text('Notes'));
        expect(tester.getCenter(about).dy, greaterThan(screenH - 100));
        expect(tester.getCenter(about).dy - tester.getCenter(notes).dy, greaterThan(300));
      }
      await tester.tap(find.descendant(of: find.byType(Drawer), matching: find.text(s)));
      await settle();
      expect(tester.takeException(), isNull, reason: s);
      if (s == 'À propos') {
        expect(find.text('Lukas Hofer'), findsOneWidget);
        expect(find.text('lukas.hofer.ju@gmail.com'), findsOneWidget);
        expect(find.text('https://github.com/Hoferlukaslh/TimeLog'), findsOneWidget);
        final screenH = tester.view.physicalSize.height / tester.view.devicePixelRatio;
        expect(tester.getCenter(find.text('Licences')).dy, greaterThan(screenH - 80));
      }
    }
    // Journal add mode
    await tester.tap(find.byTooltip('Ouvrir le menu de navigation'));
    await settle();
    await tester.tap(find.descendant(of: find.byType(Drawer), matching: find.text('Journal de travail')));
    await settle();
    await tester.tap(find.text('Ajout'));
    await settle();
    expect(tester.takeException(), isNull);
  });
}
