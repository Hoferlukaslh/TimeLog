import '../data/repository.dart';
import '../models/models.dart';
import '../utils/dates.dart';
import 'settings.dart';

/// Vacation balance of one year, in days (halves allowed).
class VacationSummary {
  final int year;
  final double entitlement;
  final double carryOver;

  /// Whether entitlement / carry-over were set for this year (otherwise defaults).
  final bool configured;
  final double taken;
  final double planned;
  final List<TimeEntry> entries;

  const VacationSummary({
    required this.year,
    required this.entitlement,
    required this.carryOver,
    required this.configured,
    required this.taken,
    required this.planned,
    required this.entries,
  });

  double get total => entitlement + carryOver;
  double get remaining => total - taken - planned;
}

class VacationService {
  final _repo = Repository.instance;

  /// Vacation days used by one entry: 1 for a whole day, 0.5 for a half day,
  /// proportional for a custom duration. Non-working days count 0.
  static double daysOf(TimeEntry e, AppSettings s) {
    final target = s.targetFor(e.date);
    if (e.dayType != DayType.vacation || target == 0) return 0;
    switch (e.absencePart) {
      case AbsencePart.full:
        return 1;
      case AbsencePart.morning:
      case AbsencePart.afternoon:
        return 0.5;
      case AbsencePart.custom:
        return ((e.absenceMinutes ?? 0) / target).clamp(0, 1).toDouble();
    }
  }

  Future<VacationSummary> summary(int year, AppSettings s) async {
    final cfg = await _repo.vacationYear(year);
    final entries = await _repo.vacationEntries(year);
    final today = Dates.today();
    var taken = 0.0, planned = 0.0;
    for (final e in entries) {
      final d = daysOf(e, s);
      if (e.date.isAfter(today)) {
        planned += d;
      } else {
        taken += d;
      }
    }
    return VacationSummary(
      year: year,
      entitlement: cfg?.$1 ?? s.vacationDaysPerYear,
      carryOver: cfg?.$2 ?? 0,
      configured: cfg != null,
      taken: taken,
      planned: planned,
      entries: entries,
    );
  }

  Future<void> save(int year, double entitlement, double carryOver) =>
      _repo.saveVacationYear(year, entitlement, carryOver);

  /// Entries of [entries] whose date is between [from] and [to] (both included).
  static List<TimeEntry> entriesBetween(List<TimeEntry> entries, DateTime from, DateTime to) => [
    for (final e in entries)
      if (!e.date.isBefore(Dates.dateOnly(from)) && !e.date.isAfter(Dates.dateOnly(to))) e,
  ];

  /// The entry [e] once its absence is removed: back to a working day, times and
  /// comment kept. Returns null when nothing is left, so the day can be deleted.
  static TimeEntry? withoutAbsence(TimeEntry e) {
    final cleared = e.copyWith(dayType: DayType.work, absencePart: AbsencePart.full, absenceMinutes: () => null);
    final empty =
        cleared.arrival == null &&
        cleared.lunchStart == null &&
        cleared.lunchEnd == null &&
        cleared.departure == null &&
        cleared.comment.isEmpty;
    return empty ? null : cleared;
  }

  /// Removes the vacation of [entries] (one period, several days at once).
  /// Only the absence is removed; clock times and comments are kept.
  /// Returns the number of days changed.
  Future<int> removeVacations(List<TimeEntry> entries) async {
    var n = 0;
    for (final e in entries) {
      if (e.dayType != DayType.vacation) continue;
      final cleared = withoutAbsence(e);
      if (cleared == null) {
        await _repo.deleteTimeEntry(e.date);
      } else {
        await _repo.saveTimeEntry(cleared);
      }
      n++;
    }
    return n;
  }

  /// Formats a number of days: "12", "12.5", "0.75".
  static String fmt(double d) {
    if (d == d.roundToDouble()) return d.toInt().toString();
    final s = d.toStringAsFixed(2);
    return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
  }
}
