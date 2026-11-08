import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart' show databaseFactoryFfiWeb;
import 'package:web/web.dart' as web;

abstract final class Host {
  static bool get isAndroid => false;
  static bool get isMobile => false;
  static bool get isDesktopApp => false;
}

/// SQLite compiled to WebAssembly (web/sqlite3.wasm), run in a shared worker
/// (web/sqflite_sw.js) and stored in the IndexedDB of the browser.
void prepareDatabaseFactory() => databaseFactory = databaseFactoryFfiWeb;

Future<String> defaultDatabasePath() async => 'timelog.db';

/// Nothing is written outside of the database in the browser.
Future<void> clearTempFiles() async {}

/// What a browser can safely display in a new tab. Other types (HTML, SVG:
/// they could run scripts on the origin of the application) are downloaded.
bool _canDisplay(String? mime) =>
    mime != null &&
    (mime == 'application/pdf' ||
        mime == 'text/plain' ||
        mime.startsWith('audio/') ||
        (mime.startsWith('image/') && !mime.contains('svg')));

/// Displays the file in a new tab, or downloads it. Returns an error message or null.
Future<String?> openBytes(String fileName, Uint8List bytes, {String? mime}) async {
  final type = _canDisplay(mime) ? mime! : 'application/octet-stream';
  final url = web.URL.createObjectURL(web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: type)));
  final link = web.HTMLAnchorElement()..href = url;
  if (_canDisplay(mime)) {
    link
      ..target = '_blank'
      ..rel = 'noopener';
  } else {
    link.download = fileName;
  }
  link.click();
  // The URL must outlive the opening of the tab or the download.
  Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
  return null;
}

/// Downloads the file (into the folder chosen in the browser settings).
Future<bool> saveBytes(String fileName, Uint8List bytes, {String? mime}) async {
  await openBytes(fileName, bytes);
  return true;
}

Future<Source> audioSourceFor(String fileName, Uint8List bytes, String? mime) async =>
    BytesSource(bytes, mimeType: mime);

/// The browser recorder ignores the path and returns a blob: URL.
Future<String> newRecordingPath(String extension) async => '';

/// Returns the content of a finished recording ([path] is a blob: URL).
Future<Uint8List> takeRecording(String path) async {
  final bytes = await http.readBytes(Uri.parse(path));
  web.URL.revokeObjectURL(path);
  return bytes;
}
