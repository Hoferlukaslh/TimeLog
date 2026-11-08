import 'dart:convert';

import 'package:timelog/sync/sync_backend.dart';
import 'package:timelog/sync/sync_models.dart';

/// Fake online service for the tests: accounts and change log in memory.
/// Changes go through JSON, like with a real server.
class MemorySyncBackend implements SyncBackend {
  final _passwords = <String, String>{}; // email -> password (test only!)
  final _accounts = <String, String>{}; // email -> account id
  final _tokens = <String, String>{}; // token -> account id
  final _log = <String, List<(String, String)>>{}; // account -> [(device, json)]
  var _tokenSeq = 0;

  /// When false, every call fails like without network.
  bool online = true;

  void _checkOnline() {
    if (!online) throw const SyncNetworkException('offline');
  }

  String _account(SyncSession s) {
    _checkOnline();
    return _tokens[s.token] ?? (throw const SyncAuthException('unauthorized'));
  }

  SyncSession _session(String email) {
    final token = 'token-${++_tokenSeq}';
    _tokens[token] = _accounts[email]!;
    return SyncSession(accountId: _accounts[email]!, email: email, token: token);
  }

  @override
  Future<SyncSession> signUp(String email, String password) async {
    _checkOnline();
    if (_accounts.containsKey(email)) throw const SyncAuthException('email_taken');
    _accounts[email] = 'acc-${_accounts.length + 1}';
    _passwords[email] = password;
    return _session(email);
  }

  @override
  Future<SyncSession> signIn(String email, String password) async {
    _checkOnline();
    if (_passwords[email] != password) throw const SyncAuthException('invalid_credentials');
    return _session(email);
  }

  @override
  Future<void> signOut(SyncSession session) async => _tokens.remove(session.token);

  @override
  Future<void> deleteAccount(SyncSession session, String password) async {
    final account = _account(session);
    final email = _accounts.entries.firstWhere((e) => e.value == account).key;
    if (_passwords[email] != password) throw const SyncAuthException('invalid_credentials');
    _accounts.remove(email);
    _passwords.remove(email);
    _log.remove(account);
    _tokens.removeWhere((_, a) => a == account);
  }

  @override
  Future<void> push(SyncSession session, String deviceId, List<SyncChange> changes) async {
    final log = _log.putIfAbsent(_account(session), () => []);
    for (final c in changes) {
      log.add((deviceId, jsonEncode(c.toJson())));
    }
  }

  @override
  Future<PullResult> pull(SyncSession session, String deviceId, String? cursor) async {
    final log = _log[_account(session)] ?? const [];
    final from = cursor == null ? 0 : int.parse(cursor);
    final changes = [
      for (var i = from; i < log.length; i++)
        if (log[i].$1 != deviceId) SyncChange.fromJson(jsonDecode(log[i].$2) as Map<String, Object?>),
    ];
    return PullResult(changes, '${log.length}');
  }
}
