import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timelog/data/database.dart';
import 'package:timelog/data/repository.dart';
import 'package:timelog/drawing/drawing.dart';
import 'package:timelog/models/models.dart';
import 'package:timelog/services/export_service.dart';
import 'package:timelog/services/hours_calculator.dart';
import 'package:timelog/services/settings.dart';
import 'package:timelog/services/vacation_service.dart';
import 'package:timelog/utils/dates.dart';

void main() {
  group('Period', () {
    test('week respects first weekday', () {
      final wed = DateTime(2026, 11, 4);
      final mon = Period.containing(PeriodType.week, wed, DateTime.monday);
      expect(mon.start, DateTime(2026, 11, 2));
      expect(mon.end, DateTime(2026, 11, 8));
      final sun = Period.containing(PeriodType.week, wed, DateTime.sunday);
      expect(sun.start, DateTime(2026, 11));
    });
    test('month shift', () {
      final p = Period.containing(PeriodType.month, DateTime(2026, 1, 31), 1).shift(1, 1);
      expect(p.start, DateTime(2026, 2));
      expect(p.end, DateTime(2026, 2, 28));
    });
  });

  group('TimeEntry', () {
    test('morning / afternoon / total', () {
      final e = TimeEntry(
        date: DateTime(2026, 1, 5),
        arrival: 8 * 60,
        lunchStart: 12 * 60,
        lunchEnd: 13 * 60,
        departure: 17 * 60 + 30,
      );
      expect(e.morningMinutes, 240);
      expect(e.afternoonMinutes, 270);
      expect(e.lunchMinutes, 60);
      expect(e.workedMinutes, 510);
    });
    test('without lunch break', () {
      final e = TimeEntry(date: DateTime(2026, 1, 5), arrival: 8 * 60, departure: 12 * 60);
      expect(e.workedMinutes, 240);
    });
  });

  group('HoursCalculator', () {
    test('positive and negative balance', () {
      final s = AppSettings()
        ..dailyTargetMinutes = 480
        ..trackingStart = DateTime(2026, 1, 5);
      final entries = [
        TimeEntry(date: DateTime(2026, 1, 5), arrival: 480, departure: 1020), // 9h -> +60
        TimeEntry(date: DateTime(2026, 1, 6), dayType: DayType.vacation), // 0
        TimeEntry(date: DateTime(2026, 1, 7), dayType: DayType.compensation), // -480
      ];
      // 8 Jan (Thu) missing -> -480, 10-11 Jan weekend -> 0
      final r = HoursCalculator.compute(DateTime(2026, 1, 5), DateTime(2026, 1, 11), entries, s);
      expect(r.balance, 60 + 0 - 480 - 480 - 480); // Fri 9 Jan missing too
      expect(r.daysWorked, 1);
    });
  });

  group('Partial absences', () {
    final s = AppSettings()
      ..dailyTargetMinutes = 480
      ..trackingStart = DateTime(2026);
    int balance(TimeEntry e) => HoursCalculator.compute(e.date, e.date, [e], s).balance;
    final mon = DateTime(2026, 1, 5);

    test('vacation morning + 4h afternoon = 0', () {
      expect(
        balance(
          TimeEntry(
            date: mon,
            dayType: DayType.vacation,
            absencePart: AbsencePart.morning,
            arrival: 13 * 60,
            departure: 17 * 60,
          ),
        ),
        0,
      );
    });
    test('sick afternoon, worked 3h morning = -1h', () {
      expect(
        balance(
          TimeEntry(
            date: mon,
            dayType: DayType.sick,
            absencePart: AbsencePart.afternoon,
            arrival: 8 * 60,
            departure: 11 * 60,
          ),
        ),
        -60,
      );
    });
    test('sick custom 6h + 2h worked = 0', () {
      expect(
        balance(
          TimeEntry(
            date: mon,
            dayType: DayType.sick,
            absencePart: AbsencePart.custom,
            absenceMinutes: 360,
            arrival: 8 * 60,
            departure: 10 * 60,
          ),
        ),
        0,
      );
    });
    test('half-day compensation consumes balance', () {
      expect(
        balance(
          TimeEntry(
            date: mon,
            dayType: DayType.compensation,
            absencePart: AbsencePart.morning,
            arrival: 13 * 60,
            departure: 17 * 60,
          ),
        ),
        -240,
      );
    });
    test('whole day sick ignores stale times', () {
      expect(balance(TimeEntry(date: mon, dayType: DayType.sick, arrival: 8 * 60, departure: 9 * 60)), 0);
    });
  });

  test('upgrade from database v1', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('timelog');
    final path = '${dir.path}/old.db';
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            "CREATE TABLE time_entries (id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL UNIQUE, day_type TEXT NOT NULL DEFAULT 'work', arrival INTEGER, lunch_start INTEGER, lunch_end INTEGER, departure INTEGER, comment TEXT)",
          );
          await db.insert('time_entries', {'date': '2026-01-05', 'day_type': 'vacation'});
        },
      ),
    );
    await old.close();
    await AppDatabase.instance.close();
    await AppDatabase.instance.open(overridePath: path);
    final e = await Repository.instance.timeEntry(DateTime(2026, 1, 5));
    expect(e!.dayType, DayType.vacation);
    expect(e.absencePart, AbsencePart.full);
    expect(await Repository.instance.vacationYear(2026), isNull); // table exists
    await AppDatabase.instance.close();
    await dir.delete(recursive: true);
  });

  test('CSV escaping', () {
    final csv = ExportService.toCsv([
      {'a': 'x;y', 'b': 'he said "hi"', 'c': null},
    ]);
    expect(csv.split('\n')[1], '"x;y";"he said ""hi""";');
  });

  group('Database', () {
    setUp(() async {
      sqfliteFfiInit();
      await AppDatabase.instance.close();
      await AppDatabase.instance.open(overridePath: inMemoryDatabasePath);
    });

    test('vacation balance', () async {
      final repo = Repository.instance;
      final s = AppSettings()..vacationDaysPerYear = 25;
      final y = DateTime.now().year;
      // Two full days and a half day in the past (previous year), one future day this year.
      final entries = [
        TimeEntry(date: DateTime(y - 1, 3, 2), dayType: DayType.vacation),
        TimeEntry(date: DateTime(y - 1, 3, 3), dayType: DayType.vacation),
        TimeEntry(date: DateTime(y - 1, 3, 4), dayType: DayType.vacation, absencePart: AbsencePart.morning),
      ];
      for (final e in entries) {
        await repo.saveTimeEntry(e);
      }
      final svc = VacationService();
      final prev = await svc.summary(y - 1, s);
      final expected = entries.fold(0.0, (a, e) => a + VacationService.daysOf(e, s));
      expect(prev.taken, expected);
      expect(prev.planned, 0);
      expect(prev.remaining, 25 - expected);

      await svc.save(y, 20, prev.remaining);
      final next = Dates.addDays(Dates.today(), 1);
      if (next.year == y && s.targetFor(next) > 0) {
        await repo.saveTimeEntry(TimeEntry(date: next, dayType: DayType.vacation));
      }
      final cur = await svc.summary(y, s);
      expect(cur.entitlement, 20);
      expect(cur.carryOver, 25 - expected);
      expect(cur.remaining, cur.total - cur.taken - cur.planned);
    });

    test('removing a vacation period clears every day at once', () async {
      final repo = Repository.instance;
      final svc = VacationService();
      final s = AppSettings()..vacationDaysPerYear = 25;
      const y = 2026;
      // Period of 3 days (Mon–Wed 5–7 Jan), a half day with a time already entered, a day outside.
      await repo.saveTimeEntry(TimeEntry(date: DateTime(y, 1, 5), dayType: DayType.vacation));
      await repo.saveTimeEntry(TimeEntry(date: DateTime(y, 1, 6), dayType: DayType.vacation));
      await repo.saveTimeEntry(
        TimeEntry(
          date: DateTime(y, 1, 7),
          dayType: DayType.vacation,
          absencePart: AbsencePart.morning,
          arrival: 13 * 60,
          departure: 17 * 60,
        ),
      );
      await repo.saveTimeEntry(TimeEntry(date: DateTime(y, 1, 12), dayType: DayType.vacation));

      var sum = await svc.summary(y, s);
      expect(sum.entries.length, 4);
      final period = VacationService.entriesBetween(sum.entries, DateTime(y, 1, 5), DateTime(y, 1, 7));
      expect(period.length, 3);

      expect(await svc.removeVacations(period), 3);

      sum = await svc.summary(y, s);
      expect(sum.entries.map((e) => e.date.day), [12]); // day outside the period untouched
      expect(await repo.timeEntry(DateTime(y, 1, 5)), isNull); // empty day removed
      final half = await repo.timeEntry(DateTime(y, 1, 7));
      expect(half!.dayType, DayType.work); // times kept, absence gone
      expect(half.arrival, 13 * 60);
      expect(half.departure, 17 * 60);
      expect(half.absencePart, AbsencePart.full);
    });

    test('withoutAbsence keeps comments and returns null for an empty day', () {
      final d = DateTime(2026, 1, 5);
      expect(VacationService.withoutAbsence(TimeEntry(date: d, dayType: DayType.vacation)), isNull);
      final kept = VacationService.withoutAbsence(
        TimeEntry(
          date: d,
          dayType: DayType.vacation,
          comment: 'Voyage',
          absenceMinutes: 120,
          absencePart: AbsencePart.custom,
        ),
      );
      expect(kept!.dayType, DayType.work);
      expect(kept.comment, 'Voyage');
      expect(kept.absenceMinutes, isNull);
    });

    test('vacation days of an entry', () {
      final s = AppSettings()..dailyTargetMinutes = 480;
      final mon = DateTime(2026, 1, 5), sat = DateTime(2026, 1, 10);
      expect(VacationService.daysOf(TimeEntry(date: mon, dayType: DayType.vacation), s), 1);
      expect(VacationService.daysOf(TimeEntry(date: sat, dayType: DayType.vacation), s), 0);
      expect(
        VacationService.daysOf(TimeEntry(date: mon, dayType: DayType.vacation, absencePart: AbsencePart.afternoon), s),
        0.5,
      );
      expect(
        VacationService.daysOf(
          TimeEntry(date: mon, dayType: DayType.vacation, absencePart: AbsencePart.custom, absenceMinutes: 120),
          s,
        ),
        0.25,
      );
      expect(VacationService.daysOf(TimeEntry(date: mon, dayType: DayType.sick), s), 0);
      expect(VacationService.fmt(12.5), '12.5');
      expect(VacationService.fmt(0.25), '0.25');
      expect(VacationService.fmt(3), '3');
    });

    test('attachments are chunked and restored', () async {
      final repo = Repository.instance;
      final now = DateTime.now();
      final noteId = await repo.saveNote(Note(date: Dates.today(), title: 'Facture', createdAt: now, updatedAt: now));
      final data = Uint8List.fromList(List.generate(1300000, (i) => i % 251));
      final aid = await repo.addAttachment(
        noteId: noteId,
        kind: AttachmentKind.document,
        fileName: 'scan.pdf',
        data: data,
      );
      expect(await repo.attachmentData(aid), data);

      expect((await repo.searchNotes('scan')).length, 1);
      expect((await repo.searchNotes('factu')).length, 1);
      expect((await repo.searchNotes('zzz')).length, 0);

      final svc = ExportService();
      final (_, json, _) = await svc.export(ExportFormat.json, ExportDataset.values.toSet());
      await repo.deleteNote(noteId);
      expect((await repo.searchNotes('')).length, 0);
      await svc.restoreJson(json);
      final notes = await repo.searchNotes('');
      expect(notes.single.attachments.single.fileName, 'scan.pdf');
      expect(await repo.attachmentData(notes.single.attachments.single.id!), data);

      // Vector drawing: stored as JSON, exported as PNG.
      final drawing = Drawing(
        width: 100,
        height: 80,
        elements: [
          DrawElement(type: ElementType.circle, color: 0xFF000000, data: [50, 40, 20]),
        ],
      );
      await repo.addAttachment(
        noteId: notes.single.id!,
        kind: AttachmentKind.drawing,
        fileName: 'dessin_1',
        mime: kDrawingMime,
        data: drawing.encode(),
      );
      final (name, zip, _) = await svc.export(ExportFormat.csv, ExportDataset.values.toSet());
      expect(name.endsWith('.zip'), true);
      final files = ZipDecoder().decodeBytes(zip).files;
      final png = files.firstWhere((f) => f.name.endsWith('dessin_1.png'));
      expect(png.content.sublist(1, 4), [0x50, 0x4E, 0x47]);
      final (_, json2, _) = await svc.export(ExportFormat.json, ExportDataset.values.toSet());
      final decoded = jsonDecode(utf8.decode(json2)) as Map;
      expect((decoded['drawing_images_png'] as Map).length, 1);
      await svc.restoreJson(json2);
      final restored = (await repo.searchNotes('dessin_1')).single.attachments.firstWhere((a) => a.isVectorDrawing);
      expect(Drawing.decode(await repo.attachmentData(restored.id!)).elements.single.type, ElementType.circle);
    });
  });
}
