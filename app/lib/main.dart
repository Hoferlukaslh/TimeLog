import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'data/database.dart';
import 'l10n/gen/app_localizations.dart';
import 'platform/platform.dart';
import 'screens/home_shell.dart';
import 'services/categories_store.dart';
import 'services/settings.dart';
import 'services/widget_sync.dart';
import 'sync/sync_controller.dart';
import 'widgets/attachment_views.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  await AppDatabase.instance.open();
  unawaited(clearTempFiles());
  final settings = AppSettings();
  await settings.load();
  final categories = CategoriesStore();
  await categories.load();
  // Online synchronization (only active once an account is connected).
  final sync = SyncController(
    AppDatabase.instance.db,
    onRemoteChanges: () async {
      AttachmentCache.clear(); // a file may have been replaced on another device
      await settings.load();
      await categories.load();
      await WidgetSync.refresh();
    },
  );
  await sync.start();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: categories),
        ChangeNotifierProvider.value(value: sync),
      ],
      child: const TimeLogApp(),
    ),
  );
}

class TimeLogApp extends StatelessWidget {
  const TimeLogApp({super.key});

  ThemeData _theme(Color seed, Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: b);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      cardTheme: const CardThemeData(clipBehavior: Clip.antiAlias),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final seed = Color(s.accentColor);
    return MaterialApp(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx).appTitle,
      debugShowCheckedModeBanner: false,
      theme: _theme(seed, Brightness.light),
      darkTheme: _theme(seed, Brightness.dark),
      themeMode: s.themeMode,
      locale: s.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: s.use24h),
        child: child!,
      ),
      home: const HomeShell(),
    );
  }
}
