import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../platform/platform.dart';
import '../sync/sync_controller.dart';
import '../utils/ui.dart';
import '../widgets/app_logo.dart';
import '../widgets/responsive.dart';
import 'about_screen.dart';
import 'categories_screen.dart';
import 'export_screen.dart';
import 'hours_screen.dart';
import 'journal_screen.dart';
import 'notes_screen.dart';
import 'settings_screen.dart';
import 'sync_screen.dart';
import 'vacation_screen.dart';

enum Section { hours, vacation, journal, notes, categories, export, sync, settings, about }

/// Root of the app: shows the selected section. The menu is a drawer opened
/// with the button at the top left of every section on small screens, and a
/// permanent sidebar on large ones.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  Section _section = Section.hours;

  static const _digits = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  @override
  void initState() {
    super.initState();
    // Not in the browser, where Ctrl+digit selects a tab.
    if (Host.isDesktopApp) HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    if (Host.isDesktopApp) HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  /// Ctrl+1 ... Ctrl+9: go to a section (in the order of the menu).
  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent || !HardwareKeyboard.instance.isControlPressed) return false;
    final i = _digits.indexOf(e.logicalKey);
    // Only on the main page: not behind an open note, a dialog...
    if (i < 0 || i >= Section.values.length || ModalRoute.of(context)?.isCurrent != true) return false;
    _select(Section.values[i]);
    return true;
  }

  void _select(Section s) => setState(() => _section = s);

  @override
  Widget build(BuildContext context) {
    final sidebar = Responsive.showsSidebar(context);
    // Data received from another device: the section is rebuilt (reloaded).
    final version = context.select((SyncController s) => s.dataVersion);
    return Row(
      children: [
        if (sidebar) ...[
          SizedBox(
            width: Responsive.sidebarWidth,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: _AppMenu(current: _section, onSelect: _select),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
        ],
        // The key keeps the section (and what is being typed) when the window
        // is resized across the width where the sidebar appears.
        Expanded(
          key: const ValueKey('section'),
          child: KeyedSubtree(
            key: ValueKey('$_section-$version'),
            child: _screen(sidebar ? null : AppDrawer(current: _section, onSelect: _select)),
          ),
        ),
      ],
    );
  }

  Widget _screen(Widget? drawer) {
    switch (_section) {
      case Section.hours:
        return HoursScreen(drawer: drawer);
      case Section.vacation:
        return VacationScreen(drawer: drawer);
      case Section.journal:
        return JournalScreen(drawer: drawer);
      case Section.notes:
        return NotesScreen(drawer: drawer);
      case Section.categories:
        return CategoriesScreen(drawer: drawer);
      case Section.export:
        return ExportScreen(drawer: drawer);
      case Section.sync:
        return SyncScreen(drawer: drawer);
      case Section.settings:
        return SettingsScreen(drawer: drawer);
      case Section.about:
        return AboutScreen(drawer: drawer);
    }
  }
}

class AppDrawer extends StatelessWidget {
  final Section current;
  final ValueChanged<Section> onSelect;

  const AppDrawer({super.key, required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: _AppMenu(
        current: current,
        onSelect: (s) {
          Navigator.pop(context);
          onSelect(s);
        },
      ),
    );
  }
}

/// Content of the menu: in the drawer or in the sidebar.
class _AppMenu extends StatelessWidget {
  final Section current;
  final ValueChanged<Section> onSelect;

  const _AppMenu({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final main = <(Section, IconData, String)>[
      (Section.hours, Icons.schedule, l.menuHours),
      (Section.vacation, Icons.beach_access, l.menuVacation),
      (Section.journal, Icons.menu_book, l.menuJournal),
      (Section.notes, Icons.sticky_note_2_outlined, l.menuNotes),
    ];
    // Second part, pinned at the bottom of the menu.
    final bottom = <(Section, IconData, String)>[
      (Section.categories, Icons.label_outline, l.menuCategories),
      (Section.export, Icons.ios_share, l.menuExport),
      (Section.sync, Icons.cloud_sync_outlined, l.menuSync),
      (Section.settings, Icons.settings_outlined, l.menuSettings),
      (Section.about, Icons.info_outline, l.menuAbout),
    ];
    Widget item((Section, IconData, String) e) =>
        _DrawerItem(icon: e.$2, label: e.$3, selected: e.$1 == current, onTap: () => onSelect(e.$1));

    return SafeArea(
      child: LayoutBuilder(
        // Scrolls only when the screen is too small for the whole menu.
        builder: (context, c) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 16, 16, 16),
                    child: Row(
                      children: [
                        const AppLogo(),
                        const SizedBox(width: 12),
                        Text(l.appTitle, style: Theme.of(context).textTheme.headlineSmall),
                      ],
                    ),
                  ),
                  for (final e in main) item(e),
                  const Spacer(),
                  const Divider(indent: 28, endIndent: 28),
                  for (final e in bottom) item(e),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Menu entry styled like a Material 3 navigation drawer destination.
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = selected ? cs.onSecondaryContainer : cs.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? cs.secondaryContainer : Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(icon, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: fg, fontWeight: selected ? FontWeight.bold : null),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
