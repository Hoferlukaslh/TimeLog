/// Everything that depends on the host (files, database location, recordings).
///
/// `dart:io` does not exist in the browser: the code shared by all platforms
/// only uses this library, implemented by platform_io.dart (Android, Linux,
/// Windows) and platform_web.dart (browser).
library;

export 'platform_io.dart' if (dart.library.js_interop) 'platform_web.dart';
