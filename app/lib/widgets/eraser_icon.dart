import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Eraser icon (the Material icon set has none). Uses the current [IconTheme].
/// With [objects], a small shape is shown next to it (erase whole shapes).
class EraserIcon extends StatelessWidget {
  final bool objects;
  const EraserIcon({super.key, this.objects = false});

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = theme.size ?? 24;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _EraserPainter(theme.color ?? Colors.black, objects)),
    );
  }
}

class _EraserPainter extends CustomPainter {
  final Color color;
  final bool objects;
  _EraserPainter(this.color, this.objects);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * s
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = color;

    // Floor line.
    canvas.drawLine(Offset(4 * s, 21 * s), Offset(20 * s, 21 * s), stroke);

    // Tilted eraser block: rubber part filled, sleeve outlined.
    canvas.save();
    canvas.translate(12 * s, 11 * s);
    canvas.rotate(-math.pi / 4);
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 18 * s, height: 9 * s),
      Radius.circular(2 * s),
    );
    canvas.drawRRect(body, stroke);
    canvas.clipRRect(body);
    canvas.drawRect(Rect.fromLTRB(-9 * s, -4.5 * s, -2 * s, 4.5 * s), fill);
    canvas.restore();

    if (objects) {
      // Small shape being erased.
      canvas.drawCircle(Offset(5 * s, 5 * s), 3.5 * s, stroke..strokeWidth = 1.6 * s);
    }
  }

  @override
  bool shouldRepaint(covariant _EraserPainter old) => old.color != color || old.objects != objects;
}
