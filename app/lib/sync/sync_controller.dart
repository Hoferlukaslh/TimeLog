import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';

import 'http_sync_backend.dart';
import 'sync_backend.dart';
import 'sync_engine.dart';
import 'sync_models.dart';

enum SyncStatus {
  /// No account connected.
  off,
  idle,
  syncing,

  /// The server cannot be reached: the app works offline.
  offline,
  error,
}

/// State of the synchronization for the interface, and automatic syncs:
/// at start-up, when the app comes back to the foreground, every
/// [pushInterval] when something changed and every [pullInterval] otherwise.
class SyncController extends ChangeNotifier with WidgetsBindingObserver {
  final Database db;
  final SyncBackend Function(String serverUrl) backendFactory;

  /// Called after changes from other devices were applied (reload the data).
  final Future<void> Function()? onRemoteChanges;

  static const pushInterval = Duration(seconds: 20);
  static const pullInterval = Duration(minutes: 3);

  SyncController(this.db, {SyncBackend Function(String)? backendFactory, this.onRemoteChanges})
    : backendFactory = backendFactory ?? HttpSyncBackend.new;

  SyncEngine? _engine;
  Timer? _timer;
  DateTime _lastAttempt = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void>? _running;

  SyncStatus status = SyncStatus.off;
  String? serverUrl;
  String? email;
  DateTime? lastSync;
  int pending = 0;

  /// Last error (exception) of an automatic or manual sync.
  Object? lastError;

  /// Increased each time data arrives from another device.
  int dataVersion = 0;

  bool get signedIn => status != SyncStatus.off;

  SyncEngine _engineFor(String url) => SyncEngine(db, backendFactory(url));

  /// Reads the saved state and starts the automatic synchronization.
  Future<void> start() async {
    final probe = SyncEngine(db, backendFactory('localhost'));
    serverUrl = await probe.serverUrl();
    email = await probe.lastEmail();
    if (serverUrl != null && await probe.session() != null && await probe.isEnabled) {
      _engine = _engineFor(serverUrl!);
      status = SyncStatus.idle;
      lastSync = await _engine!.lastSync();
      pending = await _engine!.pendingCount();
    }
    notifyListeners();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => unawaited(_tick()));
    unawaited(syncNow(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(syncNow(silent: true));
  }

  Future<void> _tick() async {
    final engine = _engine;
    if (engine == null || _running != null) return;
    pending = await engine.pendingCount();
    final since = DateTime.now().difference(_lastAttempt);
    if ((pending > 0 && since >= pushInterval) || since >= pullInterval) {
      await syncNow(silent: true);
    } else {
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- account
  /// Signs in (or creates the account) on [url]. Throws [SyncAuthException]
  /// or [SyncNetworkException] with the reason.
  Future<void> signIn(String url, String mail, String password, {bool create = false}) async {
    final backend = backendFactory(url);
    if (backend is HttpSyncBackend) await backend.checkServer();
    final engine = SyncEngine(db, backend);
    await engine.setServerUrl(url.trim());
    if (create) {
      await engine.signUp(mail, password);
    } else {
      await engine.signIn(mail, password);
    }
    _engine = engine;
    serverUrl = url.trim();
    email = mail.trim().toLowerCase();
    status = SyncStatus.idle;
    lastError = null;
    notifyListeners();
    await syncNow();
  }

  Future<void> signOut() async {
    await _engine?.signOut();
    _engine = null;
    status = SyncStatus.off;
    lastSync = null;
    pending = 0;
    notifyListeners();
  }

  Future<void> deleteAccount(String password) async {
    await _engine?.deleteAccount(password);
    _engine = null;
    status = SyncStatus.off;
    lastSync = null;
    pending = 0;
    notifyListeners();
  }

  // ------------------------------------------------------------------- sync
  /// Synchronizes now. [silent]: errors are only shown in [status].
  Future<void> syncNow({bool silent = false}) async {
    if (_engine == null) return;
    final running = _running;
    if (running != null) return running;
    final f = _sync(silent);
    _running = f;
    try {
      await f;
    } finally {
      _running = null;
    }
  }

  Future<void> _sync(bool silent) async {
    final engine = _engine!;
    _lastAttempt = DateTime.now();
    status = SyncStatus.syncing;
    notifyListeners();
    try {
      final report = await engine.sync();
      status = SyncStatus.idle;
      lastError = null;
      lastSync = await engine.lastSync();
      if (report.pulled > 0) {
        dataVersion++;
        await onRemoteChanges?.call();
      }
    } on SyncNetworkException catch (e) {
      status = SyncStatus.offline;
      lastError = e;
      if (!silent) rethrow;
    } on SyncAuthException catch (e) {
      lastError = e;
      if (e.sessionExpired) {
        // Signed out on the server: sign in again (local data kept).
        await engine.forgetAccount();
        _engine = null;
        status = SyncStatus.off;
      } else {
        status = SyncStatus.error;
      }
      if (!silent) rethrow;
    } finally {
      pending = _engine == null ? 0 : await engine.pendingCount();
      notifyListeners();
    }
  }
}
