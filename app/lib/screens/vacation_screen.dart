import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/settings.dart';
import '../services/vacation_service.dart';
import '../sync/reload_on_remote_changes.dart';
import '../utils/dates.dart';
import '../utils/ui.dart';
import '../widgets/absence_range_dialog.dart';
import '../widgets/common.dart';
import '../widgets/day_editor.dart';
import '../widgets/responsive.dart';

/// Vacation balance: entitlement per year, carry-over, taken, planned, remaining.
class VacationScreen extends StatefulWidget {
  final Widget? drawer;
  const VacationScreen({super.key, this.drawer});

  @override
  State<VacationScreen> createState() => _VacationScreenState();
}

class _VacationScreenState extends State<VacationScreen> with ReloadOnRemoteChanges {
  final _service = VacationService();
  int _year = DateTime.now().year;
  VacationSummary? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Future<void> reloadRemoteChanges() => _load();

  Future<void> _load() async {
    if (!mounted) return;
    final s = await _service.summary(_year, context.read<AppSettings>());
    if (mounted) setState(() => _summary = s);
  }

  Future<void> _editEntitlement() async {
    final sum = _summary!;
    final v = await showDaysDialog(context, title: context.l.vacationEntitlement, initial: sum.entitlement);
    if (v == null) return;
    await _service.save(_year, v, sum.carryOver);
    await _load();
  }

  Future<void> _editCarryOver() async {
    final l = context.l;
    final sum = _summary!;
    final prev = await _service.summary(_year - 1, context.read<AppSettings>());
    if (!mounted) return;
    final v = await showDaysDialog(
      context,
      title: l.vacationCarryOver,
      initial: sum.carryOver,
      allowNegative: true,
      suggestion: (l.vacationUsePrevious(_year - 1, VacationService.fmt(prev.remaining)), prev.remaining),
    );
    if (v == null) return;
    await _service.save(_year, sum.entitlement, v);
    await _load();
  }

  Future<void> _book() async {
    final n = await showAbsenceRangeDialog(context);
    if (n != null && mounted) {
      context.toast(context.l.absenceApplied(n));
      await _load();
    }
  }

  Future<void> _openDay(DateTime d) async {
    await openDayEditor(context, d);
    await _load();
  }

  /// Removes the vacation of a whole period (all its days) after confirmation.
  Future<void> _deletePeriod(List<TimeEntry> period, VacationSummary sum) async {
    final l = context.l;
    final days = VacationService.entriesBetween(sum.entries, period.first.date, period.last.date);
    final ok = await Pickers.confirm(
      context,
      title: l.vacationDeletePeriod,
      message: l.vacationDeletePeriodMessage(
        context.fmtDateShort(period.first.date),
        context.fmtDateShort(period.last.date),
      ),
    );
    if (!ok || !mounted) return;
    final n = await _service.removeVacations(days);
    if (mounted) context.toast(l.vacationPeriodDeleted(n));
    await _load();
  }

  /// Groups consecutive vacation days (non-working days in between are ignored).
  List<List<TimeEntry>> _periods(VacationSummary sum, AppSettings s) {
    final out = <List<TimeEntry>>[];
    for (final e in sum.entries) {
      if (VacationService.daysOf(e, s) == 0) continue;
      if (out.isNotEmpty) {
        final last = out.last.last.date;
        var d = Dates.addDays(last, 1);
        while (d.isBefore(e.date) && s.targetFor(d) == 0) {
          d = Dates.addDays(d, 1);
        }
        if (Dates.sameDay(d, e.date) &&
            out.last.last.absencePart == AbsencePart.full &&
            e.absencePart == AbsencePart.full) {
          out.last.add(e);
          continue;
        }
      }
      out.add([e]);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final s = context.watch<AppSettings>();
    final sum = _summary;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    const f = VacationService.fmt;
    return Scaffold(
      drawer: widget.drawer,
      appBar: AppBar(title: Text(l.menuVacation)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _book,
        icon: const Icon(Icons.beach_access),
        label: Text(l.bookVacation),
      ),
      body: sum == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CenteredListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () {
                          _year--;
                          _load();
                        },
                      ),
                      Expanded(
                        child: Text('$_year', textAlign: TextAlign.center, style: t.titleLarge),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          _year++;
                          _load();
                        },
                      ),
                    ],
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(l.vacationRemaining, style: t.titleSmall),
                          const SizedBox(height: 4),
                          Text(
                            l.daysCount(f(sum.remaining)),
                            style: t.displaySmall?.copyWith(
                              color: sum.remaining < 0 ? cs.error : cs.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              minHeight: 12,
                              value: sum.total <= 0 ? 0 : ((sum.taken + sum.planned) / sum.total).clamp(0, 1),
                            ),
                          ),
                          if (sum.remaining < 0) ...[
                            const SizedBox(height: 8),
                            Text(l.vacationExceeded, style: TextStyle(color: cs.error)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.card_giftcard),
                          title: Text(l.vacationEntitlement),
                          subtitle: sum.configured ? null : Text(l.vacationDefaultHint),
                          trailing: Text(l.daysCount(f(sum.entitlement)), style: t.titleMedium),
                          onTap: _editEntitlement,
                        ),
                        ListTile(
                          leading: const Icon(Icons.redo),
                          title: Text(l.vacationCarryOver),
                          trailing: Text(l.daysCount(f(sum.carryOver)), style: t.titleMedium),
                          onTap: _editCarryOver,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.check_circle_outline),
                          title: Text(l.vacationTaken),
                          trailing: Text(l.daysCount(f(sum.taken)), style: t.titleMedium),
                        ),
                        ListTile(
                          leading: const Icon(Icons.event_outlined),
                          title: Text(l.vacationPlanned),
                          trailing: Text(l.daysCount(f(sum.planned)), style: t.titleMedium),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                    child: Text(l.vacationList, style: t.titleMedium),
                  ),
                  if (sum.entries.isEmpty) EmptyState(icon: Icons.beach_access, text: l.nothingHere),
                  for (final p in _periods(sum, s))
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(p.first.date.isAfter(Dates.today()) ? Icons.event : Icons.check),
                        ),
                        title: Text(
                          p.length == 1
                              ? context.fmtDateShort(p.first.date)
                              : '${context.fmtDateShort(p.first.date)} – ${context.fmtDateShort(p.last.date)}',
                        ),
                        subtitle: p.length == 1 && p.first.absencePart != AbsencePart.full
                            ? Text(
                                absencePartLabel(context, p.first.absencePart, customMinutes: p.first.absenceMinutes),
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l.daysCount(f(p.fold(0.0, (a, e) => a + VacationService.daysOf(e, s)))),
                              style: t.titleSmall,
                            ),
                            IconButton(
                              tooltip: l.vacationDeletePeriod,
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _deletePeriod(p, sum),
                            ),
                          ],
                        ),
                        onTap: () => _openDay(p.first.date),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

/// Dialog to enter a number of days with −/+ buttons (steps of ½ day).
Future<double?> showDaysDialog(
  BuildContext context, {
  required String title,
  required double initial,
  bool allowNegative = false,
  (String, double)? suggestion,
}) {
  var value = initial;
  final l = context.l;
  return showDialog<double>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  icon: const Icon(Icons.remove),
                  onPressed: !allowNegative && value <= 0 ? null : () => setState(() => value -= 0.5),
                ),
                SizedBox(
                  width: 110,
                  child: Text(
                    l.daysCount(VacationService.fmt(value)),
                    textAlign: TextAlign.center,
                    style: Theme.of(ctx).textTheme.headlineSmall,
                  ),
                ),
                IconButton.filledTonal(icon: const Icon(Icons.add), onPressed: () => setState(() => value += 0.5)),
              ],
            ),
            if (suggestion != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                icon: const Icon(Icons.auto_fix_high),
                label: Text(suggestion.$1, textAlign: TextAlign.center),
                onPressed: () => setState(() => value = suggestion.$2),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, value), child: Text(l.save)),
        ],
      ),
    ),
  );
}
