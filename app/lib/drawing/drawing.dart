import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// MIME type of the vector drawings stored in the database.
const kDrawingMime = 'application/x-timelog-drawing+json';
const kDrawingExtension = 'tldraw';

/// Kind of element of a drawing.
enum ElementType { pen, erase, line, arrow, rect, circle, arc, fill }

/// One element of a vector drawing. Coordinates are in drawing units.
class DrawElement {
  final ElementType type;
  final int color;

  /// Base stroke width (shapes) — pen strokes store a width per point.
  final double width;

  /// pen / erase: [x, y, w, x, y, w, ...]
  /// line / arrow / rect: [x1, y1, x2, y2]
  /// circle: [cx, cy, r]
  /// arc: [x1, y1, x2, y2, tx, ty] (t = point the arc goes through)
  final List<double> data;

  /// fill: mask size and run-length encoded rows (see [FillMask]).
  final FillMask? mask;

  DrawElement({required this.type, required this.color, this.width = 4, List<double>? data, this.mask})
    : data = data ?? [];

  Map<String, Object?> toJson() => {
    't': type.name,
    'c': color,
    'w': _r(width),
    if (type != ElementType.fill) 'd': [for (final v in data) _r(v)],
    if (mask != null) 'm': mask!.toJson(),
  };

  factory DrawElement.fromJson(Map<String, Object?> j) => DrawElement(
    type: ElementType.values.firstWhere((e) => e.name == j['t'], orElse: () => ElementType.pen),
    color: (j['c'] as num).toInt(),
    width: (j['w'] as num?)?.toDouble() ?? 4,
    data: [for (final v in (j['d'] as List? ?? const [])) (v as num).toDouble()],
    mask: j['m'] == null ? null : FillMask.fromJson(Map<String, Object?>.from(j['m'] as Map)),
  );

  static num _r(double v) {
    final x = (v * 10).roundToDouble() / 10;
    return x == x.roundToDouble() ? x.toInt() : x;
  }

  /// Rough hit test, used by the object eraser.
  bool hits(Offset p, double tolerance) {
    double distSeg(Offset a, Offset b) {
      final ab = b - a;
      final len2 = ab.distanceSquared;
      if (len2 == 0) return (p - a).distance;
      final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
      return (p - (a + ab * t)).distance;
    }

    final tol = tolerance + width / 2;
    switch (type) {
      case ElementType.pen:
      case ElementType.erase:
        for (var i = 0; i + 2 < data.length; i += 3) {
          final a = Offset(data[i], data[i + 1]);
          final b = i + 5 < data.length ? Offset(data[i + 3], data[i + 4]) : a;
          if (distSeg(a, b) <= tolerance + data[i + 2] / 2) return true;
        }
        return false;
      case ElementType.line:
      case ElementType.arrow:
        return distSeg(Offset(data[0], data[1]), Offset(data[2], data[3])) <= tol;
      case ElementType.rect:
        final r = Rect.fromPoints(Offset(data[0], data[1]), Offset(data[2], data[3]));
        return distSeg(r.topLeft, r.topRight) <= tol ||
            distSeg(r.topRight, r.bottomRight) <= tol ||
            distSeg(r.bottomRight, r.bottomLeft) <= tol ||
            distSeg(r.bottomLeft, r.topLeft) <= tol;
      case ElementType.circle:
        return ((p - Offset(data[0], data[1])).distance - data[2]).abs() <= tol;
      case ElementType.arc:
        final pts = arcPoints(this, 48);
        for (var i = 0; i + 1 < pts.length; i++) {
          if (distSeg(pts[i], pts[i + 1]) <= tol) return true;
        }
        return false;
      case ElementType.fill:
        return mask?.contains(p) ?? false;
    }
  }
}

/// Region filled by the paint bucket, stored as a run-length encoded bitmap
/// (computed once when the user taps; replayed exactly afterwards).
class FillMask {
  /// Mask pixels per drawing unit.
  final double scale;
  final int w;
  final int h;

  /// For each row: [y, x0, x1, x0, x1, ...] (x1 exclusive). Only rows with pixels.
  final List<List<int>> rows;

  ui.Image? _image;
  int? _imageColor;

  FillMask(this.scale, this.w, this.h, this.rows);

  Map<String, Object?> toJson() => {'s': scale, 'w': w, 'h': h, 'r': rows};

  factory FillMask.fromJson(Map<String, Object?> j) =>
      FillMask((j['s'] as num).toDouble(), (j['w'] as num).toInt(), (j['h'] as num).toInt(), [
        for (final r in j['r'] as List) [for (final v in r as List) (v as num).toInt()],
      ]);

  bool contains(Offset p) {
    final x = (p.dx * scale).floor(), y = (p.dy * scale).floor();
    for (final r in rows) {
      if (r[0] != y) continue;
      for (var i = 1; i + 1 < r.length; i += 2) {
        if (x >= r[i] && x < r[i + 1]) return true;
      }
    }
    return false;
  }

  bool get isReady => _image != null;

  Future<void> prepare(int color) async {
    if (_image != null && _imageColor == color) return;
    final px = Uint8List(w * h * 4);
    final c = Color(color);
    final r = (c.r * 255).round(), g = (c.g * 255).round(), b = (c.b * 255).round();
    final a = (c.a * 255).round();
    for (final row in rows) {
      final y = row[0];
      for (var i = 1; i + 1 < row.length; i += 2) {
        for (var x = row[i]; x < row[i + 1]; x++) {
          final o = (y * w + x) * 4;
          // Premultiplied RGBA.
          px[o] = r * a ~/ 255;
          px[o + 1] = g * a ~/ 255;
          px[o + 2] = b * a ~/ 255;
          px[o + 3] = a;
        }
      }
    }
    final buf = await ui.ImmutableBuffer.fromUint8List(px);
    final desc = ui.ImageDescriptor.raw(buf, width: w, height: h, pixelFormat: ui.PixelFormat.rgba8888);
    final codec = await desc.instantiateCodec();
    _image = (await codec.getNextFrame()).image;
    _imageColor = color;
  }

  void paint(Canvas canvas) {
    final img = _image;
    if (img == null) return;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Rect.fromLTWH(0, 0, w / scale, h / scale),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
}

/// A complete vector drawing.
class Drawing {
  final double width;
  final double height;
  final int background;
  final List<DrawElement> elements;

  Drawing({required this.width, required this.height, this.background = 0xFFFFFFFF, List<DrawElement>? elements})
    : elements = elements ?? [];

  Uint8List encode() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'v': 1,
        'w': width,
        'h': height,
        'bg': background,
        'el': [for (final e in elements) e.toJson()],
      }),
    ),
  );

  factory Drawing.decode(Uint8List bytes) {
    final j = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
    return Drawing(
      width: (j['w'] as num).toDouble(),
      height: (j['h'] as num).toDouble(),
      background: (j['bg'] as num?)?.toInt() ?? 0xFFFFFFFF,
      elements: [for (final e in j['el'] as List) DrawElement.fromJson(Map<String, Object?>.from(e as Map))],
    );
  }

  /// Decodes the fill bitmaps; must be awaited before painting fills.
  Future<void> prepare() async {
    for (final e in elements) {
      if (e.type == ElementType.fill) await e.mask?.prepare(e.color);
    }
  }

  bool get isPrepared => elements.every((e) => e.type != ElementType.fill || (e.mask?.isReady ?? true));

  /// Renders the drawing to PNG (used for exports / saving a copy).
  Future<Uint8List> toPng({double pixelRatio = 2}) async {
    await prepare();
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.scale(pixelRatio);
    DrawingRenderer.paintAll(canvas, this);
    final img = await rec.endRecording().toImage((width * pixelRatio).ceil(), (height * pixelRatio).ceil());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  /// Raw RGBA pixels of the drawing at [scale] (for the paint bucket).
  Future<(Uint8List, int, int)> rasterize(double scale) async {
    await prepare();
    final w = (width * scale).ceil(), h = (height * scale).ceil();
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.scale(scale);
    DrawingRenderer.paintAll(canvas, this);
    final img = await rec.endRecording().toImage(w, h);
    final data = await img.toByteData();
    return (data!.buffer.asUint8List(), w, h);
  }

  /// Computes the paint bucket region at [p]; returns null if nothing to fill.
  Future<FillMask?> computeFill(Offset p, {double scale = 2}) async {
    final (px, w, h) = await rasterize(scale);
    final sx = (p.dx * scale).floor(), sy = (p.dy * scale).floor();
    if (sx < 0 || sy < 0 || sx >= w || sy >= h) return null;
    final rows = floodFill(px, w, h, sx, sy);
    return rows.isEmpty ? null : FillMask(scale, w, h, rows);
  }

  /// Scanline flood fill on RGBA pixels from (sx, sy). Pixels similar to the
  /// seed colour are filled; the region is grown by 1 pixel to cover the
  /// anti-aliased border of the surrounding strokes.
  static List<List<int>> floodFill(Uint8List px, int w, int h, int sx, int sy, {int tolerance = 96}) {
    final seed = (sy * w + sx) * 4;
    final r0 = px[seed], g0 = px[seed + 1], b0 = px[seed + 2], a0 = px[seed + 3];
    bool similar(int i) {
      final o = i * 4;
      return (px[o] - r0).abs() + (px[o + 1] - g0).abs() + (px[o + 2] - b0).abs() + (px[o + 3] - a0).abs() <= tolerance;
    }

    final filled = Uint8List(w * h);
    final stack = <int>[sx, sy];
    while (stack.isNotEmpty) {
      final y = stack.removeLast();
      final x = stack.removeLast();
      var i = y * w + x;
      if (filled[i] == 1 || !similar(i)) continue;
      var x0 = x;
      while (x0 > 0 && filled[i - 1] == 0 && similar(i - 1)) {
        x0--;
        i--;
      }
      var x1 = x;
      var j = y * w + x;
      while (x1 < w - 1 && filled[j + 1] == 0 && similar(j + 1)) {
        x1++;
        j++;
      }
      for (var xx = x0; xx <= x1; xx++) {
        filled[y * w + xx] = 1;
      }
      for (final ny in [y - 1, y + 1]) {
        if (ny < 0 || ny >= h) continue;
        var inRun = false;
        for (var xx = x0; xx <= x1; xx++) {
          final k = ny * w + xx;
          final ok = filled[k] == 0 && similar(k);
          if (ok && !inRun) {
            stack
              ..add(xx)
              ..add(ny);
          }
          inRun = ok;
        }
      }
    }
    // Dilate by one pixel.
    final grown = Uint8List.fromList(filled);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (filled[y * w + x] == 0) continue;
        if (x > 0) grown[y * w + x - 1] = 1;
        if (x < w - 1) grown[y * w + x + 1] = 1;
        if (y > 0) grown[(y - 1) * w + x] = 1;
        if (y < h - 1) grown[(y + 1) * w + x] = 1;
      }
    }
    final rows = <List<int>>[];
    for (var y = 0; y < h; y++) {
      List<int>? row;
      var x = 0;
      while (x < w) {
        if (grown[y * w + x] == 1) {
          final start = x;
          while (x < w && grown[y * w + x] == 1) {
            x++;
          }
          (row ??= [y]).addAll([start, x]);
        } else {
          x++;
        }
      }
      if (row != null) rows.add(row);
    }
    return rows;
  }
}

/// Points of an arc element (for hit testing).
List<Offset> arcPoints(DrawElement e, int n) {
  final a = Offset(e.data[0], e.data[1]), b = Offset(e.data[2], e.data[3]), t = Offset(e.data[4], e.data[5]);
  final c = _circumcenter(a, t, b);
  if (c == null) return [a, b];
  final r = (a - c).distance;
  final (start, sweep) = _arcAngles(a, b, t, c);
  return [
    for (var i = 0; i <= n; i++) c + Offset(math.cos(start + sweep * i / n), math.sin(start + sweep * i / n)) * r,
  ];
}

Offset? _circumcenter(Offset a, Offset b, Offset c) {
  final d = 2 * (a.dx * (b.dy - c.dy) + b.dx * (c.dy - a.dy) + c.dx * (a.dy - b.dy));
  if (d.abs() < 1e-6) return null;
  final a2 = a.dx * a.dx + a.dy * a.dy, b2 = b.dx * b.dx + b.dy * b.dy, c2 = c.dx * c.dx + c.dy * c.dy;
  return Offset(
    (a2 * (b.dy - c.dy) + b2 * (c.dy - a.dy) + c2 * (a.dy - b.dy)) / d,
    (a2 * (c.dx - b.dx) + b2 * (a.dx - c.dx) + c2 * (b.dx - a.dx)) / d,
  );
}

/// Start angle and sweep of the arc from a to b passing through t.
(double, double) _arcAngles(Offset a, Offset b, Offset t, Offset c) {
  double ang(Offset p) => math.atan2(p.dy - c.dy, p.dx - c.dx);
  final sa = ang(a), sb = ang(b), st = ang(t);
  double norm(double x) {
    while (x < 0) {
      x += 2 * math.pi;
    }
    while (x >= 2 * math.pi) {
      x -= 2 * math.pi;
    }
    return x;
  }

  final ccwToB = norm(sb - sa), ccwToT = norm(st - sa);
  // If t lies on the positive sweep from a to b, go that way; otherwise the other way.
  return ccwToT <= ccwToB ? (sa, ccwToB) : (sa, ccwToB - 2 * math.pi);
}

class DrawingRenderer {
  /// Paints the background and all elements (erasers are applied inside a layer).
  static void paintAll(Canvas canvas, Drawing d, {DrawElement? extra}) {
    final bounds = Rect.fromLTWH(0, 0, d.width, d.height);
    canvas.drawRect(bounds, Paint()..color = Color(d.background));
    canvas.saveLayer(bounds, Paint());
    for (final e in d.elements) {
      paintElement(canvas, e);
    }
    if (extra != null) paintElement(canvas, extra);
    canvas.restore();
  }

  static void paintElement(Canvas canvas, DrawElement e) {
    final paint = Paint()
      ..color = Color(e.color)
      ..strokeWidth = e.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    final d = e.data;
    switch (e.type) {
      case ElementType.pen:
      case ElementType.erase:
        if (e.type == ElementType.erase) {
          paint
            ..blendMode = BlendMode.clear
            ..color = const Color(0xFF000000);
        }
        _paintVariableStroke(canvas, d, paint);
      case ElementType.line:
        canvas.drawLine(Offset(d[0], d[1]), Offset(d[2], d[3]), paint);
      case ElementType.arrow:
        final a = Offset(d[0], d[1]), b = Offset(d[2], d[3]);
        canvas.drawLine(a, b, paint);
        final len = (b - a).distance;
        if (len > 0) {
          final head = math.min(len * 0.5, 10 + e.width * 3);
          final ang = math.atan2(b.dy - a.dy, b.dx - a.dx);
          final path = Path()
            ..moveTo(b.dx + head * math.cos(ang + math.pi * 0.85), b.dy + head * math.sin(ang + math.pi * 0.85))
            ..lineTo(b.dx, b.dy)
            ..lineTo(b.dx + head * math.cos(ang - math.pi * 0.85), b.dy + head * math.sin(ang - math.pi * 0.85));
          canvas.drawPath(path, paint);
        }
      case ElementType.rect:
        canvas.drawRect(Rect.fromPoints(Offset(d[0], d[1]), Offset(d[2], d[3])), paint);
      case ElementType.circle:
        canvas.drawCircle(Offset(d[0], d[1]), d[2], paint);
      case ElementType.arc:
        final a = Offset(d[0], d[1]), b = Offset(d[2], d[3]), t = Offset(d[4], d[5]);
        final c = _circumcenter(a, t, b);
        if (c == null) {
          canvas.drawLine(a, b, paint);
        } else {
          final (start, sweep) = _arcAngles(a, b, t, c);
          canvas.drawArc(Rect.fromCircle(center: c, radius: (a - c).distance), start, sweep, false, paint);
        }
      case ElementType.fill:
        e.mask?.paint(canvas);
    }
  }

  /// Pen stroke whose width varies point by point (simulated pressure).
  static void _paintVariableStroke(Canvas canvas, List<double> d, Paint paint) {
    final n = d.length ~/ 3;
    if (n == 0) return;
    if (n == 1) {
      canvas.drawCircle(
        Offset(d[0], d[1]),
        d[2] / 2,
        Paint()
          ..color = paint.color
          ..blendMode = paint.blendMode,
      );
      return;
    }
    // Quadratic smoothing through segment midpoints, one segment per width.
    Offset pt(int i) => Offset(d[i * 3], d[i * 3 + 1]);
    double wd(int i) => d[i * 3 + 2];
    var prevMid = pt(0);
    for (var i = 1; i < n; i++) {
      final mid = i == n - 1 ? pt(i) : (pt(i) + pt(i + 1)) / 2;
      final path = Path()
        ..moveTo(prevMid.dx, prevMid.dy)
        ..quadraticBezierTo(pt(i).dx, pt(i).dy, mid.dx, mid.dy);
      paint.strokeWidth = (wd(i - 1) + wd(i)) / 2;
      canvas.drawPath(path, paint);
      prevMid = mid;
    }
  }
}
