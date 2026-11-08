import 'dart:convert';
import 'dart:typed_data';

/// One row changed on a device, as exchanged with the server.
class SyncChange {
  final String table;

  /// Global id of the row (see SyncSchema).
  final String uid;
  final bool deleted;

  /// Business columns of the row; references to other rows are uids.
  final Map<String, Object?> values;

  /// Columns changed by this change (used to merge edits made on two devices).
  final Set<String> columns;

  /// Time of the change, in milliseconds since epoch.
  final int modifiedAt;
  final String deviceId;

  /// New content of an attachment file, if it changed.
  final Uint8List? data;

  /// Time of the last change of each column (sent by the server), used to
  /// merge column by column. Missing column: [modifiedAt].
  final Map<String, int> columnTimes;

  const SyncChange({
    required this.table,
    required this.uid,
    this.deleted = false,
    this.values = const {},
    this.columns = const {},
    required this.modifiedAt,
    required this.deviceId,
    this.data,
    this.columnTimes = const {},
  });

  int timeOf(String column) => columnTimes[column] ?? modifiedAt;

  Map<String, Object?> toJson() => {
    'table': table,
    'uid': uid,
    if (deleted) 'deleted': true,
    if (!deleted) 'values': values,
    if (!deleted) 'columns': columns.toList(),
    'modified_at': modifiedAt,
    'device_id': deviceId,
    if (data != null) 'data': base64Encode(data!),
  };

  factory SyncChange.fromJson(Map<String, Object?> j) => SyncChange(
    table: j['table']! as String,
    uid: j['uid']! as String,
    deleted: j['deleted'] == true,
    values: Map<String, Object?>.from((j['values'] as Map<String, Object?>?) ?? const {}),
    columns: {for (final c in (j['columns'] as List<Object?>?) ?? const []) c! as String},
    modifiedAt: (j['modified_at']! as num).toInt(),
    deviceId: j['device_id']! as String,
    data: j['data'] == null ? null : base64Decode(j['data']! as String),
    columnTimes: {
      for (final e in ((j['column_times'] as Map<String, Object?>?) ?? const {}).entries)
        e.key: (e.value! as num).toInt(),
    },
  );
}

/// Signed-in account. The password is never stored: only the session token.
class SyncSession {
  final String accountId;
  final String email;
  final String token;

  const SyncSession({required this.accountId, required this.email, required this.token});
}

/// Changes received from the server and the position to resume from.
class PullResult {
  final List<SyncChange> changes;
  final String cursor;

  /// More changes are waiting: pull again from [cursor].
  final bool hasMore;

  const PullResult(this.changes, this.cursor, {this.hasMore = false});
}

/// Result of one synchronization.
class SyncReport {
  final int pushed;
  final int pulled;

  const SyncReport({required this.pushed, required this.pulled});

  @override
  String toString() => 'SyncReport(pushed: $pushed, pulled: $pulled)';
}

/// Refused by the server: wrong e-mail / password, expired session, e-mail
/// already used... [code] is the error code of the API (see server/API.md).
class SyncAuthException implements Exception {
  final String code;
  const SyncAuthException(this.code);

  /// The session is not valid anymore: the user has to sign in again.
  bool get sessionExpired => code == 'unauthorized';

  @override
  String toString() => 'SyncAuthException: $code';
}

/// The server cannot be reached (no network, wrong address, server down...).
/// Nothing is lost: the changes are sent at the next synchronization.
class SyncNetworkException implements Exception {
  final String message;
  const SyncNetworkException(this.message);

  @override
  String toString() => 'SyncNetworkException: $message';
}
