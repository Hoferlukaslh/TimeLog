import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';
import '../utils/ui.dart';
import '../widgets/app_logo.dart';

class AboutScreen extends StatelessWidget {
  final Widget? drawer;
  const AboutScreen({super.key, this.drawer});

  /// Opens a link (browser / e-mail app); copies it if no app can open it.
  static Future<void> _open(BuildContext context, Uri uri) async {
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on PlatformException {
      ok = false;
    }
    if (!ok && context.mounted) {
      await _copy(context, uri.scheme == 'mailto' ? uri.path : uri.toString());
    }
  }

  static Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) context.toast(context.l.copied);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      drawer: drawer,
      appBar: AppBar(title: Text(l.menuAbout)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Center(child: AppLogo(size: 112)),
                  const SizedBox(height: 12),
                  Text(l.appTitle, textAlign: TextAlign.center, style: t.headlineMedium),
                  Text(l.version(AppInfo.appVersion), textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Text(l.aboutText, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(l.author),
                          subtitle: const Text(AppInfo.authorName),
                        ),
                        ListTile(
                          leading: const Icon(Icons.mail_outline),
                          title: Text(l.contact),
                          subtitle: const Text(AppInfo.authorEmail),
                          onTap: () => _open(context, Uri(scheme: 'mailto', path: AppInfo.authorEmail)),
                          trailing: IconButton(
                            tooltip: l.copy,
                            icon: const Icon(Icons.copy),
                            onPressed: () => _copy(context, AppInfo.authorEmail),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.code),
                          title: Text(l.sourceCode),
                          subtitle: const Text(AppInfo.sourceUrl),
                          onTap: () => _open(context, Uri.parse(AppInfo.sourceUrl)),
                          trailing: IconButton(
                            tooltip: l.copy,
                            icon: const Icon(Icons.copy),
                            onPressed: () => _copy(context, AppInfo.sourceUrl),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Licenses button pinned at the bottom.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.description_outlined),
                  label: Text(l.licenses),
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: l.appTitle,
                    applicationVersion: AppInfo.appVersion,
                    applicationLegalese: '© ${AppInfo.authorName} — ${AppInfo.license}',
                    applicationIcon: const Padding(padding: EdgeInsets.all(8), child: AppLogo(size: 64)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
