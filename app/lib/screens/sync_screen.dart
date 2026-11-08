import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../sync/http_sync_backend.dart';
import '../sync/sync_controller.dart';
import '../sync/sync_models.dart';
import '../utils/ui.dart';
import '../widgets/responsive.dart';

/// Localized message of a synchronization error.
String syncErrorMessage(BuildContext context, Object? error) {
  final l = context.l;
  return switch (error) {
    SyncAuthException(code: 'invalid_credentials') => l.syncErrInvalidCredentials,
    SyncAuthException(code: 'email_taken') => l.syncErrEmailTaken,
    SyncAuthException(code: 'invalid_email') => l.syncErrInvalidEmail,
    SyncAuthException(code: 'weak_password') => l.syncErrWeakPassword,
    SyncAuthException(code: 'too_many_attempts') => l.syncErrTooMany,
    SyncAuthException(code: 'unauthorized') => l.syncSessionExpired,
    SyncAuthException(:final code) => l.syncErrOther(code),
    SyncNetworkException(message: 'not_timelog_server') => l.syncErrNotServer,
    SyncNetworkException() => l.syncErrNetwork,
    FormatException() => l.syncErrNotServer,
    _ => l.syncErrOther('$error'),
  };
}

/// Account and status of the online synchronization.
class SyncScreen extends StatelessWidget {
  final Widget? drawer;
  const SyncScreen({super.key, this.drawer});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final sync = context.watch<SyncController>();
    return Scaffold(
      drawer: drawer,
      appBar: AppBar(title: Text(l.menuSync)),
      body: CenteredListView(
        maxWidth: 640,
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_sync_outlined, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(l.syncIntro)),
            ],
          ),
          const SizedBox(height: 16),
          if (sync.signedIn) const _AccountView() else const _LoginForm(),
        ],
      ),
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm();

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _server = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final sync = context.read<SyncController>();
    // In the browser the API is served by the same address as the application.
    _server.text = kIsWeb ? Uri.base.origin : sync.serverUrl ?? '';
    _email.text = sync.email ?? '';
    final e = sync.lastError;
    if (e is SyncAuthException && e.sessionExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _error = context.l.syncSessionExpired);
      });
    }
  }

  @override
  void dispose() {
    _server.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool create}) async {
    if (_server.text.trim().isEmpty || _email.text.trim().isEmpty || _password.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<SyncController>().signIn(_server.text, _email.text, _password.text, create: create);
      _password.clear();
    } on Exception catch (e) {
      if (mounted) setState(() => _error = syncErrorMessage(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final cs = Theme.of(context).colorScheme;
    final insecure = _server.text.trim().isNotEmpty && HttpSyncBackend.isInsecure(_server.text);
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!kIsWeb)
            TextField(
              controller: _server,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l.syncServer,
                hintText: l.syncServerHint,
                prefixIcon: const Icon(Icons.dns_outlined),
              ),
              onChanged: (_) => setState(() {}),
            ),
          if (insecure)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: cs.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l.syncInsecure, style: TextStyle(color: cs.error)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const [AutofillHints.email, AutofillHints.username],
            decoration: InputDecoration(labelText: l.email, prefixIcon: const Icon(Icons.mail_outline)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: _hide,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: l.password,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: l.showPassword,
                icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
            onSubmitted: (_) => _submit(create: false),
          ),
          const SizedBox(height: 8),
          Text(l.syncMergeInfo, style: Theme.of(context).textTheme.bodySmall),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: cs.error)),
            ),
          const SizedBox(height: 16),
          if (_busy) const Padding(padding: EdgeInsets.only(bottom: 12), child: LinearProgressIndicator()),
          FilledButton.icon(
            onPressed: _busy ? null : () => _submit(create: false),
            icon: const Icon(Icons.login),
            label: Text(l.signIn),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _submit(create: true),
            icon: const Icon(Icons.person_add_alt),
            label: Text(l.signUp),
          ),
        ],
      ),
    );
  }
}

class _AccountView extends StatelessWidget {
  const _AccountView();

  Future<void> _deleteAccount(BuildContext context) async {
    final l = context.l;
    final ctrl = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: Text(l.syncDeleteAccount),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.syncDeleteAccountMessage),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(labelText: l.password),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (password == null || password.isEmpty || !context.mounted) return;
    try {
      await context.read<SyncController>().deleteAccount(password);
      if (context.mounted) context.toast(l.syncAccountDeleted);
    } on Exception catch (e) {
      if (context.mounted) context.toast(syncErrorMessage(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final sync = context.watch<SyncController>();
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final (IconData icon, Color color, String text) = switch (sync.status) {
      SyncStatus.syncing => (Icons.sync, cs.primary, l.syncRunning),
      SyncStatus.offline => (Icons.cloud_off_outlined, cs.tertiary, l.syncOffline),
      SyncStatus.error => (Icons.error_outline, cs.error, syncErrorMessage(context, sync.lastError)),
      _ =>
        sync.lastSync == null
            ? (Icons.cloud_queue, cs.outline, l.syncNever)
            : (
                Icons.cloud_done_outlined,
                Colors.green.shade600,
                l.syncLast(
                  '${DateFormat.yMd(context.localeName).format(sync.lastSync!)} '
                  '${TimeOfDay.fromDateTime(sync.lastSync!).format(context)}',
                ),
              ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 32),
                    const SizedBox(width: 12),
                    Expanded(child: Text(text, style: t.titleSmall)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(sync.pending == 0 ? l.syncUpToDate : l.syncPending(sync.pending), style: t.bodySmall),
                const SizedBox(height: 12),
                if (sync.status == SyncStatus.syncing) const LinearProgressIndicator(),
                FilledButton.icon(
                  onPressed: sync.status == SyncStatus.syncing
                      ? null
                      : () async {
                          try {
                            await sync.syncNow();
                          } on Exception catch (e) {
                            if (context.mounted) context.toast(syncErrorMessage(context, e));
                          }
                        },
                  icon: const Icon(Icons.sync),
                  label: Text(l.syncNow),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(l.syncAccount),
                subtitle: Text(sync.email ?? ''),
              ),
              ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: Text(l.syncServer),
                subtitle: Text(sync.serverUrl ?? ''),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.logout),
          label: Text(l.signOut),
          onPressed: () async {
            if (await Pickers.confirm(context, title: l.signOut, message: l.syncSignOutConfirm)) {
              await sync.signOut();
            }
          },
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: cs.error),
          icon: const Icon(Icons.delete_forever_outlined),
          label: Text(l.syncDeleteAccount),
          onPressed: () => _deleteAccount(context),
        ),
      ],
    );
  }
}
