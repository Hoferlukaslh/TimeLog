import 'package:flutter/material.dart';

/// Layout rules for large screens (computer, browser, tablet).
///
/// Everything here only applies on a "roomy" screen: telephones, including in
/// landscape where the width can exceed 900, keep the compact layout.
abstract final class Responsive {
  /// Width of the window from which the menu stays visible.
  static const sidebarFrom = 900.0;
  static const sidebarWidth = 264.0;

  /// Width of the content from which screens use two columns.
  static const twoColumnsFrom = 820.0;

  /// Lower than this, the device is a telephone in landscape.
  static const _minHeight = 500.0;

  static bool isRoomy(BuildContext context) => MediaQuery.sizeOf(context).height >= _minHeight;

  static bool showsSidebar(BuildContext context) => isRoomy(context) && MediaQuery.sizeOf(context).width >= sidebarFrom;

  static bool twoColumns(BuildContext context, double contentWidth) =>
      isRoomy(context) && contentWidth >= twoColumnsFrom;
}

/// A [ListView] whose content keeps a readable width on large screens. The
/// scrollbar and the mouse wheel still work on the whole width.
class CenteredListView extends StatelessWidget {
  final EdgeInsets padding;
  final double maxWidth;
  final List<Widget> children;

  const CenteredListView({super.key, this.padding = EdgeInsets.zero, this.maxWidth = 760, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final inner = maxWidth + padding.horizontal;
        final side = Responsive.isRoomy(context) && c.maxWidth > inner ? (c.maxWidth - inner) / 2 : 0.0;
        return ListView(
          padding: padding.add(EdgeInsets.symmetric(horizontal: side)),
          children: children,
        );
      },
    );
  }
}

/// Keeps a widget (toolbar, form) at a readable width, centered.
class CenteredBox extends StatelessWidget {
  final double maxWidth;
  final Widget child;
  const CenteredBox({super.key, this.maxWidth = 760, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
