import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'sync_backend.dart';
import 'sync_models.dart';

/// Client of the TimeLog server API (server/ folder, see server/API.md).
class HttpSyncBackend implements SyncBackend {
  final Uri base;
  final http.Client _client;
  static const _timeout = Duration(seconds: 30);
  static const _transferTimeout = Duration(minutes: 5);

  HttpSyncBackend(String serverUrl, {http.Client? client})
    : base = normalizeUrl(serverUrl),
      _client = client ?? http.Client();

  /// "example.com" -> "https://example.com/api/v1/"
  static Uri normalizeUrl(String url) {
    var u = url.trim();
    if (!u.contains('://')) u = 'https://$u';
    u = u.replaceAll(RegExp(r'/+$'), '');
    if (!u.endsWith('/api/v1')) u = '$u/api/v1';
    return Uri.parse('$u/');
  }

  /// True when the password would travel unencrypted (http:// outside this machine).
  static bool isInsecure(String url) {
    final u = normalizeUrl(url);
    return u.scheme == 'http' && !{'localhost', '127.0.0.1', '::1'}.contains(u.host);
  }

  Future<Map<String, Object?>> _send(
    String method,
    String path, {
    SyncSession? session,
    Object? body,
    Map<String, String>? query,
    Duration timeout = _timeout,
  }) async {
    final uri = base.resolve(path).replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers['Accept'] = 'application/json'
      ..headers['Content-Type'] = 'application/json';
    if (session != null) request.headers['Authorization'] = 'Bearer ${session.token}';
    if (body != null) request.body = jsonEncode(body);
    http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request).timeout(timeout));
    } on TimeoutException {
      throw const SyncNetworkException('timeout');
    } on Exception catch (e) {
      // Connection refused, TLS failure, request blocked by the browser...
      throw SyncNetworkException(e is http.ClientException ? e.message : '$e');
    }
    Map<String, Object?> json = const {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, Object?>) json = decoded;
      } on FormatException {
        // Not our API (wrong address?).
        throw const SyncNetworkException('not_timelog_server');
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return json;
    final code = (json['error'] as String?) ?? 'http_${response.statusCode}';
    if (response.statusCode >= 500 || response.statusCode == 404) throw SyncNetworkException(code);
    throw SyncAuthException(code);
  }

  SyncSession _session(Map<String, Object?> j) =>
      SyncSession(accountId: j['account_id']! as String, email: j['email']! as String, token: j['token']! as String);

  /// Checks that the address is a TimeLog server.
  Future<void> checkServer() async {
    final j = await _send('GET', 'health');
    if (j['app'] != 'TimeLog') throw const SyncNetworkException('not_timelog_server');
  }

  @override
  Future<SyncSession> signUp(String email, String password) async =>
      _session(await _send('POST', 'auth/signup', body: {'email': email, 'password': password}));

  @override
  Future<SyncSession> signIn(String email, String password) async =>
      _session(await _send('POST', 'auth/login', body: {'email': email, 'password': password}));

  @override
  Future<void> signOut(SyncSession session) => _send('POST', 'auth/logout', session: session);

  @override
  Future<void> deleteAccount(SyncSession session, String password) =>
      _send('POST', 'account/delete', session: session, body: {'password': password});

  @override
  Future<void> push(SyncSession session, String deviceId, List<SyncChange> changes) => _send(
    'POST',
    'sync/push',
    session: session,
    body: {
      'device_id': deviceId,
      'changes': [for (final c in changes) c.toJson()],
    },
    timeout: _transferTimeout,
  );

  @override
  Future<PullResult> pull(SyncSession session, String deviceId, String? cursor) async {
    final j = await _send(
      'GET',
      'sync/pull',
      session: session,
      query: {'device_id': deviceId, 'cursor': ?cursor},
      timeout: _transferTimeout,
    );
    return PullResult(
      [for (final c in (j['changes'] as List<Object?>?) ?? const []) SyncChange.fromJson(c! as Map<String, Object?>)],
      j['cursor']! as String,
      hasMore: j['has_more'] == true,
    );
  }
}
