import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/settings.dart';

/// App logo drawn in the accent colour chosen in the settings:
/// rounded square with a slight vertical gradient + the white calendar.
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final accent = Color(context.watch<AppSettings>().accentColor);
    final darker = Color.lerp(accent, Colors.black, 0.35)!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        // Same corner ratio as the original logo (215 / 1024).
        borderRadius: BorderRadius.circular(size * 0.21),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [accent, darker]),
      ),
      child: Image.asset('assets/logo_glyph.png', width: size, height: size),
    );
  }
}
