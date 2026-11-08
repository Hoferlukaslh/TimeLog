import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/categories_store.dart';
import '../services/export_service.dart';
import '../services/settings.dart';
import '../utils/ui.dart';
import '../widgets/attachment_views.dart';
import '../widgets/responsive.dart';

class ExportScreen extends StatefulWidget {
  final Widget? drawer;
  const ExportScreen({super.key, this.drawer});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final _service = ExportService();
  ExportFormat _format = ExportFormat.json;
  final Set<ExportDataset> _datasets = {...ExportDataset.values};
  bool _attachments = true;
  bool _busy = false;

  String _label(ExportDataset d) {
    final l = context.l;
    switch (d) {
      case ExportDataset.hours:
        return l.menuHours;
      case ExportDataset.journal:
        return l.menuJournal;
      case ExportDataset.notes:
        return l.menuNotes;
      case ExportDataset.categories:
        return l.menuCategories;
      case ExportDataset.settings:
        return l.settingsData;
    }
  }

  Future<void> _export() async {
    final l = context.l;
    setState(() => _busy = true);
    try {
      final (name, bytes, mime) = await _service.export(_format, _datasets, includeAttachments: _attachments);
      final ok = await Files.saveToDevice(name, bytes, mime: mime);
      if (ok && mounted) context.toast(l.exportDone);
    } catch (e) {
      if (mounted) context.toast(l.errorMessage('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final l = context.l;
    final settings = context.read<AppSettings>();
    final cats = context.read<CategoriesStore>();
    final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json']);
    if (f == null || !mounted) return;
    if (!await Pickers.confirm(context, title: l.importBackup, message: l.importConfirm)) return;
    setState(() => _busy = true);
    try {
      await _service.restoreJson(await f.readAsBytes());
      await settings.load();
      await cats.load();
      if (mounted) context.toast(l.importDone);
    } catch (e) {
      if (mounted) context.toast(l.errorMessage('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      drawer: widget.drawer,
      appBar: AppBar(title: Text(l.exportTitle)),
      body: CenteredListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.exportFormat, style: t.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ExportFormat>(
            segments: const [
              ButtonSegment(value: ExportFormat.json, label: Text('JSON'), icon: Icon(Icons.data_object)),
              ButtonSegment(value: ExportFormat.csv, label: Text('CSV'), icon: Icon(Icons.table_chart_outlined)),
            ],
            selected: {_format},
            onSelectionChanged: (s) => setState(() => _format = s.first),
          ),
          const SizedBox(height: 8),
          Text(_format == ExportFormat.csv ? l.exportCsvInfo : l.exportJsonInfo, style: t.bodySmall),
          const SizedBox(height: 24),
          Text(l.exportWhat, style: t.titleMedium),
          for (final d in ExportDataset.values)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _datasets.contains(d),
              title: Text(_label(d)),
              onChanged: (v) => setState(() => v! ? _datasets.add(d) : _datasets.remove(d)),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _attachments && _datasets.contains(ExportDataset.notes),
            title: Text(l.includeAttachments),
            onChanged: _datasets.contains(ExportDataset.notes) ? (v) => setState(() => _attachments = v) : null,
          ),
          const SizedBox(height: 16),
          if (_busy) const Padding(padding: EdgeInsets.only(bottom: 16), child: LinearProgressIndicator()),
          FilledButton.icon(
            onPressed: _busy || _datasets.isEmpty ? null : _export,
            icon: const Icon(Icons.download),
            label: Text(l.exportButton),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    await _import();
                    // Restored attachments may reuse ids.
                    AttachmentCache.clear();
                  },
            icon: const Icon(Icons.restore),
            label: Text(l.importBackup),
          ),
        ],
      ),
    );
  }
}
