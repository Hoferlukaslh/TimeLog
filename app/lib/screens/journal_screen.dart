import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';

import '../data/repository.dart';
import '../models/models.dart';
import '../services/settings.dart';
import '../utils/dates.dart';
import '../utils/ui.dart';
import '../widgets/common.dart';
import '../widgets/journal_form.dart';

class JournalScreen extends StatefulWidget {
  final Widget drawer;
  const JournalScreen({super.key, required this.drawer});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _repo = Repository.instance;
  bool _addMode = false;
  late Period _period;
  DateTime _addDate = Dates.today();
  int? _filterCategory;
  List<JournalEntry> _entries = [];
  List<JournalEntry> _dayEntries = [];

  @override
  void initState() {
    super.initState();
    _period = Period.containing(PeriodType.week, Dates.today(), context.read<AppSettings>().firstWeekday);
    _load();
  }

  Future<void> _load() async {
    final list = await _repo.journal(_period.start, _period.end);
    final day = await _repo.journal(_addDate, _addDate);
    if (!mounted) return;
    setState(() {
      _entries = list;
      _dayEntries = day;
    });
  }

  Future<void> _edit(JournalEntry? e) async {
    final l = context.l;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: Text(e == null ? l.newEntry : l.editEntry),
            actions: [
              if (e != null)
                IconButton(
                  tooltip: l.delete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await Pickers.confirm(ctx)) {
                      await _repo.deleteJournal(e.id!);
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  },
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: JournalForm(
              entry: e,
              initialDate: _period.contains(Dates.today()) ? Dates.today() : _period.start,
              onSaved: (_) => Navigator.pop(ctx),
            ),
          ),
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      drawer: widget.drawer,
      appBar: AppBar(
        title: Text(l.menuJournal),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: true, icon: const Icon(Icons.edit_note), label: Text(l.journalModeAdd)),
                  ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.visibility_outlined),
                    label: Text(l.journalModeView),
                  ),
                ],
                selected: {_addMode},
                onSelectionChanged: (s) => setState(() => _addMode = s.first),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: _addMode
          ? null
          : FloatingActionButton(tooltip: l.newEntry, onPressed: () => _edit(null), child: const Icon(Icons.add)),
      body: _addMode ? _buildAdd() : _buildView(),
    );
  }

  Widget _buildAdd() {
    final l = context.l;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l.newEntry, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        JournalForm(
          initialDate: _addDate,
          clearAfterSave: true,
          onDateChanged: (d) {
            _addDate = d;
            _load();
          },
          onSaved: (_) => _load(),
        ),
        const SizedBox(height: 24),
        Text('${l.entriesOfDay} · ${context.fmtDateShort(_addDate)}', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_dayEntries.isEmpty) EmptyState(icon: Icons.menu_book, text: l.nothingHere),
        for (final e in _dayEntries) _EntryCard(entry: e, onTap: () => _edit(e)),
      ],
    );
  }

  Widget _buildView() {
    final l = context.l;
    final list = _filterCategory == null ? _entries : _entries.where((e) => e.categoryId == _filterCategory).toList();
    final total = list.fold<int>(0, (s, e) => s + (e.durationMinutes ?? 0));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          PeriodSelector(
            period: _period,
            onChanged: (p) {
              setState(() => _period = p);
              _load();
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: CategoryDropdown(
                    value: _filterCategory,
                    allLabel: l.allCategories,
                    dense: true,
                    onChanged: (v) => setState(() => _filterCategory = v),
                  ),
                ),
                const SizedBox(width: 12),
                Chip(
                  avatar: const Icon(Icons.timer_outlined, size: 18),
                  label: Text(l.totalDuration(Fmt.duration(total))),
                ),
              ],
            ),
          ),
          if (list.isEmpty) EmptyState(icon: Icons.menu_book, text: l.nothingHere),
          ..._grouped(list),
        ],
      ),
    );
  }

  List<Widget> _grouped(List<JournalEntry> list) {
    final out = <Widget>[];
    DateTime? last;
    for (final e in list) {
      if (last == null || !Dates.sameDay(last, e.date)) {
        last = e.date;
        final dayTotal = list
            .where((x) => Dates.sameDay(x.date, e.date))
            .fold<int>(0, (s, x) => s + (x.durationMinutes ?? 0));
        out.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.fmtDateLong(e.date),
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
                if (dayTotal > 0) Text(Fmt.duration(dayTotal)),
              ],
            ),
          ),
        );
      }
      out.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _EntryCard(entry: e, onTap: () => _edit(e)),
        ),
      );
    }
    return out;
  }
}

class _EntryCard extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback onTap;
  const _EntryCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(entry.title.isEmpty ? context.l.untitled : entry.title, style: t.titleMedium)),
                  if (entry.durationMinutes != null)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.timer_outlined, size: 16),
                      label: Text(Fmt.duration(entry.durationMinutes!)),
                    ),
                ],
              ),
              if (entry.categoryId != null) ...[const SizedBox(height: 4), CategoryChip(categoryId: entry.categoryId)],
              if (entry.content.trim().isNotEmpty) ...[const SizedBox(height: 8), MarkdownBody(data: entry.content)],
            ],
          ),
        ),
      ),
    );
  }
}
