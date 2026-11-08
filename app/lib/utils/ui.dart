import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../l10n/gen/app_localizations.dart';
import '../services/settings.dart';
import 'dates.dart';

extension ContextX on BuildContext {
  AppLocalizations get l => AppLocalizations.of(this);
  AppSettings get settings => read<AppSettings>();
  String get localeName => Localizations.localeOf(this).toLanguageTag();

  String fmtTime(int? minutes) => Fmt.time(minutes, watch<AppSettings>().use24h, localeName);

  String fmtDateLong(DateTime d) => DateFormat.yMMMMEEEEd(localeName).format(d);
  String fmtDateShort(DateTime d) => DateFormat.yMMMEd(localeName).format(d);

  void toast(String msg) => ScaffoldMessenger.of(this)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

/// All time entries go through these pickers.
class Pickers {
  static Future<DateTime?> date(BuildContext context, DateTime initial) {
    return showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2000), lastDate: DateTime(2100));
  }

  /// Returns minutes after midnight.
  static Future<int?> time(BuildContext context, int? initialMinutes, {String? help}) async {
    final now = TimeOfDay.now();
    final init = initialMinutes == null ? now : TimeOfDay(hour: initialMinutes ~/ 60, minute: initialMinutes % 60);
    final use24h = context.read<AppSettings>().use24h;
    final t = await showTimePicker(
      context: context,
      initialTime: init,
      helpText: help,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: use24h),
        child: child!,
      ),
    );
    return t == null ? null : t.hour * 60 + t.minute;
  }

  /// Duration picker (hours + minutes) built on the time picker dial in
  /// 24h input mode. Returns minutes.
  static Future<int?> duration(BuildContext context, int? initialMinutes, {String? help}) async {
    final m = initialMinutes ?? 60;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (m ~/ 60).clamp(0, 23), minute: m % 60),
      helpText: help ?? context.l.hoursMinutes,
      builder: (ctx, child) =>
          MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    return t == null ? null : t.hour * 60 + t.minute;
  }

  static Future<bool> confirm(BuildContext context, {String? title, String? message}) async {
    final l = context.l;
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title ?? l.deleteConfirmTitle),
        content: Text(message ?? l.deleteConfirmMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.ok)),
        ],
      ),
    );
    return r ?? false;
  }

  static Future<String?> text(BuildContext context, {required String title, String initial = '', String? label}) {
    final ctrl = TextEditingController(text: initial);
    final l = context.l;
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: Text(l.ok)),
        ],
      ),
    );
  }
}

class Files {
  /// Asks the user where to save [bytes]. Returns true if saved.
  static Future<bool> saveToDevice(String fileName, Uint8List bytes, {String? mime}) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mime ?? 'application/octet-stream',
    );
    if (uri == null) return false;
    // Some desktop implementations only return the chosen path.
    if (uri.scheme == 'file') {
      final f = File(uri.toFilePath());
      if (!await f.exists() || await f.length() != bytes.length) {
        await f.writeAsBytes(bytes, flush: true);
      }
    }
    return true;
  }

  static Future<Directory> _tempDir() async => Directory(p.join((await getTemporaryDirectory()).path, 'timelog_files'));

  /// Deletes the temporary copies of attachments (opened files, audio played).
  /// Called at start-up: the originals stay in the database.
  static Future<void> clearTemp() async {
    try {
      final dir = await _tempDir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } on FileSystemException {
      // A file may still be open in another app: it will be removed next time.
    }
  }

  /// Writes the file to a temporary location (cache) and returns it.
  static Future<File> toTemp(String fileName, Uint8List bytes) async {
    final sub = await _tempDir();
    await sub.create(recursive: true);
    final safe = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final f = File(p.join(sub.path, safe));
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  /// Opens the file with the default app of the device. Returns an error message or null.
  static Future<String?> open(String fileName, Uint8List bytes, {String? mime}) async {
    final f = await toTemp(fileName, bytes);
    if (Platform.isLinux) {
      final r = await Process.run('xdg-open', [f.path]);
      return r.exitCode == 0 ? null : '${r.stderr}';
    }
    final r = await OpenFilex.open(f.path, type: mime);
    return r.type == ResultType.done ? null : r.message;
  }

  static String? mimeFromName(String name) {
    switch (p.extension(name).toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.heic':
        return 'image/heic';
      case '.pdf':
        return 'application/pdf';
      case '.txt':
        return 'text/plain';
      case '.csv':
        return 'text/csv';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.xls':
        return 'application/vnd.ms-excel';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.m4a':
        return 'audio/mp4';
      case '.aac':
        return 'audio/aac';
      case '.wav':
        return 'audio/wav';
      case '.mp3':
        return 'audio/mpeg';
      case '.ogg':
      case '.opus':
        return 'audio/ogg';
      default:
        return null;
    }
  }
}
