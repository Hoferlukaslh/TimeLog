import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show sqfliteFfiInit, databaseFactoryFfi;
import 'package:url_launcher/url_launcher.dart';

abstract final class Host {
  static bool get isAndroid => Platform.isAndroid;
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  /// Installed application on a computer (not a browser).
  static bool get isDesktopApp => Platform.isLinux || Platform.isWindows || Platform.isMacOS;
}

/// Selects the SQLite implementation. Android / iOS use the sqflite plugin.
void prepareDatabaseFactory() {
  if (Host.isMobile) return;
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

Future<String> defaultDatabasePath() async {
  if (Host.isMobile) return p.join(await getDatabasesPath(), 'timelog.db');
  // ~/.local/share/<app id>/ on Linux, %APPDATA%\<company>\<product>\ on Windows.
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  return p.join(dir.path, 'timelog.db');
}

Future<Directory> _tempDir() async => Directory(p.join((await getTemporaryDirectory()).path, 'timelog_files'));

/// Deletes the temporary copies of attachments (opened files, audio played).
/// Called at start-up: the originals stay in the database.
Future<void> clearTempFiles() async {
  try {
    final dir = await _tempDir();
    if (await dir.exists()) await dir.delete(recursive: true);
  } on FileSystemException {
    // A file may still be open in another app: it will be removed next time.
  }
}

/// Writes the file to a temporary location (cache) and returns its path.
Future<String> writeTempFile(String fileName, Uint8List bytes) async {
  final sub = await _tempDir();
  await sub.create(recursive: true);
  final safe = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  final f = File(p.join(sub.path, safe));
  await f.writeAsBytes(bytes, flush: true);
  return f.path;
}

/// Asks the user where to save [bytes]. Returns true if saved.
Future<bool> saveBytes(String fileName, Uint8List bytes, {String? mime}) async {
  final uri = await FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: mime ?? 'application/octet-stream');
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

/// Opens the file with the default app of the device. Returns an error message or null.
Future<String?> openBytes(String fileName, Uint8List bytes, {String? mime}) async {
  final path = await writeTempFile(fileName, bytes);
  if (Platform.isLinux) {
    final r = await Process.run('xdg-open', [path]);
    return r.exitCode == 0 ? null : '${r.stderr}';
  }
  if (Platform.isWindows) {
    // Not `cmd /c start` (open_filex): cmd would interpret characters such as
    // "&" that are allowed in the name of an attachment.
    return await launchUrl(Uri.file(path)) ? null : path;
  }
  final r = await OpenFilex.open(path, type: mime);
  return r.type == ResultType.done ? null : r.message;
}

/// The audio player reads a file on these platforms.
Future<Source> audioSourceFor(String fileName, Uint8List bytes, String? mime) async =>
    DeviceFileSource(await writeTempFile(fileName, bytes), mimeType: mime);

/// Where the recorder writes (the recorder needs a file on these platforms).
Future<String> newRecordingPath(String extension) async {
  final dir = await getTemporaryDirectory();
  return p.join(dir.path, 'rec_${DateTime.now().millisecondsSinceEpoch}.$extension');
}

/// Returns the content of a finished recording and removes the file.
Future<Uint8List> takeRecording(String path) async {
  final f = File(path);
  // Give the encoder a moment to flush the file.
  for (var i = 0; i < 10 && !await f.exists(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  final bytes = await f.readAsBytes();
  await f.delete().catchError((_) => f);
  return bytes;
}
