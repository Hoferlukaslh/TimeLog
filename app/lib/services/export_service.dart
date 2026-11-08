import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../data/repository.dart';
import '../drawing/drawing.dart';

enum ExportFormat { csv, json }

enum ExportDataset { hours, journal, notes, categories, settings }

/// Builds CSV / JSON exports of the whole database, and restores JSON backups.
class ExportService {
  static const _tables = {
    ExportDataset.hours: ['time_entries', 'vacation_years'],
    ExportDataset.journal: ['journal_entries'],
    ExportDataset.notes: ['notes', 'attachments'],
    ExportDataset.categories: ['categories'],
    ExportDataset.settings: ['settings'],
  };

  final Repository _repo = Repository.instance;

  /// Returns (fileName, bytes, mime).
  Future<(String, Uint8List, String)> export(
    ExportFormat format,
    Set<ExportDataset> datasets, {
    bool includeAttachments = true,
  }) async {
    final stamp = DateTime.now().toIso8601String().substring(0, 19).replaceAll(':', '-');
    final tables = <String, List<Map<String, Object?>>>{};
    for (final ds in ExportDataset.values) {
      if (!datasets.contains(ds)) continue;
      for (final t in _tables[ds]!) {
        tables[t] = await _repo.rawTable(t);
      }
    }
    final withFiles = includeAttachments && tables.containsKey('attachments');

    if (format == ExportFormat.json) {
      final out = <String, Object?>{
        'app': 'TimeLog',
        'format': 1,
        'exported_at': DateTime.now().toIso8601String(),
        'tables': tables,
      };
      if (withFiles) {
        final files = <String, String>{};
        final images = <String, String>{};
        for (final a in tables['attachments']!) {
          final id = a['id'] as int;
          final data = await _repo.attachmentData(id);
          // Vector data (to restore the backup) ...
          files['$id'] = base64Encode(data);
          // ... and the drawing as an image, for other programs.
          if (a['mime'] == kDrawingMime) {
            images['$id'] = base64Encode(await Drawing.decode(data).toPng());
          }
        }
        out['attachment_data'] = files;
        if (images.isNotEmpty) out['drawing_images_png'] = images;
      }
      final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(out));
      return ('timelog_$stamp.json', Uint8List.fromList(bytes), 'application/json');
    }

    // CSV: one file per table, zipped together (with attachment files).
    final archive = Archive();
    for (final e in tables.entries) {
      final data = utf8.encode('﻿${toCsv(e.value)}');
      archive.addFile(ArchiveFile('${e.key}.csv', data.length, data));
    }
    if (withFiles) {
      for (final a in tables['attachments']!) {
        final id = a['id'] as int;
        var data = await _repo.attachmentData(id);
        var name = a['file_name'] as String;
        if (a['mime'] == kDrawingMime) {
          data = await Drawing.decode(data).toPng();
          name = '$name.png';
        }
        final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        archive.addFile(ArchiveFile('attachments/${id}_$safe', data.length, data));
      }
    }
    final zip = ZipEncoder().encode(archive);
    return ('timelog_csv_$stamp.zip', Uint8List.fromList(zip), 'application/zip');
  }

  static String toCsv(List<Map<String, Object?>> rows) {
    if (rows.isEmpty) return '';
    final cols = rows.first.keys.toList();
    final sb = StringBuffer()..writeln(cols.map(_cell).join(';'));
    for (final r in rows) {
      sb.writeln(cols.map((c) => _cell(r[c])).join(';'));
    }
    return sb.toString();
  }

  static String _cell(Object? v) {
    if (v == null) return '';
    final s = v.toString();
    if (s.contains(RegExp(r'[;"\n\r]'))) return '"${s.replaceAll('"', '""')}"';
    return s;
  }

  /// Restores a JSON backup produced by [export].
  /// Throws a [FormatException] if the file is not a valid TimeLog backup.
  Future<void> restoreJson(Uint8List bytes) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const FormatException('Not a TimeLog backup');
    }
    if (decoded case {'app': 'TimeLog', 'tables': final Map<String, Object?> rawTables}) {
      final tables = <String, List<Map<String, Object?>>>{};
      for (final MapEntry(:key, :value) in rawTables.entries) {
        if (value is! List<Object?>) throw FormatException('Invalid table: $key');
        tables[key] = [
          for (final row in value)
            if (row is Map<String, Object?>) row else throw FormatException('Invalid row in $key'),
        ];
      }
      final files = <int, Uint8List>{};
      if (decoded['attachment_data'] case final Map<String, Object?> data) {
        for (final MapEntry(:key, :value) in data.entries) {
          final id = int.tryParse(key);
          if (id == null || value is! String) throw const FormatException('Invalid attachment data');
          files[id] = base64Decode(value);
        }
      }
      // Attachments without data cannot be restored.
      if (tables['attachments'] case final attachments?) {
        tables['attachments'] = attachments.where((a) => files.containsKey(a['id'])).toList();
      }
      await _repo.restore(tables, files);
      return;
    }
    throw const FormatException('Not a TimeLog backup');
  }
}
