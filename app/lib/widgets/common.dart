import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/categories_store.dart';
import '../services/settings.dart';
import '../utils/dates.dart';
import '../utils/ui.dart';

/// Day / week / month / year selector with previous / next navigation.
class PeriodSelector extends StatelessWidget {
  final Period period;
  final ValueChanged<Period> onChanged;

  const PeriodSelector({super.key, required this.period, required this.onChanged});

  String _label(BuildContext context) {
    final loc = context.localeName;
    switch (period.type) {
      case PeriodType.day:
        return DateFormat.yMMMMEEEEd(loc).format(period.start);
      case PeriodType.week:
        final f = DateFormat.MMMd(loc);
        return '${context.l.weekNumber(Dates.weekNumber(period.start.add(const Duration(days: 3))))}'
            ' · ${f.format(period.start)} – ${f.format(period.end)}';
      case PeriodType.month:
        final s = DateFormat.yMMMM(loc).format(period.start);
        return s[0].toUpperCase() + s.substring(1);
      case PeriodType.year:
        return '${period.start.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fw = context.watch<AppSettings>().firstWeekday;
    final isCurrent = period.contains(Dates.today());
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<PeriodType>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: PeriodType.day, label: Text(l.periodDay)),
                ButtonSegment(value: PeriodType.week, label: Text(l.periodWeek)),
                ButtonSegment(value: PeriodType.month, label: Text(l.periodMonth)),
                ButtonSegment(value: PeriodType.year, label: Text(l.periodYear)),
              ],
              selected: {period.type},
              onSelectionChanged: (s) {
                // Keep the reference date inside the current period.
                final ref = period.contains(Dates.today()) ? Dates.today() : period.start;
                onChanged(Period.containing(s.first, ref, fw));
              },
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => onChanged(period.shift(-1, fw))),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    final d = await Pickers.date(context, period.start);
                    if (d != null) onChanged(Period.containing(period.type, d, fw));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _label(context),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
              if (!isCurrent)
                IconButton(
                  tooltip: l.today,
                  icon: const Icon(Icons.today),
                  onPressed: () => onChanged(Period.containing(period.type, Dates.today(), fw)),
                ),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => onChanged(period.shift(1, fw))),
            ],
          ),
        ],
      ),
    );
  }
}

class CategoryChip extends StatelessWidget {
  final int? categoryId;
  const CategoryChip({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CategoriesStore>().byId(categoryId);
    if (c == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.colorValue.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.colorValue),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 4, backgroundColor: c.colorValue),
          const SizedBox(width: 4),
          Text(c.name, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

/// Category selection (optional). [allLabel] turns it into a filter.
class CategoryDropdown extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  final String? allLabel;
  final bool dense;

  const CategoryDropdown({super.key, required this.value, required this.onChanged, this.allLabel, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final cats = context.watch<CategoriesStore>().items;
    final v = cats.any((c) => c.id == value) ? value : null;
    return DropdownButtonFormField<int?>(
      initialValue: v,
      key: ValueKey('cat-$v-${cats.length}'),
      isExpanded: true,
      decoration: InputDecoration(labelText: l.category, isDense: dense, prefixIcon: const Icon(Icons.label_outline)),
      items: [
        DropdownMenuItem<int?>(child: Text(allLabel ?? l.noCategory)),
        for (final c in cats)
          DropdownMenuItem<int?>(
            value: c.id,
            child: Row(
              children: [
                CircleAvatar(radius: 6, backgroundColor: c.colorValue),
                const SizedBox(width: 8),
                Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.outline;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: c),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: c),
          ),
        ],
      ),
    );
  }
}

/// Small coloured label showing a signed duration.
class BalanceText extends StatelessWidget {
  final int minutes;
  final TextStyle? style;
  const BalanceText(this.minutes, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final color = minutes > 0
        ? Colors.green.shade600
        : minutes < 0
        ? Theme.of(context).colorScheme.error
        : null;
    return Text(
      Fmt.duration(minutes, signed: true),
      style: (style ?? const TextStyle()).copyWith(color: color, fontWeight: FontWeight.bold),
    );
  }
}

/// Label of an absence part. For [AbsencePart.custom], gives the duration
/// when [customMinutes] is known ([short]: duration only).
String absencePartLabel(BuildContext context, AbsencePart p, {int? customMinutes, bool short = false}) {
  final l = context.l;
  return switch (p) {
    AbsencePart.full => l.absenceFull,
    AbsencePart.morning => l.absenceMorning,
    AbsencePart.afternoon => l.absenceAfternoon,
    AbsencePart.custom when customMinutes == null => l.absenceCustom,
    AbsencePart.custom when short => Fmt.duration(customMinutes!),
    AbsencePart.custom => '${l.absenceCustom} · ${Fmt.duration(customMinutes!)}',
  };
}

/// Label of a clock step (0 arrival, 1 lunch start, 2 lunch end, 3 departure).
String clockStepLabel(BuildContext context, int step) {
  final l = context.l;
  return [l.arrival, l.lunchStart, l.lunchEnd, l.departure][step];
}

/// Returns the localized label of a day type.
String dayTypeLabel(BuildContext context, DayType t) {
  final l = context.l;
  switch (t) {
    case DayType.work:
      return l.dayTypeWork;
    case DayType.vacation:
      return l.dayTypeVacation;
    case DayType.sick:
      return l.dayTypeSick;
    case DayType.holiday:
      return l.dayTypeHoliday;
    case DayType.compensation:
      return l.dayTypeCompensation;
  }
}

IconData dayTypeIcon(DayType t) {
  switch (t) {
    case DayType.work:
      return Icons.work_outline;
    case DayType.vacation:
      return Icons.beach_access;
    case DayType.sick:
      return Icons.healing;
    case DayType.holiday:
      return Icons.celebration;
    case DayType.compensation:
      return Icons.hourglass_bottom;
  }
}
