import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repository.dart';
import '../models/models.dart';
import '../services/settings.dart';
import '../utils/dates.dart';
import '../utils/ui.dart';
import '../widgets/attachment_views.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import 'note_editor_screen.dart';

class NotesScreen extends StatefulWidget {
  final Widget? drawer;
  const NotesScreen({super.key, this.drawer});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _repo = Repository.instance;
  final _search = TextEditingController();
  Timer? _debounce;
  late Period _period;
  int? _filterCategory;
  List<Note> _notes = [];

  bool get _searching => _search.text.trim().isNotEmpty;

  /// Room for three columns of notes.
  static const _maxWidth = 1200.0;

  @override
  void initState() {
    super.initState();
    _period = Period.containing(PeriodType.month, Dates.today(), context.read<AppSettings>().firstWeekday);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    List<Note> list;
    if (_searching) {
      list = await _repo.searchNotes(_search.text, categoryId: _filterCategory);
    } else {
      list = await _repo.notes(_period.start, _period.end);
      if (_filterCategory != null) {
        list = list.where((n) => n.categoryId == _filterCategory).toList();
      }
    }
    if (mounted) setState(() => _notes = list);
  }

  Future<void> _open({Note? note, NoteAction? action}) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => NoteEditorScreen(note: note, initialAction: action),
      ),
    );
    await _load();
  }

  void _showAddMenu() {
    final l = context.l;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        Widget item(IconData i, String t, NoteAction a) => ListTile(
          leading: Icon(i),
          title: Text(t),
          onTap: () {
            Navigator.pop(ctx);
            _open(action: a);
          },
        );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l.newNote, style: Theme.of(ctx).textTheme.titleMedium),
              ),
              item(Icons.notes, l.noteText, NoteAction.text),
              item(Icons.photo_camera_outlined, l.addPhoto, NoteAction.photo),
              item(Icons.mic_none, l.addAudio, NoteAction.audio),
              item(Icons.draw_outlined, l.addDrawing, NoteAction.drawing),
              item(Icons.attach_file, l.addDocument, NoteAction.document),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      drawer: widget.drawer,
      appBar: AppBar(title: Text(l.menuNotes)),
      floatingActionButton: FloatingActionButton(
        tooltip: l.newNote,
        onPressed: _showAddMenu,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CenteredListView(
          maxWidth: _maxWidth,
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: CenteredBox(
                child: SearchBar(
                  controller: _search,
                  hintText: l.searchNotesHint,
                  leading: const Icon(Icons.search),
                  trailing: [
                    if (_searching)
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          _load();
                        },
                      ),
                  ],
                  onChanged: (_) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 300), _load);
                    setState(() {});
                  },
                ),
              ),
            ),
            if (!_searching)
              CenteredBox(
                child: PeriodSelector(
                  period: _period,
                  onChanged: (p) {
                    setState(() => _period = p);
                    _load();
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: CenteredBox(
                child: CategoryDropdown(
                  value: _filterCategory,
                  allLabel: l.allCategories,
                  dense: true,
                  onChanged: (v) {
                    setState(() => _filterCategory = v);
                    _load();
                  },
                ),
              ),
            ),
            if (_notes.isEmpty)
              EmptyState(
                icon: _searching ? Icons.search_off : Icons.sticky_note_2_outlined,
                text: _searching ? l.noResults : l.nothingHere,
              ),
            LayoutBuilder(
              builder: (context, c) {
                final columns = Responsive.twoColumns(context, c.maxWidth) ? (c.maxWidth / 380).floor().clamp(2, 3) : 1;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _grouped(columns == 1 ? null : c.maxWidth / columns),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Notes grouped by day. [cardWidth]: side by side, null: one under the other.
  List<Widget> _grouped(double? cardWidth) {
    final out = <Widget>[];
    var day = <Widget>[];
    void endOfDay() {
      if (cardWidth != null && day.isNotEmpty) out.add(Wrap(children: day));
      day = [];
    }

    DateTime? last;
    for (final n in _notes) {
      if (last == null || !Dates.sameDay(last, n.date)) {
        endOfDay();
        last = n.date;
        out.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              context.fmtDateLong(n.date),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        );
      }
      final card = _NoteCard(
        note: n,
        onTap: () => _open(note: n),
      );
      if (cardWidth == null) {
        out.add(card);
      } else {
        day.add(SizedBox(width: cardWidth, child: card));
      }
    }
    endOfDay();
    return out;
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  const _NoteCard({required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final title = note.title.isNotEmpty
        ? note.title
        : note.attachments.isNotEmpty
        ? note.attachments.first.fileName
        : l.untitled;
    final snippet = note.content.trim().replaceAll(RegExp(r'[#*`>\-\[\]]'), '').trim();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: t.titleMedium, overflow: TextOverflow.ellipsis),
                  ),
                  Text(TimeOfDay.fromDateTime(note.createdAt).format(context), style: t.bodySmall),
                ],
              ),
              if (note.categoryId != null) ...[const SizedBox(height: 4), CategoryChip(categoryId: note.categoryId)],
              if (snippet.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(snippet, maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
              if (note.attachments.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 56,
                  child: ScrollConfiguration(
                    // A mouse has no horizontal wheel: the row can be dragged.
                    behavior: ScrollConfiguration.of(context)
                        .copyWith(dragDevices: {...PointerDeviceKind.values}, scrollbars: false),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final a in note.attachments)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Tooltip(
                              message: a.fileName,
                              child: AttachmentThumb(attachment: a, size: 56),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
