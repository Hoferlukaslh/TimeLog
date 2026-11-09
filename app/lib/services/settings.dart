import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../utils/dates.dart';
import 'widget_sync.dart';

/// User preferences, persisted in the SQLite `settings` table.
class AppSettings extends ChangeNotifier {
  static const accentColors = <int>[
    0xFF1F6038, // logo green (default)
    0xFF1565C0, // blue
    0xFF00897B, // teal
    0xFF2E7D32, // green
    0xFF6A1B9A, // purple
    0xFFC62828, // red
    0xFFEF6C00, // orange
    0xFFAD1457, // pink
    0xFF4E342E, // brown
    0xFF37474F, // blue grey
    0xFF283593, // indigo
  ];

  ThemeMode themeMode = ThemeMode.system;
  int accentColor = accentColors.first;

  /// Language code, or null to follow the system language.
  String? languageCode;

  /// 1 = Monday ... 7 = Sunday.
  int firstWeekday = DateTime.monday;
  bool use24h = true;
  int dailyTargetMinutes = 8 * 60 + 24;
  Set<int> workDays = {1, 2, 3, 4, 5};
  DateTime trackingStart = Dates.today();

  /// Default number of vacation days per year (can be changed per year).
  double vacationDaysPerYear = 25;

  final _repo = Repository.instance;

  Locale? get locale => languageCode == null ? null : Locale(languageCode!);

  Future<void> load() async {
    final m = await _repo.loadSettings();
    themeMode = ThemeMode.values.firstWhere((e) => e.name == m['themeMode'], orElse: () => ThemeMode.system);
    accentColor = int.tryParse(m['accentColor'] ?? '') ?? accentColor;
    final lang = m['language'];
    languageCode = (lang == null || lang.isEmpty) ? null : lang;
    firstWeekday = int.tryParse(m['firstWeekday'] ?? '') ?? firstWeekday;
    use24h = (m['use24h'] ?? 'true') == 'true';
    dailyTargetMinutes = int.tryParse(m['dailyTargetMinutes'] ?? '') ?? dailyTargetMinutes;
    final wd = m['workDays'];
    if (wd != null) {
      workDays = wd.split(',').where((s) => s.isNotEmpty).map(int.parse).toSet();
    }
    vacationDaysPerYear = double.tryParse(m['vacationDaysPerYear'] ?? '') ?? vacationDaysPerYear;
    final ts = m['trackingStart'];
    if (ts != null && ts.isNotEmpty) {
      trackingStart = Dates.parseKey(ts);
    } else {
      // First launch: the balance starts today.
      // A default, not a choice: it must not replace the value of an account.
      await _repo.saveDefaultSetting('trackingStart', Dates.key(trackingStart));
    }
    notifyListeners();
  }

  Future<void> _set(String key, String value) async {
    await _repo.saveSetting(key, value);
    notifyListeners();
    // Language, time format and accent colour are also used by the home screen widget.
    if (const {'language', 'use24h', 'accentColor'}.contains(key)) await WidgetSync.refresh();
  }

  Future<void> setThemeMode(ThemeMode m) {
    themeMode = m;
    return _set('themeMode', m.name);
  }

  Future<void> setAccentColor(int c) {
    accentColor = c;
    return _set('accentColor', '$c');
  }

  Future<void> setLanguage(String? code) {
    languageCode = code;
    return _set('language', code ?? '');
  }

  Future<void> setFirstWeekday(int d) {
    firstWeekday = d;
    return _set('firstWeekday', '$d');
  }

  Future<void> setUse24h(bool v) {
    use24h = v;
    return _set('use24h', '$v');
  }

  Future<void> setDailyTarget(int minutes) {
    dailyTargetMinutes = minutes;
    return _set('dailyTargetMinutes', '$minutes');
  }

  Future<void> setWorkDays(Set<int> days) {
    workDays = days;
    final list = days.toList()..sort();
    return _set('workDays', list.join(','));
  }

  Future<void> setTrackingStart(DateTime d) {
    trackingStart = Dates.dateOnly(d);
    return _set('trackingStart', Dates.key(trackingStart));
  }

  Future<void> setVacationDaysPerYear(double d) {
    vacationDaysPerYear = d;
    return _set('vacationDaysPerYear', '$d');
  }

  /// Target minutes for a given day (0 if not a working day).
  int targetFor(DateTime day) => workDays.contains(day.weekday) ? dailyTargetMinutes : 0;
}
