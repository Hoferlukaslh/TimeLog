import 'package:intl/intl.dart';

enum PeriodType { day, week, month, year }

/// A closed date range [start, end] (both are dates without time).
class Period {
  final PeriodType type;
  final DateTime start;
  final DateTime end;

  const Period(this.type, this.start, this.end);

  /// Builds the period of [type] containing [ref].
  /// [firstWeekday] uses DateTime convention (1 = Monday ... 7 = Sunday).
  factory Period.containing(PeriodType type, DateTime ref, int firstWeekday) {
    final d = Dates.dateOnly(ref);
    switch (type) {
      case PeriodType.day:
        return Period(type, d, d);
      case PeriodType.week:
        final diff = (d.weekday - firstWeekday + 7) % 7;
        final s = Dates.addDays(d, -diff);
        return Period(type, s, Dates.addDays(s, 6));
      case PeriodType.month:
        return Period(type, DateTime(d.year, d.month), DateTime(d.year, d.month + 1, 0));
      case PeriodType.year:
        return Period(type, DateTime(d.year), DateTime(d.year, 12, 31));
    }
  }

  Period shift(int delta, int firstWeekday) {
    switch (type) {
      case PeriodType.day:
        return Period.containing(type, Dates.addDays(start, delta), firstWeekday);
      case PeriodType.week:
        return Period.containing(type, Dates.addDays(start, 7 * delta), firstWeekday);
      case PeriodType.month:
        return Period.containing(type, DateTime(start.year, start.month + delta), firstWeekday);
      case PeriodType.year:
        return Period.containing(type, DateTime(start.year + delta), firstWeekday);
    }
  }

  bool contains(DateTime d) {
    final x = Dates.dateOnly(d);
    return !x.isBefore(start) && !x.isAfter(end);
  }

  Iterable<DateTime> get days sync* {
    for (var d = start; !d.isAfter(end); d = Dates.addDays(d, 1)) {
      yield d;
    }
  }
}

class Dates {
  static final _keyFormat = DateFormat('yyyy-MM-dd');

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime today() => dateOnly(DateTime.now());

  /// DST-safe day addition.
  static DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

  static String key(DateTime d) => _keyFormat.format(d);

  static DateTime parseKey(String s) => dateOnly(DateTime.parse(s));

  static bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// ISO-8601 week number.
  static int weekNumber(DateTime d) {
    final thursday = addDays(d, 4 - d.weekday);
    final firstJan = DateTime(thursday.year);
    return ((thursday.difference(firstJan).inHours / 24).round() ~/ 7) + 1;
  }
}

/// Formatting of times and durations according to user settings.
class Fmt {
  /// Formats minutes after midnight.
  static String time(int? minutes, bool use24h, String locale) {
    if (minutes == null) return '--:--';
    final dt = DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60);
    return use24h ? DateFormat.Hm(locale).format(dt) : DateFormat.jm(locale).format(dt);
  }

  /// Formats a duration in minutes as "7h 30" / "-0h 15".
  static String duration(int minutes, {bool signed = false}) {
    final neg = minutes < 0;
    final m = minutes.abs();
    final s = '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}';
    if (neg) return '-$s';
    return signed ? '+$s' : s;
  }

  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
