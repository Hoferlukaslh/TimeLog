import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/gen/app_localizations.dart';
import '../services/settings.dart';
import '../services/vacation_service.dart';
import '../utils/dates.dart';
import '../utils/ui.dart';
import '../widgets/responsive.dart';
import 'categories_screen.dart';
import 'export_screen.dart';
import 'sync_screen.dart';
import 'vacation_screen.dart';

class SettingsScreen extends StatelessWidget {
  final Widget? drawer;
  const SettingsScreen({super.key, this.drawer});

  /// Localized weekday name (1 = Monday). [short]: abbreviation of the language
  /// ("lun.", "Mo.", "Mon") instead of cutting the name.
  String _weekdayName(BuildContext context, int weekday, {bool short = false}) {
    // 2024-01-01 is a Monday.
    final d = DateTime(2024, 1, weekday);
    final s = (short ? DateFormat.E(context.localeName) : DateFormat.EEEE(context.localeName)).format(d);
    return s[0].toUpperCase() + s.substring(1);
  }

  Future<T?> _choose<T>(BuildContext context, String title, List<(T, String)> options, T current) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(title),
        children: [
          RadioGroup<T>(
            groupValue: current,
            onChanged: (v) => Navigator.pop(ctx, v),
            child: Column(
              children: [for (final o in options) RadioListTile<T>(value: o.$1, title: Text(o.$2))],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final s = context.watch<AppSettings>();
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(text, style: t.titleSmall?.copyWith(color: cs.primary)),
    );

    final themeLabels = {ThemeMode.system: l.themeSystem, ThemeMode.light: l.themeLight, ThemeMode.dark: l.themeDark};

    // Languages come from the ARB files: adding lib/l10n/app_xx.arb adds a language.
    final languages = <(String?, String)>[
      (null, l.languageSystem),
      for (final loc in AppLocalizations.supportedLocales) (loc.languageCode, lookupAppLocalizations(loc).languageName),
    ];
    final currentLang = languages.firstWhere((e) => e.$1 == s.languageCode, orElse: () => languages.first);

    return Scaffold(
      drawer: drawer,
      appBar: AppBar(title: Text(l.menuSettings)),
      body: CenteredListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          header(l.sectionAppearance),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(l.theme),
            subtitle: Text(themeLabels[s.themeMode]!),
            onTap: () async {
              final v = await _choose(context, l.theme, [
                for (final m in ThemeMode.values) (m, themeLabels[m]!),
              ], s.themeMode);
              if (v != null) await s.setThemeMode(v);
            },
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(l.accentColor),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ColorChoice(value: s.accentColor, onChanged: s.setAccentColor),
            ),
          ),
          header(l.sectionGeneral),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l.language),
            subtitle: Text(currentLang.$2),
            onTap: () async {
              // Use a sentinel because null means "system".
              final v = await _choose<String>(context, l.language, [
                for (final e in languages) (e.$1 ?? '', e.$2),
              ], s.languageCode ?? '');
              if (v != null) await s.setLanguage(v.isEmpty ? null : v);
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_view_week),
            title: Text(l.firstDayOfWeek),
            subtitle: Text(_weekdayName(context, s.firstWeekday)),
            onTap: () async {
              final v = await _choose(context, l.firstDayOfWeek, [
                for (var d = 1; d <= 7; d++) (d, _weekdayName(context, d)),
              ], s.firstWeekday);
              if (v != null) await s.setFirstWeekday(v);
            },
          ),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: Text(l.timeFormat),
            subtitle: Text(s.use24h ? l.format24h : l.format12h),
            onTap: () async {
              final v = await _choose(context, l.timeFormat, [(true, l.format24h), (false, l.format12h)], s.use24h);
              if (v != null) await s.setUse24h(v);
            },
          ),
          header(l.sectionHours),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text(l.dailyTarget),
            subtitle: Text(Fmt.duration(s.dailyTargetMinutes)),
            onTap: () async {
              final m = await Pickers.duration(context, s.dailyTargetMinutes, help: l.dailyTarget);
              if (m != null) await s.setDailyTarget(m);
            },
          ),
          ListTile(
            leading: const Icon(Icons.date_range),
            title: Text(l.workDays),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < 7; i++)
                    Builder(
                      builder: (context) {
                        final d = (s.firstWeekday - 1 + i) % 7 + 1;
                        return FilterChip(
                          label: Text(_weekdayName(context, d, short: true)),
                          selected: s.workDays.contains(d),
                          onSelected: (v) {
                            final n = {...s.workDays};
                            v ? n.add(d) : n.remove(d);
                            s.setWorkDays(n);
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.beach_access),
            title: Text(l.vacationDaysPerYear),
            subtitle: Text(l.daysCount(VacationService.fmt(s.vacationDaysPerYear))),
            onTap: () async {
              final v = await showDaysDialog(context, title: l.vacationDaysPerYear, initial: s.vacationDaysPerYear);
              if (v != null) await s.setVacationDaysPerYear(v);
            },
          ),
          ListTile(
            leading: const Icon(Icons.start),
            title: Text(l.trackingStart),
            subtitle: Text(context.fmtDateLong(s.trackingStart)),
            onTap: () async {
              final d = await Pickers.date(context, s.trackingStart);
              if (d != null) await s.setTrackingStart(Dates.dateOnly(d));
            },
          ),
          header(l.sectionData),
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: Text(l.manageCategories),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => const CategoriesScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync_outlined),
            title: Text(l.menuSync),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => const SyncScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: Text(l.menuExport),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => const ExportScreen())),
          ),
        ],
      ),
    );
  }
}
