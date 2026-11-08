import 'dart:io';

import 'package:flutter/services.dart';

/// Asks the Android home screen widget to refresh after data changes.
class WidgetSync {
  static const _channel = MethodChannel('ch.lukas.timelog/widget');

  static Future<void> refresh() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('refresh');
    } catch (_) {
      // The widget is optional: never fail because of it.
    }
  }
}
