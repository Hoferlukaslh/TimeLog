import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repository.dart';
import '../models/models.dart';
import '../services/settings.dart';
import '../utils/dates.dart';
import '../utils/ui.dart';
import 'common.dart';

/// Opens the editor of one day in a new page.
Future<void> openDayEditor(BuildContext context, DateTime day) {
  return Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (ctx) => Scaffold(
        appBar: AppBar(title: Text(ctx.fmtDateLong(day))),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: DayEditor(date: day),
        ),
      ),
    ),
  );
}

/// Editing of the four clock times of one day, day type and comment.
/// Changes are saved immediately.
class DayEditor extends StatefulWidget {
  final DateTime date;
  final VoidCallback? onChanged;

  const DayEditor({super.key, required this.date, this.onChanged});

  @override
  State<DayEditor> createState() => DayEditorState();
}

class DayEditorState extends State<DayEditor> {
  final _repo = Repository.instance;
  TimeEntry? _entry;
  bool _loaded = false;
  final _comment = TextEditingController();

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void didUpdateWidget(DayEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!Dates.sameDay(oldWidget.date, widget.date)) reload();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    final e = await _repo.timeEntry(widget.date);
    if (!mounted) return;
    setState(() {
      _entry = e;
      _loaded = true;
      _comment.text = e?.comment ?? '';
    });
  }

  TimeEntry get _current => _entry ?? TimeEntry(date: widget.date);

  Future<void> _save(TimeEntry e) async {
    final empty =
        e.arrival == null &&
        e.lunchStart == null &&
        e.lunchEnd == null &&
        e.departure == null &&
        e.comment.isEmpty &&
        e.dayType == DayType.work;
    if (empty) {
      await _repo.deleteTimeEntry(widget.date);
    } else {
      await _repo.saveTimeEntry(e);
    }
    await reload();
    widget.onChanged?.call();
  }

  Future<void> _pick(int index, String label) async {
    final e = _current;
    // Suggest the current time, or the previous time entered.
    var initial = e.timeAt(index);
    if (initial == null) {
      final prev = [for (var i = 0; i < index; i++) e.timeAt(i)].whereType<int>().toList();
      final now = DateTime.now();
      initial = Dates.sameDay(widget.date, now) ? now.hour * 60 + now.minute : (prev.isNotEmpty ? prev.last : 8 * 60);
    }
    final m = await Pickers.time(context, initial, help: label);
    if (m == null || !mounted) return;
    final n = e.withTime(index, m);
    if (!n.isChronological) {
      context.toast(context.l.timeOrderError);
      return;
    }
    await _save(n);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final l = context.l;
    final s = context.watch<AppSettings>();
    final e = _current;
    final t = Theme.of(context).textTheme;
    final labels = [l.arrival, l.lunchStart, l.lunchEnd, l.departure];
    final icons = [Icons.login, Icons.restaurant, Icons.work_history_outlined, Icons.logout];
    final values = [e.arrival, e.lunchStart, e.lunchEnd, e.departure];
    final target = s.targetFor(widget.date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<DayType>(
              initialValue: e.dayType,
              key: ValueKey('dt-${e.dayType}-${widget.date}'),
              isExpanded: true,
              decoration: InputDecoration(labelText: l.dayType),
              items: [
                for (final dt in DayType.values)
                  DropdownMenuItem(
                    value: dt,
                    child: Row(
                      children: [
                        Icon(dayTypeIcon(dt), size: 20),
                        const SizedBox(width: 8),
                        Flexible(child: Text(dayTypeLabel(context, dt), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v != null) _save(e.copyWith(dayType: v));
              },
            ),
          ),
        ),
        if (e.isAbsence) _absenceCard(e, target),
        if (!e.isFullAbsence)
          Card(
            child: Column(
              children: [
                if (e.isAbsence)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(l.partialAbsenceHint, style: t.bodySmall),
                  ),
                for (final i in e.clockSteps)
                  ListTile(
                    leading: Icon(icons[i]),
                    title: Text(labels[i]),
                    subtitle: values[i] == null ? Text(l.tapToSet) : null,
                    onTap: () => _pick(i, labels[i]),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(context.fmtTime(values[i]), style: t.titleLarge),
                        if (values[i] != null)
                          IconButton(
                            tooltip: l.clearTime,
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => _save(e.withTime(i, null)),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (!e.isFullAbsence) ...[
                  if (e.clockSteps.length == 4) ...[
                    _row(l.morning, Text(Fmt.duration(e.morningMinutes))),
                    _row(l.lunchBreak, Text(Fmt.duration(e.lunchMinutes))),
                    _row(l.afternoon, Text(Fmt.duration(e.afternoonMinutes))),
                  ],
                  _row(l.worked, Text(Fmt.duration(e.workedMinutes), style: t.titleMedium)),
                ],
                if (e.isAbsence)
                  _row(
                    '${dayTypeLabel(context, e.dayType)} (${absencePartLabel(context, e.absencePart, customMinutes: e.absenceMinutes, short: true)})',
                    Text(
                      e.dayType == DayType.compensation
                          ? '${Fmt.duration(e.absenceDuration(target))} · ${l.notCredited}'
                          : '+${Fmt.duration(e.creditedMinutes(target))}',
                    ),
                  ),
                if (e.isAbsence && !e.isFullAbsence) ...[
                  const Divider(),
                  _row(l.totalCounted, Text(Fmt.duration(e.effectiveMinutes(target)), style: t.titleMedium)),
                ],
                _row(l.target, Text(Fmt.duration(target))),
                if (_entry != null)
                  _row(l.balance, BalanceText(e.effectiveMinutes(target) - target, style: t.titleMedium)),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _comment,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: '${l.comment} (${l.optional})',
                prefixIcon: const Icon(Icons.comment_outlined),
              ),
              onEditingComplete: () => _save(e.copyWith(comment: _comment.text)),
              onTapOutside: (_) {
                FocusScope.of(context).unfocus();
                if (_comment.text != e.comment) _save(e.copyWith(comment: _comment.text));
              },
            ),
          ),
        ),
        if (_entry != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              icon: const Icon(Icons.delete_outline),
              label: Text(l.deleteDay),
              onPressed: () async {
                if (await Pickers.confirm(context)) {
                  await _repo.deleteTimeEntry(widget.date);
                  await reload();
                  widget.onChanged?.call();
                }
              },
            ),
          ),
      ],
    );
  }

  Future<void> _setPart(TimeEntry e, AbsencePart p, int target) async {
    var n = e.withAbsencePart(p);
    if (p == AbsencePart.custom) {
      final m = await Pickers.duration(context, e.absenceMinutes ?? target ~/ 2, help: context.l.absenceDuration);
      if (m == null) return;
      n = n.copyWith(absenceMinutes: () => m);
    }
    await _save(n);
  }

  Widget _absenceCard(TimeEntry e, int target) {
    final l = context.l;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.absencePart, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in AbsencePart.values)
                  ChoiceChip(
                    label: Text(absencePartLabel(context, p)),
                    selected: e.absencePart == p,
                    onSelected: (_) => _setPart(e, p, target),
                  ),
              ],
            ),
            if (e.absencePart == AbsencePart.custom)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.timer_outlined),
                title: Text(l.absenceDuration),
                trailing: Text(Fmt.duration(e.absenceMinutes ?? 0), style: Theme.of(context).textTheme.titleLarge),
                onTap: () => _setPart(e, AbsencePart.custom, target),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, Widget value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        value,
      ],
    ),
  );
}
