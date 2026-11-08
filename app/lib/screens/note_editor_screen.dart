import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../data/repository.dart';
import '../drawing/drawing.dart';
import '../models/models.dart';
import '../utils/dates.dart';
import '../utils/ui.dart';
import '../widgets/attachment_views.dart';
import '../widgets/common.dart';
import '../widgets/markdown_editor.dart';
import 'audio_recorder_screen.dart';
import 'drawing_screen.dart';

enum NoteAction { text, photo, audio, drawing, document }

/// Creation / edition of a note with its attachments.
/// The note is linked to the day it was added.
class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  final NoteAction? initialAction;

  const NoteEditorScreen({super.key, this.note, this.initialAction});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _repo = Repository.instance;
  late final TextEditingController _title;
  late final TextEditingController _content;
  int? _id;
  int? _categoryId;
  late DateTime _date;
  late DateTime _createdAt;
  List<Attachment> _attachments = [];
  bool _busy = false;

  bool get _canUseCamera => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    _id = n?.id;
    _title = TextEditingController(text: n?.title ?? '');
    _content = TextEditingController(text: n?.content ?? '');
    _categoryId = n?.categoryId;
    _date = n?.date ?? Dates.today();
    _createdAt = n?.createdAt ?? DateTime.now();
    _attachments = [...?n?.attachments];
    final a = widget.initialAction;
    if (a != null && a != NoteAction.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run(a));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  bool get _isEmpty => _title.text.trim().isEmpty && _content.text.trim().isEmpty && _attachments.isEmpty;

  /// Saves the note and returns its id.
  Future<int> _save() async {
    final id = await _repo.saveNote(
      Note(
        id: _id,
        date: _date,
        title: _title.text.trim(),
        content: _content.text,
        categoryId: _categoryId,
        createdAt: _createdAt,
        updatedAt: DateTime.now(),
      ),
    );
    _id = id;
    return id;
  }

  Future<void> _reloadAttachments() async {
    if (_id == null) return;
    final n = await _repo.note(_id!);
    if (n != null && mounted) setState(() => _attachments = n.attachments);
  }

  Future<void> _addAttachment(AttachmentKind kind, String name, Uint8List data, String? mime) async {
    setState(() => _busy = true);
    try {
      final id = await _save();
      await _repo.addAttachment(noteId: id, kind: kind, fileName: name, mime: mime, data: data);
      await _reloadAttachments();
    } catch (e) {
      if (mounted) context.toast(context.l.errorMessage('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _stamp() => DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

  Future<void> _run(NoteAction a) async {
    switch (a) {
      case NoteAction.text:
        break;
      case NoteAction.photo:
        await _photo();
      case NoteAction.audio:
        await _audio();
      case NoteAction.drawing:
        await _drawing();
      case NoteAction.document:
        await _document();
    }
  }

  Future<void> _photo() async {
    final l = context.l;
    ImageSource? source = ImageSource.gallery;
    if (_canUseCamera) {
      source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(l.takePhoto),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(l.choosePhoto),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
    }
    if (source == null) return;
    try {
      XFile? x;
      if (source == ImageSource.gallery && !_canUseCamera) {
        final f = await FilePicker.pickFile(type: FileType.image);
        if (f == null) return;
        final bytes = await f.readAsBytes();
        await _addAttachment(AttachmentKind.photo, f.name, bytes, Files.mimeFromName(f.name));
        return;
      }
      x = await ImagePicker().pickImage(source: source, maxWidth: 2560, imageQuality: 85);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final name = source == ImageSource.camera ? 'photo_${_stamp()}.jpg' : x.name;
      await _addAttachment(AttachmentKind.photo, name, bytes, Files.mimeFromName(name) ?? 'image/jpeg');
    } catch (e) {
      if (mounted) context.toast(l.errorMessage('$e'));
    }
  }

  Future<void> _audio() async {
    final r = await Navigator.push<AudioResult>(
      context,
      MaterialPageRoute<AudioResult>(builder: (_) => const AudioRecorderScreen()),
    );
    if (r == null) return;
    await _addAttachment(AttachmentKind.audio, 'audio_${_stamp()}.${r.extension}', r.bytes, r.mime);
  }

  Future<void> _drawing() async {
    final d = await Navigator.push<Drawing>(context, MaterialPageRoute<Drawing>(builder: (_) => const DrawingScreen()));
    if (d == null || d.elements.isEmpty) return;
    await _addAttachment(AttachmentKind.drawing, 'dessin_${_stamp()}', d.encode(), kDrawingMime);
  }

  /// Opens a vector drawing in the editor and saves the changes.
  Future<void> _editDrawing(Attachment a) async {
    final bytes = await AttachmentCache.get(a.id!);
    if (!mounted) return;
    final d = await Navigator.push<Drawing>(
      context,
      MaterialPageRoute<Drawing>(builder: (_) => DrawingScreen(initial: Drawing.decode(bytes))),
    );
    if (d == null) return;
    await _repo.updateAttachmentData(a.id!, d.encode());
    AttachmentCache.evict(a.id!);
    await _reloadAttachments();
  }

  Future<void> _document() async {
    try {
      final files = await FilePicker.pickFiles();
      for (final f in files) {
        final bytes = await f.readAsBytes();
        final mime = Files.mimeFromName(f.name);
        final kind = (mime?.startsWith('image/') ?? false)
            ? AttachmentKind.photo
            : (mime?.startsWith('audio/') ?? false)
            ? AttachmentKind.audio
            : AttachmentKind.document;
        await _addAttachment(kind, f.name, bytes, mime);
      }
    } catch (e) {
      if (mounted) context.toast(context.l.errorMessage('$e'));
    }
  }

  Future<void> _openAttachment(Attachment a) async {
    if (a.isVectorDrawing) {
      await _editDrawing(a);
      return;
    }
    if (a.isImage) {
      await Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => ImageViewerScreen(attachment: a)));
      return;
    }
    final bytes = await AttachmentCache.get(a.id!);
    final err = await Files.open(a.fileName, bytes, mime: a.mime);
    if (err != null && mounted) context.toast(context.l.cannotOpenFile(err));
  }

  Widget _menu(Attachment a) {
    final l = context.l;
    return PopupMenuButton<String>(
      onSelected: (v) async {
        switch (v) {
          case 'open':
            await _openAttachment(a);
          case 'rename':
            final n = await Pickers.text(context, title: l.rename, initial: a.fileName, label: l.fileName);
            if (n != null && n.trim().isNotEmpty) {
              await _repo.renameAttachment(a.id!, n.trim());
              await _reloadAttachments();
            }
          case 'save':
            var bytes = await AttachmentCache.get(a.id!);
            var mime = a.mime;
            if (a.isVectorDrawing) {
              bytes = await Drawing.decode(bytes).toPng();
              mime = 'image/png';
            }
            if (await Files.saveToDevice(a.exportFileName, bytes, mime: mime) && mounted) {
              context.toast(l.saved);
            }
          case 'delete':
            if (await Pickers.confirm(context)) {
              await _repo.deleteAttachment(a.id!);
              AttachmentCache.evict(a.id!);
              await _reloadAttachments();
            }
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'open',
          child: ListTile(leading: const Icon(Icons.open_in_new), title: Text(l.open)),
        ),
        PopupMenuItem(
          value: 'rename',
          child: ListTile(leading: const Icon(Icons.edit), title: Text(l.rename)),
        ),
        PopupMenuItem(
          value: 'save',
          child: ListTile(leading: const Icon(Icons.download), title: Text(l.saveToDevice)),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(leading: const Icon(Icons.delete_outline), title: Text(l.delete)),
        ),
      ],
    );
  }

  Future<void> _close() async {
    if (_isEmpty) {
      if (_id != null) await _repo.deleteNote(_id!);
    } else {
      await _save();
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final images = _attachments.where((a) => a.isVisual).toList();
    final audios = _attachments.where((a) => a.kind == AttachmentKind.audio).toList();
    final docs = _attachments.where((a) => a.kind == AttachmentKind.document).toList();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.note == null ? l.newNote : l.editNote),
          actions: [
            if (_id != null)
              IconButton(
                tooltip: l.delete,
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await Pickers.confirm(context)) {
                    await _repo.deleteNote(_id!);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            IconButton(tooltip: l.save, icon: const Icon(Icons.check), onPressed: _close),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionButton(icon: Icons.photo_camera_outlined, label: l.addPhoto, onTap: _busy ? null : _photo),
                _ActionButton(icon: Icons.mic_none, label: l.addAudio, onTap: _busy ? null : _audio),
                _ActionButton(icon: Icons.draw_outlined, label: l.addDrawing, onTap: _busy ? null : _drawing),
                _ActionButton(icon: Icons.attach_file, label: l.addDocument, onTap: _busy ? null : _document),
              ],
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Icon(Icons.event, size: 18),
                const SizedBox(width: 8),
                Text(context.fmtDateLong(_date), style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.title, prefixIcon: const Icon(Icons.short_text)),
            ),
            const SizedBox(height: 12),
            CategoryDropdown(value: _categoryId, onChanged: (v) => setState(() => _categoryId = v)),
            const SizedBox(height: 12),
            MarkdownEditor(controller: _content, label: l.noteText, minLines: 4),
            if (_busy) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
            if (_attachments.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l.attachments, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
            ],
            if (images.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in images)
                    Stack(
                      children: [
                        InkWell(
                          onTap: () => _openAttachment(a),
                          child: AttachmentThumb(attachment: a, size: 110),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                              shape: BoxShape.circle,
                            ),
                            child: _menu(a),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            for (final a in audios) AudioPlayerTile(attachment: a, trailing: _menu(a)),
            for (final a in docs) DocumentTile(attachment: a, onTap: () => _openAttachment(a), trailing: _menu(a)),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ActionButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon),
              const SizedBox(height: 2),
              Text(label, style: Theme.of(context).textTheme.labelSmall, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
