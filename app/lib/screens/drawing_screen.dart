import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../drawing/drawing.dart';
import '../utils/ui.dart';
import '../widgets/eraser_icon.dart';

enum DrawTool { pen, line, arrow, rect, circle, arc, fill, eraser, objectEraser }

/// Vector drawing editor. Pops with the edited [Drawing] (or null if unchanged).
class DrawingScreen extends StatefulWidget {
  final Drawing? initial;
  const DrawingScreen({super.key, this.initial});

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  static const _colors = <int>[
    0xFF000000,
    0xFF616161,
    0xFFD32F2F,
    0xFFF57C00,
    0xFFFBC02D,
    0xFF388E3C,
    0xFF1976D2,
    0xFF7B1FA2,
    0xFF6D4C41,
    0xFFFFFFFF,
  ];

  Drawing? _d;
  final _undo = <List<DrawElement>>[];
  final _redo = <List<DrawElement>>[];
  bool _changed = false;
  bool _busy = false;

  DrawTool _tool = DrawTool.pen;
  int _color = _colors.first;
  double _width = 4;
  bool _pressure = true;

  // Element being drawn.
  DrawElement? _current;
  int? _pointer;
  Offset? _start;
  Offset? _lastPos;
  Duration? _lastTime;
  double _lastW = 4;

  // Arc whose curvature can still be adjusted with its handle.
  DrawElement? _editableArc;
  bool _draggingArcHandle = false;

  // View transform (drawing units -> screen).
  double _scale = 1;
  Offset _offset = Offset.zero;

  ui.Picture? _committed;

  @override
  void initState() {
    super.initState();
    _d = widget.initial;
    _d?.prepare().then((_) {
      if (mounted) _invalidate();
    });
  }

  @override
  void dispose() {
    _committed?.dispose();
    super.dispose();
  }

  void _invalidate() {
    _committed?.dispose();
    _committed = null;
    setState(() {});
  }

  ui.Picture _picture() {
    return _committed ??= () {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      for (final e in _d!.elements) {
        DrawingRenderer.paintElement(c, e);
      }
      return rec.endRecording();
    }();
  }

  void _snapshot() {
    _undo.add(List.of(_d!.elements));
    _redo.clear();
    _changed = true;
  }

  void _doUndo() {
    if (_undo.isEmpty) return;
    _redo.add(List.of(_d!.elements));
    _d!.elements
      ..clear()
      ..addAll(_undo.removeLast());
    _editableArc = null;
    _changed = true;
    _invalidate();
  }

  void _doRedo() {
    if (_redo.isEmpty) return;
    _undo.add(List.of(_d!.elements));
    _d!.elements
      ..clear()
      ..addAll(_redo.removeLast());
    _changed = true;
    _invalidate();
  }

  Offset _toDrawing(Offset screen) => (screen - _offset) / _scale;

  /// Snaps a segment to 0 / 45 / 90° when close.
  Offset _snap(Offset a, Offset b) {
    final v = b - a;
    final len = v.distance;
    if (len < 1) return b;
    final ang = math.atan2(v.dy, v.dx);
    const step = math.pi / 4;
    final snapped = (ang / step).round() * step;
    if ((ang - snapped).abs() < 5 * math.pi / 180) {
      return a + Offset(math.cos(snapped), math.sin(snapped)) * len;
    }
    return b;
  }

  double _penWidth(PointerEvent ev, double dist, double dtMs) {
    if (ev.kind == PointerDeviceKind.stylus && ev.pressureMax > ev.pressureMin) {
      final p = ((ev.pressure - ev.pressureMin) / (ev.pressureMax - ev.pressureMin)).clamp(0.0, 1.0);
      return _width * (0.3 + 1.4 * p);
    }
    if (!_pressure) return _width;
    // Faster = thinner. Speed in screen pixels per millisecond.
    final speed = dtMs <= 0 ? 0.0 : dist * _scale / dtMs;
    final factor = (1.5 / (1 + speed * 1.1)).clamp(0.3, 1.5);
    final target = _width * factor;
    return _lastW + (target - _lastW) * 0.35;
  }

  void _onDown(PointerDownEvent ev) {
    if (_pointer != null || _busy) return;
    _pointer = ev.pointer;
    final p = _toDrawing(ev.localPosition);
    _start = p;
    _lastPos = p;
    _lastTime = ev.timeStamp;
    switch (_tool) {
      case DrawTool.pen:
        _lastW = _pressure ? _width * 0.9 : _width;
        _current = DrawElement(type: ElementType.pen, color: _color, width: _width, data: [p.dx, p.dy, _lastW]);
      case DrawTool.eraser:
        _current = DrawElement(type: ElementType.erase, color: 0, width: _width * 4, data: [p.dx, p.dy, _width * 4]);
      case DrawTool.line:
      case DrawTool.arrow:
      case DrawTool.rect:
        _current = DrawElement(
          type: {
            DrawTool.line: ElementType.line,
            DrawTool.arrow: ElementType.arrow,
            DrawTool.rect: ElementType.rect,
          }[_tool]!,
          color: _color,
          width: _width,
          data: [p.dx, p.dy, p.dx, p.dy],
        );
      case DrawTool.circle:
        _current = DrawElement(type: ElementType.circle, color: _color, width: _width, data: [p.dx, p.dy, 0]);
      case DrawTool.arc:
        final arc = _editableArc;
        if (arc != null && (Offset(arc.data[4], arc.data[5]) - p).distance * _scale < 28) {
          _snapshot();
          // Work on a copy so that undo restores the previous curvature.
          final copy = DrawElement(type: arc.type, color: arc.color, width: arc.width, data: List.of(arc.data));
          final i = _d!.elements.indexOf(arc);
          if (i >= 0) _d!.elements[i] = copy;
          _editableArc = copy;
          _draggingArcHandle = true;
        } else {
          _editableArc = null;
          _current = DrawElement(
            type: ElementType.arc,
            color: _color,
            width: _width,
            data: [p.dx, p.dy, p.dx, p.dy, p.dx, p.dy],
          );
        }
      case DrawTool.objectEraser:
        _snapshot();
        _eraseObjectsAt(p);
      case DrawTool.fill:
        break;
    }
    setState(() {});
  }

  void _eraseObjectsAt(Offset p) {
    final before = _d!.elements.length;
    _d!.elements.removeWhere((e) => e.hits(p, 10 / _scale));
    if (_d!.elements.length != before) _invalidate();
  }

  void _onMove(PointerMoveEvent ev) {
    if (ev.pointer != _pointer) return;
    final p = _toDrawing(ev.localPosition);
    final cur = _current;
    switch (_tool) {
      case DrawTool.pen:
      case DrawTool.eraser:
        final dist = (p - _lastPos!).distance;
        if (dist * _scale < 1) return;
        final dt = (ev.timeStamp - _lastTime!).inMicroseconds / 1000;
        final w = _tool == DrawTool.eraser ? _width * 4 : _penWidth(ev, dist, dt);
        _lastW = w;
        cur!.data.addAll([p.dx, p.dy, w]);
        _lastPos = p;
        _lastTime = ev.timeStamp;
      case DrawTool.line:
      case DrawTool.arrow:
        final b = _snap(_start!, p);
        cur!.data
          ..[2] = b.dx
          ..[3] = b.dy;
      case DrawTool.rect:
        cur!.data
          ..[2] = p.dx
          ..[3] = p.dy;
      case DrawTool.circle:
        cur!.data[2] = (p - _start!).distance;
      case DrawTool.arc:
        if (_draggingArcHandle) {
          _editableArc!.data
            ..[4] = p.dx
            ..[5] = p.dy;
          _invalidate();
          return;
        }
        // Default: half circle on the left of the chord.
        final a = _start!;
        final mid = (a + p) / 2;
        final v = p - a;
        final normal = Offset(v.dy, -v.dx) / 2;
        cur!.data
          ..[2] = p.dx
          ..[3] = p.dy
          ..[4] = mid.dx + normal.dx
          ..[5] = mid.dy + normal.dy;
      case DrawTool.objectEraser:
        _eraseObjectsAt(p);
        return;
      case DrawTool.fill:
        return;
    }
    setState(() {});
  }

  Future<void> _onUp(PointerEvent ev) async {
    if (ev.pointer != _pointer) return;
    _pointer = null;
    final cur = _current;
    _current = null;
    _draggingArcHandle = false;
    if (_tool == DrawTool.fill) {
      await _fill(_toDrawing(ev.localPosition));
      return;
    }
    if (cur == null) {
      setState(() {});
      return;
    }
    if (cur.type == ElementType.pen) _taper(cur);
    final tiny = switch (cur.type) {
      ElementType.line ||
      ElementType.arrow ||
      ElementType.rect ||
      ElementType.arc => (Offset(cur.data[0], cur.data[1]) - Offset(cur.data[2], cur.data[3])).distance * _scale < 3,
      ElementType.circle => cur.data[2] * _scale < 2,
      _ => false,
    };
    if (!tiny) {
      _snapshot();
      _d!.elements.add(cur);
      if (cur.type == ElementType.arc) _editableArc = cur;
    }
    _invalidate();
  }

  /// Thin out the end of a pen stroke, like a real pen lifting.
  void _taper(DrawElement e) {
    if (!_pressure) return;
    final n = e.data.length ~/ 3;
    for (var k = 0; k < math.min(4, n - 1); k++) {
      final i = (n - 1 - k) * 3 + 2;
      e.data[i] *= 0.55 + 0.1 * k;
    }
  }

  Future<void> _fill(Offset p) async {
    final d = _d!;
    if (p.dx < 0 || p.dy < 0 || p.dx > d.width || p.dy > d.height) return;
    setState(() => _busy = true);
    try {
      final mask = await d.computeFill(p);
      if (mask != null) {
        await mask.prepare(_color);
        _snapshot();
        d.elements.add(DrawElement(type: ElementType.fill, color: _color, mask: mask));
        _editableArc = null;
      }
    } finally {
      if (mounted) {
        _busy = false;
        _invalidate();
      }
    }
  }

  /// ✓ button: the only way to save the drawing.
  void _save() {
    Navigator.pop(context, _changed ? _d : null);
  }

  /// Back: leaves without saving; asks for confirmation if something changed.
  Future<void> _leave() async {
    if (_changed) {
      final l = context.l;
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded),
          title: Text(l.discardDrawingTitle),
          content: Text(l.discardDrawingMessage),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.keepDrawing)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.discardDrawing),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    Navigator.pop(context);
  }

  String _toolLabel(DrawTool t) {
    final l = context.l;
    return switch (t) {
      DrawTool.pen => l.toolPen,
      DrawTool.line => l.toolLine,
      DrawTool.arrow => l.toolArrow,
      DrawTool.rect => l.toolRect,
      DrawTool.circle => l.toolCircle,
      DrawTool.arc => l.toolArc,
      DrawTool.fill => l.toolFill,
      DrawTool.eraser => l.eraser,
      DrawTool.objectEraser => l.toolObjectEraser,
    };
  }

  static IconData _toolIcon(DrawTool t) => switch (t) {
    DrawTool.pen => Icons.edit,
    DrawTool.line => Icons.horizontal_rule,
    DrawTool.arrow => Icons.north_east,
    DrawTool.rect => Icons.crop_square,
    DrawTool.circle => Icons.circle_outlined,
    DrawTool.arc => Icons.looks,
    DrawTool.fill => Icons.format_color_fill,
    // Erasers use the custom EraserIcon.
    DrawTool.eraser || DrawTool.objectEraser => Icons.circle,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.drawingTitle),
          actions: [
            IconButton(tooltip: l.undo, icon: const Icon(Icons.undo), onPressed: _undo.isEmpty ? null : _doUndo),
            IconButton(tooltip: l.redo, icon: const Icon(Icons.redo), onPressed: _redo.isEmpty ? null : _doRedo),
            IconButton(
              tooltip: l.clearDrawing,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: (_d?.elements.isEmpty ?? true)
                  ? null
                  : () async {
                      if (await Pickers.confirm(context)) {
                        _snapshot();
                        _d!.elements.clear();
                        _editableArc = null;
                        _invalidate();
                      }
                    },
            ),
            IconButton(tooltip: l.save, icon: const Icon(Icons.check), onPressed: _save),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ColoredBox(
                color: cs.surfaceContainerHighest,
                child: LayoutBuilder(
                  builder: (context, c) {
                    _d ??= Drawing(width: c.maxWidth, height: c.maxHeight);
                    final d = _d!;
                    _scale = math.min(c.maxWidth / d.width, c.maxHeight / d.height);
                    _offset = Offset((c.maxWidth - d.width * _scale) / 2, (c.maxHeight - d.height * _scale) / 2);
                    return Listener(
                      key: const ValueKey('drawing-canvas'),
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _onDown,
                      onPointerMove: _onMove,
                      onPointerUp: _onUp,
                      onPointerCancel: _onUp,
                      child: ClipRect(
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _EditorPainter(
                            drawing: d,
                            committed: _picture(),
                            current: _current,
                            scale: _scale,
                            offset: _offset,
                            handle: _tool == DrawTool.arc && _editableArc != null
                                ? Offset(_editableArc!.data[4], _editableArc!.data[5])
                                : null,
                            handleColor: cs.primary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Fixed height so the canvas never changes size while drawing.
            SizedBox(height: 4, child: _busy ? const LinearProgressIndicator() : null),
            _toolbar(context),
          ],
        ),
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    final l = context.l;
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Material(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  for (final t in DrawTool.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: _toolLabel(t),
                        isSelected: _tool == t,
                        style: IconButton.styleFrom(
                          backgroundColor: _tool == t ? cs.primaryContainer : null,
                          foregroundColor: _tool == t ? cs.onPrimaryContainer : null,
                        ),
                        icon: switch (t) {
                          DrawTool.eraser => const EraserIcon(),
                          DrawTool.objectEraser => const EraserIcon(objects: true),
                          _ => Icon(_toolIcon(t)),
                        },
                        onPressed: () => setState(() {
                          _tool = t;
                          if (t != DrawTool.arc) _editableArc = null;
                        }),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  _tool == DrawTool.arc && _editableArc != null ? l.arcHint : _toolLabel(_tool),
                  style: Theme.of(context).textTheme.labelMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final c in _colors)
                      GestureDetector(
                        onTap: () => setState(() {
                          _color = c;
                          if (_tool == DrawTool.eraser || _tool == DrawTool.objectEraser) _tool = DrawTool.pen;
                        }),
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              width: _color == c ? 4 : 1,
                              color: _color == c ? cs.primary : cs.outline,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  Tooltip(
                    message: l.pressureSim,
                    child: FilterChip(
                      avatar: const Icon(Icons.speed, size: 18),
                      label: Text(l.pressureShort),
                      selected: _pressure,
                      onSelected: (v) => setState(() => _pressure = v),
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      min: 1,
                      max: 24,
                      value: _width,
                      label: _width.toStringAsFixed(0),
                      divisions: 23,
                      onChanged: (v) => setState(() => _width = v),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: Center(
                      child: Container(
                        width: _width.clamp(2, 28),
                        height: _width.clamp(2, 28),
                        decoration: BoxDecoration(
                          color: Color(_color),
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.outline, width: 0.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorPainter extends CustomPainter {
  final Drawing drawing;
  final ui.Picture committed;
  final DrawElement? current;
  final double scale;
  final Offset offset;
  final Offset? handle;
  final Color handleColor;

  _EditorPainter({
    required this.drawing,
    required this.committed,
    required this.current,
    required this.scale,
    required this.offset,
    required this.handle,
    required this.handleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);
    final bounds = Rect.fromLTWH(0, 0, drawing.width, drawing.height);
    canvas.drawRect(bounds, Paint()..color = Color(drawing.background));
    canvas.clipRect(bounds);
    canvas.saveLayer(bounds, Paint());
    canvas.drawPicture(committed);
    if (current != null) DrawingRenderer.paintElement(canvas, current!);
    canvas.restore();
    if (handle != null) {
      canvas.drawCircle(handle!, 10 / scale, Paint()..color = handleColor.withValues(alpha: 0.3));
      canvas.drawCircle(handle!, 5 / scale, Paint()..color = handleColor);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Read-only rendering of a drawing scaled to the available space.
class DrawingView extends StatefulWidget {
  final Drawing drawing;
  const DrawingView({super.key, required this.drawing});

  @override
  State<DrawingView> createState() => _DrawingViewState();
}

class _DrawingViewState extends State<DrawingView> {
  @override
  void initState() {
    super.initState();
    if (!widget.drawing.isPrepared) {
      widget.drawing.prepare().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.drawing;
    return FittedBox(
      child: SizedBox(
        width: d.width,
        height: d.height,
        child: CustomPaint(painter: _ViewPainter(d)),
      ),
    );
  }
}

class _ViewPainter extends CustomPainter {
  final Drawing d;
  _ViewPainter(this.d);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    DrawingRenderer.paintAll(canvas, d);
  }

  @override
  bool shouldRepaint(covariant _ViewPainter old) => old.d != d;
}
