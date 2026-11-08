import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/repository.dart';
import '../models/models.dart';
import '../services/hours_calculator.dart';
import '../services/settings.dart';
import '../services/vacation_service.dart';
import '../utils/dates.dart';
import '../utils/ui.dart';
import '../widgets/absence_range_dialog.dart';
import '../widgets/common.dart';
import '../widgets/day_editor.dart';
import '../widgets/responsive.dart';

class HoursScreen extends StatefulWidget {
  final Widget? drawer;
  const HoursScreen({super.key, this.drawer});

  @override
  State<HoursScreen> createState() => _HoursScreenState();
}

class _HoursScreenState extends State<HoursScreen> with WidgetsBindingObserver {
  final _repo = Repository.instance;
  late Period _period;

  /// Day considered as "today" (to detect the change of day while the app is open).
  DateTime _today = Dates.today();
  PeriodSummary? _summary;
  int _overall = 0;
  double? _vacationLeft;
  TimeEntry? _todayEntry;
  final _editorKey = GlobalKey<DayEditorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _period = Period.containing(PeriodType.day, Dates.today(), context.read<AppSettings>().firstWeekday);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back in the app: the home screen widget may have clocked in meanwhile.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // After midnight, follow the new day if the current period was showing "today".
    final today = Dates.today();
    if (!Dates.sameDay(today, _today)) {
      if (_period.contains(_today)) {
        _period = Period.containing(_period.type, today, context.read<AppSettings>().firstWeekday);
      }
      _today = today;
    }
    unawaited(_load());
    unawaited(_editorKey.currentState?.reload());
  }

  Future<void> _load() async {
    final s = context.read<AppSettings>();
    final entries = await _repo.timeEntries(_period.start, _period.end);
    final today = Dates.today();
    final all = await _repo.timeEntries(s.trackingStart, today);
    final overall = HoursCalculator.compute(s.trackingStart, today, all, s).balance;
    final todayEntry = await _repo.timeEntry(today);
    final vac = await VacationService().summary(today.year, s);
    if (!mounted) return;
    setState(() {
      _summary = HoursCalculator.compute(_period.start, _period.end, entries, s);
      _overall = overall;
      _vacationLeft = vac.remaining;
      _todayEntry = todayEntry;
    });
  }

  void _setPeriod(Period p) {
    setState(() => _period = p);
    _load();
  }

  /// "Clock in" button: fills the next missing time of today with a time
  /// picker preset to the current time.
  Future<void> _clockIn() async {
    final l = context.l;
    final today = Dates.today();
    var e = _todayEntry ?? TimeEntry(date: today);
    if (e.isFullAbsence) {
      context.toast(l.fullDayAbsence(dayTypeLabel(context, e.dayType)));
      return;
    }
    final step = e.nextClockStep;
    if (step == null) {
      context.toast(l.dayComplete);
      return;
    }
    final now = DateTime.now();
    final picked = await Pickers.time(context, now.hour * 60 + now.minute, help: clockStepLabel(context, step));
    if (picked == null || !mounted) return;
    e = e.withTime(step, picked);
    if (!e.isChronological) {
      context.toast(l.timeOrderError);
      return;
    }
    await _repo.saveTimeEntry(e);
    await _load();
    await _editorKey.currentState?.reload();
  }

  Future<void> _addAbsenceRange() async {
    final changed = await showAbsenceRangeDialog(context);
    if (changed != null && mounted) {
      context.toast(context.l.absenceApplied(changed));
      await _load();
      await _editorKey.currentState?.reload();
    }
  }

  String? _nextStepLabel() {
    final step = (_todayEntry ?? TimeEntry(date: Dates.today())).nextClockStep;
    return step == null ? null : clockStepLabel(context, step);
  }

  Future<void> _openDay(DateTime d) async {
    await openDayEditor(context, d);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final next = _nextStepLabel();
    return Scaffold(
      drawer: widget.drawer,
      appBar: AppBar(
        title: Text(l.menuHours),
        actions: [IconButton(tooltip: l.addAbsence, icon: const Icon(Icons.event_busy), onPressed: _addAbsenceRange)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _clockIn,
        icon: const Icon(Icons.touch_app),
        label: Text(next == null ? l.clockIn : '${l.clockIn} · $next'),
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final overview = [
            PeriodSelector(period: _period, onChanged: _setPeriod),
            if (_summary != null) _SummaryCard(summary: _summary!, overall: _overall, vacationLeft: _vacationLeft),
          ];
          final details = [
            if (_period.type == PeriodType.day)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DayEditor(key: _editorKey, date: _period.start, onChanged: _load),
              )
            else if (_period.type == PeriodType.year && _summary != null)
              ..._buildYear()
            else if (_summary != null)
              ..._buildDays(),
          ];
          if (!Responsive.twoColumns(context, c.maxWidth)) {
            return RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.only(bottom: 96), children: [...overview, ...details]),
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 400, child: ListView(children: overview)),
              const VerticalDivider(width: 1),
              Expanded(
                child: CenteredListView(padding: const EdgeInsets.only(top: 8, bottom: 96), children: details),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildDays() {
    final today = Dates.today();
    return [
      for (final d in _summary!.days)
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          color: Dates.sameDay(d.date, today) ? Theme.of(context).colorScheme.primaryContainer : null,
          child: ListTile(
            onTap: () => _openDay(d.date),
            leading: CircleAvatar(
              child: d.entry != null ? Icon(dayTypeIcon(d.entry!.dayType), size: 20) : Text('${d.date.day}'),
            ),
            title: Text(context.fmtDateShort(d.date)),
            subtitle: Text(_daySubtitle(d)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [Text(Fmt.duration(d.worked)), if (d.counted) BalanceText(d.balance)],
            ),
          ),
        ),
    ];
  }

  String _daySubtitle(DayResult d) {
    final e = d.entry;
    if (e == null) return d.target == 0 ? '—' : context.l.noEntry;
    if (e.isFullAbsence) return dayTypeLabel(context, e.dayType);
    if (e.isAbsence) {
      return '${dayTypeLabel(context, e.dayType)} · '
          '${context.fmtTime(e.arrival)} – ${context.fmtTime(e.departure)}';
    }
    final parts = <String>[
      '${context.fmtTime(e.arrival)} – ${context.fmtTime(e.lunchStart)}',
      if (e.lunchStart != null || e.lunchEnd != null)
        '${context.fmtTime(e.lunchEnd)} – ${context.fmtTime(e.departure)}',
    ];
    if (e.lunchStart == null && e.lunchEnd == null) {
      parts
        ..clear()
        ..add('${context.fmtTime(e.arrival)} – ${context.fmtTime(e.departure)}');
    }
    return parts.join('  ·  ');
  }

  List<Widget> _buildYear() {
    final loc = context.localeName;
    final s = _summary!;
    return [
      for (var m = 1; m <= 12; m++)
        Builder(
          builder: (context) {
            final days = s.days.where((d) => d.date.month == m).toList();
            final ps = PeriodSummary(days);
            final name = DateFormat.MMMM(loc).format(DateTime(_period.start.year, m));
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              child: ListTile(
                onTap: () => _setPeriod(
                  Period.containing(
                    PeriodType.month,
                    DateTime(_period.start.year, m),
                    context.read<AppSettings>().firstWeekday,
                  ),
                ),
                leading: CircleAvatar(child: Text('$m')),
                title: Text(name[0].toUpperCase() + name.substring(1)),
                subtitle: Text('${context.l.daysWorked}: ${ps.daysWorked}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [Text(Fmt.duration(ps.worked)), BalanceText(ps.balance)],
                ),
              ),
            );
          },
        ),
    ];
  }
}

class _SummaryCard extends StatelessWidget {
  final PeriodSummary summary;
  final int overall;
  final double? vacationLeft;
  const _SummaryCard({required this.summary, required this.overall, this.vacationLeft});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    Widget cell(String label, Widget value) => Expanded(
      child: Column(
        children: [
          Text(label, style: t.labelMedium, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          value,
        ],
      ),
    );
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                cell(l.worked, Text(Fmt.duration(summary.worked), style: t.titleMedium)),
                cell(l.target, Text(Fmt.duration(summary.target), style: t.titleMedium)),
                cell(l.balance, BalanceText(summary.balance, style: t.titleMedium)),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(child: Text(l.totalBalance, style: t.titleSmall)),
                BalanceText(overall, style: t.titleMedium),
              ],
            ),
            if (vacationLeft != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text(l.vacationRemaining, style: t.titleSmall)),
                  Text(l.daysCount(VacationService.fmt(vacationLeft!)), style: t.titleMedium),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
