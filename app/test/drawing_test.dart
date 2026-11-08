import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timelog/drawing/drawing.dart';
import 'package:timelog/l10n/gen/app_localizations.dart';
import 'package:timelog/screens/drawing_screen.dart';

void main() {
  test('encode / decode round trip', () {
    final d = Drawing(
      width: 300,
      height: 200,
      elements: [
        DrawElement(type: ElementType.pen, color: 0xFF000000, data: [1, 2, 3.33, 4, 5, 2.5]),
        DrawElement(type: ElementType.arc, color: 0xFFFF0000, data: [0, 0, 100, 0, 50, -50]),
        DrawElement(
          type: ElementType.fill,
          color: 0xFF00FF00,
          mask: FillMask(2, 10, 10, [
            [3, 1, 5],
          ]),
        ),
      ],
    );
    final back = Drawing.decode(d.encode());
    expect(back.width, 300);
    expect(back.elements.length, 3);
    expect(back.elements[0].data, [1, 2, 3.3, 4, 5, 2.5]);
    expect(back.elements[1].type, ElementType.arc);
    expect(back.elements[2].mask!.rows, [
      [3, 1, 5],
    ]);
    expect(back.elements[2].mask!.contains(const Offset(1, 1.6)), true);
  });

  test('flood fill stays inside a closed box', () {
    const w = 20, h = 20;
    final px = Uint8List(w * h * 4)..fillRange(0, w * h * 4, 255); // white
    void black(int x, int y) => px.setRange((y * w + x) * 4, (y * w + x) * 4 + 3, [0, 0, 0]);
    for (var i = 5; i <= 14; i++) {
      black(i, 5);
      black(i, 14);
      black(5, i);
      black(14, i);
    }
    final rows = Drawing.floodFill(px, w, h, 10, 10);
    final count = rows.fold<int>(0, (s, r) {
      var c = 0;
      for (var i = 1; i < r.length; i += 2) {
        c += r[i + 1] - r[i];
      }
      return s + c;
    });
    // Inside is 8x8 = 64 pixels, grown by one pixel over the border: 10x10 - 4 corners.
    expect(count, 96);
    expect(rows.first[0], 5);
  });

  test('arc points go through the middle point', () {
    final e = DrawElement(type: ElementType.arc, color: 0, data: [0, 0, 100, 0, 50, -50]);
    final pts = arcPoints(e, 64);
    expect(pts.first.dx, closeTo(0, 0.01));
    expect(pts.last.dx, closeTo(100, 0.01));
    expect(pts.any((p) => (p - const Offset(50, -50)).distance < 3), true);
    expect(e.hits(const Offset(50, -50), 2), true);
    expect(e.hits(const Offset(50, 50), 2), false);
  });

  testWidgets('drawing editor: every tool, fill and PNG export', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    Drawing? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => result = await Navigator.push<Drawing>(
                  ctx,
                  MaterialPageRoute(builder: (_) => const DrawingScreen()),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    final origin = tester.getTopLeft(find.byKey(const ValueKey('drawing-canvas')));
    expect(tester.getSize(find.byKey(const ValueKey('drawing-canvas'))).height, greaterThan(520));

    Future<void> drag(Offset a, Offset b, {int steps = 10, Duration step = const Duration(milliseconds: 16)}) async {
      final g = await tester.startGesture(origin + a);
      for (var i = 1; i <= steps; i++) {
        await g.moveTo(origin + Offset.lerp(a, b, i / steps)!, timeStamp: step * i);
      }
      await g.up();
      await tester.pump();
    }

    Future<void> tool(String tooltip) async {
      await tester.tap(find.byTooltip(tooltip));
      await tester.pump();
    }

    // Pen: slow then fast stroke.
    await drag(const Offset(20, 20), const Offset(120, 20), step: const Duration(milliseconds: 60));
    await drag(const Offset(20, 40), const Offset(320, 40), steps: 6, step: const Duration(milliseconds: 4));
    await tool('Rectangle');
    await drag(const Offset(50, 100), const Offset(250, 300));
    await tool('Trait droit');
    await drag(const Offset(20, 330), const Offset(300, 332));
    await tool('Flèche');
    await drag(const Offset(20, 360), const Offset(200, 420));
    await tool('Cercle');
    await drag(const Offset(300, 450), const Offset(340, 450));
    await tool('Arc de cercle');
    await drag(const Offset(20, 500), const Offset(200, 500));
    expect(find.text("Faites glisser le point pour courber l'arc"), findsOneWidget);
    // Bend the arc with its handle (half circle above the chord: handle at (110, 410)).
    await drag(const Offset(110, 410), const Offset(110, 440));
    await tool('Gomme');
    await drag(const Offset(20, 380), const Offset(300, 380));
    await tool('Gomme à objets');
    await drag(const Offset(150, 331), const Offset(160, 331), steps: 2);
    await tool('Remplissage de zone');
    final g = await tester.startGesture(origin + const Offset(150, 200));
    await g.up();
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 2)));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Enregistrer'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    final types = result!.elements.map((e) => e.type).toList();
    // The straight line was removed by the object eraser.
    expect(types, [
      ElementType.pen,
      ElementType.pen,
      ElementType.rect,
      ElementType.arrow,
      ElementType.circle,
      ElementType.arc,
      ElementType.erase,
      ElementType.fill,
    ]);
    // Simulated pressure: the fast stroke is thinner than the slow one.
    double avg(DrawElement e) {
      final w = [for (var i = 2; i < e.data.length; i += 3) e.data[i]];
      return w.reduce((a, b) => a + b) / w.length;
    }

    expect(avg(result!.elements[1]), lessThan(avg(result!.elements[0])));
    // The arc was bent: the through-point moved down.
    expect(result!.elements[5].data[5], closeTo(440, 1));
    // The fill covers the inside of the rectangle only.
    final mask = result!.elements[7].mask!;
    expect(mask.contains(const Offset(150, 200)), true);
    expect(mask.contains(const Offset(20, 200)), false);

    final png = await tester.runAsync(() => Drawing.decode(result!.encode()).toPng());
    expect(png!.sublist(1, 4), [0x50, 0x4E, 0x47]); // "PNG"
  });

  testWidgets('saves only with ✓, back asks before discarding changes', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    Drawing? result;
    var popped = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  popped = false;
                  result = await Navigator.push<Drawing>(ctx, MaterialPageRoute(builder: (_) => const DrawingScreen()));
                  popped = true;
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    final editor = find.byKey(const ValueKey('drawing-canvas'));
    Future<void> open() async {
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    Future<void> scribble() async {
      final o = tester.getTopLeft(editor);
      final g = await tester.startGesture(o + const Offset(50, 50));
      await g.moveTo(o + const Offset(150, 80), timeStamp: const Duration(milliseconds: 30));
      await g.up();
      await tester.pump();
    }

    // No change: back leaves directly.
    await open();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(editor, findsNothing);
    expect(popped, true);
    expect(result, isNull);

    // Change + back: warning; "keep drawing" stays in the editor.
    await open();
    await scribble();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Quitter sans enregistrer ?'), findsOneWidget);
    await tester.tap(find.text('Continuer à dessiner'));
    await tester.pumpAndSettle();
    expect(editor, findsOneWidget);
    expect(popped, false);

    // Back again and confirm: nothing saved.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Quitter sans enregistrer'));
    await tester.pumpAndSettle();
    expect(editor, findsNothing);
    expect(popped, true);
    expect(result, isNull);

    // ✓ saves.
    await open();
    await scribble();
    await tester.tap(find.byTooltip('Enregistrer'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.elements.length, 1);
  });
}
