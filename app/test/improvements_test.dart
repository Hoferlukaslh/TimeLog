import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timelog/app_info.dart';
import 'package:timelog/data/database.dart';
import 'package:timelog/data/repository.dart';
import 'package:timelog/models/models.dart';
import 'package:timelog/services/export_service.dart';
import 'package:timelog/utils/dates.dart';
import 'package:timelog/widgets/attachment_views.dart';

void main() {
  test('app version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*([^+\s]+)', multiLine: true).firstMatch(pubspec)!.group(1);
    expect(AppInfo.appVersion, version);
  });

  group('TimeEntry clock rules', () {
    final day = DateTime(2026, 1, 5);
    test('steps of a normal day, a half day and a whole-day absence', () {
      expect(TimeEntry(date: day).clockSteps, [0, 1, 2, 3]);
      expect(TimeEntry(date: day, dayType: DayType.vacation, absencePart: AbsencePart.morning).clockSteps, [0, 3]);
      expect(TimeEntry(date: day, dayType: DayType.sick).clockSteps, isEmpty);
      expect(TimeEntry(date: day, dayType: DayType.sick, absencePart: AbsencePart.custom).clockSteps, [0, 1, 2, 3]);
    });
    test('next step and chronological order', () {
      var e = TimeEntry(date: day);
      for (final (i, t) in [(0, 480), (1, 720), (2, 780), (3, 1020)]) {
        expect(e.nextClockStep, i);
        e = e.withTime(i, t);
        expect(e.timeAt(i), t);
      }
      expect(e.nextClockStep, isNull);
      expect(e.isChronological, isTrue);
      expect(e.withTime(2, 700).isChronological, isFalse);
    });
    test('half day drops the lunch break', () {
      final e = TimeEntry(date: day, dayType: DayType.vacation, lunchStart: 720, lunchEnd: 780);
      final half = e.withAbsencePart(AbsencePart.afternoon);
      expect(half.lunchStart, isNull);
      expect(half.lunchEnd, isNull);
      expect(e.withAbsencePart(AbsencePart.custom).lunchStart, 720);
    });
  });

  group('Database', () {
    setUp(() async {
      sqfliteFfiInit();
      await AppDatabase.instance.close();
      await AppDatabase.instance.open(overridePath: inMemoryDatabasePath);
    });

    Future<int> note(String title) {
      final now = DateTime.now();
      return Repository.instance.saveNote(Note(date: Dates.today(), title: title, createdAt: now, updatedAt: now));
    }

    test('search treats % and _ literally', () async {
      await note('Rabais 50% sur les vis');
      await note('Rabais 500 sur les vis');
      await note('fichier_final');
      await note('fichierXfinal');
      final repo = Repository.instance;
      expect((await repo.searchNotes('50%')).map((n) => n.title), ['Rabais 50% sur les vis']);
      expect((await repo.searchNotes('r_f')).map((n) => n.title), ['fichier_final']);
      expect(await repo.searchNotes(r'\'), isEmpty);
    });

    test('restore ignores unknown tables and columns (no SQL injection)', () async {
      await note('à garder');
      final backup = utf8.encode(
        jsonEncode({
          'app': 'TimeLog',
          'tables': {
            'notes': [
              {
                'id': 1,
                'date': '2026-01-05',
                'title': 'restaurée',
                'content': '',
                'created_at': '2026-01-05T08:00:00',
                'updated_at': '2026-01-05T08:00:00',
                'x) VALUES (1); DROP TABLE notes; --': 1,
              },
            ],
            'sqlite_master': [
              {'name': 'x'},
            ],
          },
        }),
      );
      await ExportService().restoreJson(Uint8List.fromList(backup));
      final notes = await Repository.instance.searchNotes('');
      expect(notes.single.title, 'restaurée');
    });

    test('invalid backups give a FormatException and change nothing', () async {
      await note('intacte');
      for (final bad in ['pas du json', '{"app":"Autre"}', '{"app":"TimeLog","tables":{"notes":[1]}}']) {
        await expectLater(
          ExportService().restoreJson(Uint8List.fromList(utf8.encode(bad))),
          throwsA(isA<FormatException>()),
          reason: bad,
        );
      }
      expect((await Repository.instance.searchNotes('')).single.title, 'intacte');
    });

    test('attachment cache keeps memory under its budget', () async {
      final repo = Repository.instance;
      final id = await note('photos');
      final ids = [
        for (var i = 0; i < 4; i++)
          await repo.addAttachment(noteId: id, kind: AttachmentKind.photo, fileName: 'p$i.jpg', data: Uint8List(1000)),
      ];
      AttachmentCache.clear();
      final old = AttachmentCache.maxBytes;
      AttachmentCache.maxBytes = 2500;
      addTearDown(() => AttachmentCache.maxBytes = old);
      final first = AttachmentCache.get(ids[0]);
      await first;
      for (final a in ids.skip(1)) {
        await AttachmentCache.get(a);
      }
      // The oldest one was dropped: a new request reloads it (new future).
      expect(identical(AttachmentCache.get(ids[0]), first), isFalse);
      // The most recent ones are still cached.
      final last = AttachmentCache.get(ids[3]);
      expect(identical(AttachmentCache.get(ids[3]), last), isTrue);
    });
  });
}
