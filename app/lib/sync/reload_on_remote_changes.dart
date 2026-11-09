import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'sync_controller.dart';

/// Reloads a screen in place when data arrives from another device.
///
/// The widget stays mounted: the period shown, the mode, the scroll position,
/// open dialogs and the text being typed are kept.
mixin ReloadOnRemoteChanges<T extends StatefulWidget> on State<T> {
  late final SyncController _sync;
  late int _dataVersion;

  /// Reads the data again.
  Future<void> reloadRemoteChanges();

  @override
  void initState() {
    super.initState();
    _sync = context.read<SyncController>();
    _dataVersion = _sync.dataVersion;
    _sync.addListener(_onSyncChanged);
  }

  void _onSyncChanged() {
    if (_sync.dataVersion == _dataVersion) return;
    _dataVersion = _sync.dataVersion;
    reloadRemoteChanges();
  }

  @override
  void dispose() {
    _sync.removeListener(_onSyncChanged);
    super.dispose();
  }
}
