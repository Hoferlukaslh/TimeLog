import 'sync_models.dart';

/// Online service storing the data of an account (to be implemented, e.g. a
/// REST API or a hosted database). Every call after sign-in is authenticated
/// with the [SyncSession] token; the password only travels in [signIn] and
/// [signUp] (over HTTPS) and is never stored by the app.
abstract interface class SyncBackend {
  /// Creates an account. Throws [SyncAuthException] if the e-mail is taken.
  Future<SyncSession> signUp(String email, String password);

  /// Throws [SyncAuthException] if the e-mail or the password is wrong.
  Future<SyncSession> signIn(String email, String password);

  Future<void> signOut(SyncSession session);

  /// Deletes the online account and all its data (password asked again).
  Future<void> deleteAccount(SyncSession session, String password);

  /// Sends the local changes of [deviceId].
  Future<void> push(SyncSession session, String deviceId, List<SyncChange> changes);

  /// Changes made by the other devices of the account since [cursor]
  /// (null: everything).
  Future<PullResult> pull(SyncSession session, String deviceId, String? cursor);
}
