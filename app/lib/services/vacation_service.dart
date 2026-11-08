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

  /// Formats a number of days: "12", "12.5", "0.75".
  static String fmt(double d) {
    if (d == d.roundToDouble()) return d.toInt().toString();
    final s = d.toStringAsFixed(2);
    return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
  }
}
