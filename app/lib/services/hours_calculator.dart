import '../models/models.dart';
import '../utils/dates.dart';
import 'settings.dart';

class DayResult {
  final DateTime date;
  final TimeEntry? entry;
  final int worked;
  final int target;

  /// Whether this day counts in the balance.
  final bool counted;

  const DayResult(this.date, this.entry, this.worked, this.target, this.counted);

  int get balance => counted ? worked - target : 0;
}

class PeriodSummary {
  final List<DayResult> days;
  const PeriodSummary(this.days);

  int get worked => days.fold(0, (s, d) => s + (d.counted ? d.worked : 0));
  int get target => days.fold(0, (s, d) => s + (d.counted ? d.target : 0));
  int get balance => days.fold(0, (s, d) => s + d.balance);
  int get daysWorked =>
      days.where((d) => d.entry != null && !d.entry!.isFullAbsence && d.entry!.workedMinutes > 0).length;
  int get averagePerDay => daysWorked == 0
      ? 0
      : days.where((d) => d.entry != null && !d.entry!.isFullAbsence).fold(0, (s, d) => s + d.entry!.workedMinutes) ~/
            daysWorked;
}

/// Automatic computation of positive / negative hours.
///
/// Rules:
/// * Days before the "tracking start" setting or in the future are ignored.
/// * Past days count fully (a missing working day = negative balance).
/// * Today only counts once the departure (or an absence) has been entered.
/// * Vacation, sickness and public holidays are credited with the target time
///   (whole day), half of it (morning / afternoon) or a custom duration; any
///   clocked time on the same day is added.
/// * Overtime compensation is not credited (it consumes the balance).
class HoursCalculator {
  static PeriodSummary compute(DateTime from, DateTime to, List<TimeEntry> entries, AppSettings s) {
    final map = {for (final e in entries) Dates.key(e.date): e};
    final today = Dates.today();
    final result = <DayResult>[];
    for (var d = Dates.dateOnly(from); !d.isAfter(to); d = Dates.addDays(d, 1)) {
      final e = map[Dates.key(d)];
      final target = s.targetFor(d);
      var counted = !d.isBefore(s.trackingStart) && !d.isAfter(today);
      if (Dates.sameDay(d, today) && (e == null || (!e.isFullAbsence && e.departure == null))) {
        counted = false;
      }
      final worked = e?.effectiveMinutes(target) ?? 0;
      result.add(DayResult(d, e, worked, target, counted));
    }
    return PeriodSummary(result);
  }
}
