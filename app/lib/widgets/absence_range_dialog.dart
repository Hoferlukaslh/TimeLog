import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repository.dart';
import '../models/models.dart';
import '../services/settings.dart';
import '../services/vacation_service.dart';
import '../utils/dates.dart';
import '../utils/ui.dart';
import 'common.dart';

/// Dialog to set an absence (vacation, sickness, …) on several days at once.
/// Returns the number of days updated, or null if cancelled.
Future<int?> showAbsenceRangeDialog(BuildContext context, {DayType initialType = DayType.vacation}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _AbsenceRangeDialog(initialType: initialType),
  );
}

class _AbsenceRangeDialog extends StatefulWidget {
  final DayType initialType;
  const _AbsenceRangeDialog({required this.initialType});

  @override
  State<_AbsenceRangeDialog> createState() => _AbsenceRangeDialogState();
}

class _AbsenceRangeDialogState extends State<_AbsenceRangeDialog> {
  DateTimeRange? _range;
  late DayType _type = widget.initialType;
  AbsencePart _part = AbsencePart.full;
  bool _busy = false;

  /// Vacation balance of the year of the start date (for the preview).
  VacationSummary? _vacation;

  int get _workDays {
    final r = _range;
    if (r == null) return 0;
    final s = context.read<AppSettings>();
    var n = 0;
    for (var d = Dates.dateOnly(r.start); !d.isAfter(r.end); d = Dates.addDays(d, 1)) {
      if (s.targetFor(d) > 0) n++;
    }
    return n;
  }

  Future<void> _loadVacation() async {
    final r = _range;
    if (r == null) return;
    final v = await VacationService().summary(r.start.year, context.read<AppSettings>());
    if (mounted) setState(() => _vacation = v);
  }

  Future<void> _pickRange() async {
    final now = Dates.today();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _range ?? DateTimeRange(start: now, end: now),
    );
    if (r != null) {
      setState(() => _range = r);
      await _loadVacation();
    }
  }

  Future<void> _apply() async {
    final range = _range;
    if (range == null) return;
    setState(() => _busy = true);
    final s = context.read<AppSettings>();
    final repo = Repository.instance;
    var count = 0;
    for (var d = Dates.dateOnly(range.start); !d.isAfter(range.end); d = Dates.addDays(d, 1)) {
      if (s.targetFor(d) == 0) continue; // only working days
      final existing = await repo.timeEntry(d) ?? TimeEntry(date: d);
      await repo.saveTimeEntry(existing.copyWith(dayType: _type).withAbsencePart(_part));
      count++;
    }
    if (mounted) Navigator.pop(context, count);
  }

  Widget _preview() {
    final l = context.l;
    final cs = Theme.of(context).colorScheme;
    final days = _workDays * (_part == AbsencePart.full ? 1.0 : 0.5);
    final lines = <String>[l.workDaysInRange(_workDays)];
    Color? color;
    final v = _vacation;
    if (_type == DayType.vacation && v != null) {
      // Days of the range already booked as vacation are not counted twice.
      final already = v.entries
          .where((e) => _range!.start.isBefore(e.date.add(const Duration(days: 1))) && !e.date.isAfter(_range!.end))
          .fold(0.0, (a, e) => a + VacationService.daysOf(e, context.read<AppSettings>()));
      final after = v.remaining + already - days;
      lines.add(l.vacationPreview(VacationService.fmt(days), VacationService.fmt(after)));
      if (after < 0) color = cs.error;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (color ?? cs.primary).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(lines.join('\n'), style: TextStyle(color: color)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final parts = [AbsencePart.full, AbsencePart.morning, AbsencePart.afternoon];
    return AlertDialog(
      title: Text(l.addAbsence),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<DayType>(
              initialValue: _type,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.dayType),
              items: [
                for (final t in DayType.values.where((t) => t != DayType.work))
                  DropdownMenuItem(
                    value: t,
                    child: Row(
                      children: [
                        Icon(dayTypeIcon(t), size: 20),
                        const SizedBox(width: 8),
                        Flexible(child: Text(dayTypeLabel(context, t), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text(
                _range == null
                    ? l.absencePeriod
                    : '${context.fmtDateShort(_range!.start)} – ${context.fmtDateShort(_range!.end)}',
              ),
              onPressed: _pickRange,
            ),
            const SizedBox(height: 12),
            Text(l.absencePart, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                for (final p in parts)
                  ChoiceChip(
                    label: Text(absencePartLabel(context, p)),
                    selected: _part == p,
                    onSelected: (_) => setState(() => _part = p),
                  ),
              ],
            ),
            if (_range != null) ...[const SizedBox(height: 12), _preview()],
            const SizedBox(height: 12),
            Text(l.onlyWorkDaysInfo, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: _range == null || _busy ? null : _apply, child: Text(l.apply)),
      ],
    );
  }
}
