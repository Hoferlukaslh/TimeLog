import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../models/models.dart';
import '../utils/dates.dart';
import '../utils/ui.dart';
import 'common.dart';
import 'markdown_editor.dart';

/// Form to create or edit a journal entry.
class JournalForm extends StatefulWidget {
  final JournalEntry? entry;
  final DateTime initialDate;

  /// Called after a successful save.
  final ValueChanged<JournalEntry>? onSaved;

  /// In "add" mode the form is cleared after saving to add another entry.
  final bool clearAfterSave;

  final ValueChanged<DateTime>? onDateChanged;

  const JournalForm({
    super.key,
    this.entry,
    required this.initialDate,
    this.onSaved,
    this.clearAfterSave = false,
    this.onDateChanged,
  });

  @override
  State<JournalForm> createState() => _JournalFormState();
}

class _JournalFormState extends State<JournalForm> {
  late DateTime _date;
  late final TextEditingController _title;
  late final TextEditingController _content;
  int? _duration;
  int? _categoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _date = e?.date ?? widget.initialDate;
    _title = TextEditingController(text: e?.title ?? '');
    _content = TextEditingController(text: e?.content ?? '');
    _duration = e?.durationMinutes;
    _categoryId = e?.categoryId;
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l;
    if (_title.text.trim().isEmpty && _content.text.trim().isEmpty) {
      context.toast(l.titleOrContentRequired);
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final e = JournalEntry(
      id: widget.entry?.id,
      date: _date,
      title: _title.text.trim(),
      content: _content.text,
      durationMinutes: _duration,
      categoryId: _categoryId,
      createdAt: widget.entry?.createdAt ?? now,
      updatedAt: now,
    );
    final id = await Repository.instance.saveJournal(e);
    if (!mounted) return;
    setState(() => _saving = false);
    final saved = JournalEntry(
      id: id,
      date: e.date,
      title: e.title,
      content: e.content,
      durationMinutes: e.durationMinutes,
      categoryId: e.categoryId,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
    );
    if (widget.clearAfterSave) {
      _title.clear();
      _content.clear();
      setState(() => _duration = null);
      context.toast(l.entryAdded);
    }
    widget.onSaved?.call(saved);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: InputDecorator(
                decoration: InputDecoration(labelText: l.date, prefixIcon: const Icon(Icons.event)),
                child: InkWell(
                  onTap: () async {
                    final d = await Pickers.date(context, _date);
                    if (d != null) {
                      setState(() => _date = Dates.dateOnly(d));
                      widget.onDateChanged?.call(_date);
                    }
                  },
                  child: Text(context.fmtDateShort(_date)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l.title, prefixIcon: const Icon(Icons.short_text)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: CategoryDropdown(value: _categoryId, onChanged: (v) => setState(() => _categoryId = v)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: '${l.duration} (${l.optional})',
                  prefixIcon: const Icon(Icons.timer_outlined),
                  suffixIcon: _duration == null
                      ? null
                      : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _duration = null)),
                ),
                child: InkWell(
                  onTap: () async {
                    final m = await Pickers.duration(context, _duration, help: l.duration);
                    if (m != null) setState(() => _duration = m);
                  },
                  child: Text(_duration == null ? l.noDuration : Fmt.duration(_duration!)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        MarkdownEditor(controller: _content, label: l.content),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save),
          label: Text(widget.clearAfterSave ? l.saveAndNew : l.save),
        ),
      ],
    );
  }
}
