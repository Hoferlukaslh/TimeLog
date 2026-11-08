import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../drawing/drawing.dart';
import '../models/models.dart';
import '../screens/drawing_screen.dart';
import '../utils/dates.dart';
import '../utils/ui.dart';

/// In-memory cache of attachment bytes (they come from SQLite).
///
/// Least recently used entries are dropped above [maxBytes], so that browsing
/// many photos does not keep them all in memory.
class AttachmentCache {
  @visibleForTesting
  static int maxBytes = 64 * 1024 * 1024;
  static final _futures = <int, Future<Uint8List>>{};

  /// Loaded entries, in least -> most recently used order.
  static final _sizes = <int, int>{};
  static int _total = 0;

  static Future<Uint8List> get(int id) {
    final f = _futures[id];
    if (f != null) {
      // Mark as most recently used.
      final size = _sizes.remove(id);
      if (size != null) _sizes[id] = size;
      return f;
    }
    final future = Repository.instance.attachmentData(id).then((data) {
      if (_futures.containsKey(id)) {
        _sizes[id] = data.length;
        _total += data.length;
        _trim(keep: id);
      }
      return data;
    });
    _futures[id] = future;
    // A failed load must not stay in the cache (callers still get the error).
    unawaited(future.then<void>((_) {}, onError: (Object _) => _futures.remove(id)));
    return future;
  }

  static void _trim({required int keep}) {
    while (_total > maxBytes && _sizes.length > 1) {
      final oldest = _sizes.keys.firstWhere((k) => k != keep);
      evict(oldest);
    }
  }

  static void evict(int id) {
    _futures.remove(id);
    _total -= _sizes.remove(id) ?? 0;
  }

  static void clear() {
    _futures.clear();
    _sizes.clear();
    _total = 0;
  }
}

IconData attachmentIcon(AttachmentKind k) {
  switch (k) {
    case AttachmentKind.photo:
      return Icons.photo_outlined;
    case AttachmentKind.audio:
      return Icons.mic_none;
    case AttachmentKind.drawing:
      return Icons.draw_outlined;
    case AttachmentKind.document:
      return Icons.description_outlined;
  }
}

class AttachmentThumb extends StatelessWidget {
  final Attachment attachment;
  final double size;
  const AttachmentThumb({super.key, required this.attachment, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (attachment.isVectorDrawing) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: size,
          height: size,
          color: Colors.white,
          child: FutureBuilder<Uint8List>(
            future: AttachmentCache.get(attachment.id!),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              try {
                return DrawingView(drawing: Drawing.decode(snap.data!));
              } catch (_) {
                return const Icon(Icons.broken_image_outlined);
              }
            },
          ),
        ),
      );
    }
    if (!attachment.isImage) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(8)),
        child: Icon(attachmentIcon(attachment.kind), color: cs.onSecondaryContainer),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: FutureBuilder<Uint8List>(
        future: AttachmentCache.get(attachment.id!),
        builder: (context, snap) {
          if (!snap.hasData) {
            return Container(width: size, height: size, color: cs.surfaceContainerHighest);
          }
          return Image.memory(
            snap.data!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: (size * 3).round(),
            errorBuilder: (_, _, _) =>
                SizedBox(width: size, height: size, child: const Icon(Icons.broken_image_outlined)),
          );
        },
      ),
    );
  }
}

/// Full screen image viewer with zoom.
class ImageViewerScreen extends StatelessWidget {
  final Attachment attachment;
  const ImageViewerScreen({super.key, required this.attachment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(attachment.fileName)),
      body: FutureBuilder<Uint8List>(
        future: AttachmentCache.get(attachment.id!),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return InteractiveViewer(maxScale: 8, child: Center(child: Image.memory(snap.data!)));
        },
      ),
    );
  }
}

/// Small audio player for an attachment.
class AudioPlayerTile extends StatefulWidget {
  final Attachment attachment;
  final Widget? trailing;
  const AudioPlayerTile({super.key, required this.attachment, this.trailing});

  @override
  State<AudioPlayerTile> createState() => _AudioPlayerTileState();
}

class _AudioPlayerTileState extends State<AudioPlayerTile> {
  final _player = AudioPlayer();
  final _subs = <StreamSubscription<Object?>>[];
  PlayerState _state = PlayerState.stopped;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;
  bool _sourceSet = false;

  @override
  void initState() {
    super.initState();
    _subs.add(_player.onPlayerStateChanged.listen((s) => setState(() => _state = s)));
    _subs.add(_player.onPositionChanged.listen((p) => setState(() => _pos = p)));
    _subs.add(_player.onDurationChanged.listen((d) => setState(() => _dur = d)));
    _subs.add(_player.onPlayerComplete.listen((_) => setState(() => _pos = Duration.zero)));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (_state == PlayerState.playing) {
        await _player.pause();
        return;
      }
      if (!_sourceSet) {
        final bytes = await AttachmentCache.get(widget.attachment.id!);
        final f = await Files.toTemp('${widget.attachment.id}_${widget.attachment.fileName}', bytes);
        await _player.setSource(DeviceFileSource(f.path, mimeType: widget.attachment.mime));
        _sourceSet = true;
      }
      await _player.resume();
    } catch (e) {
      if (mounted) context.toast(context.l.errorMessage('$e'));
    }
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final playing = _state == PlayerState.playing;
    final max = _dur.inMilliseconds.toDouble();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            IconButton.filledTonal(
              tooltip: playing ? context.l.pause : context.l.play,
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              onPressed: _toggle,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 4),
                    child: Text(widget.attachment.fileName, overflow: TextOverflow.ellipsis),
                  ),
                  Slider(
                    value: max <= 0 ? 0 : _pos.inMilliseconds.clamp(0, max).toDouble(),
                    max: max <= 0 ? 1 : max,
                    onChanged: max <= 0 ? null : (v) => _player.seek(Duration(milliseconds: v.round())),
                  ),
                ],
              ),
            ),
            Text('${_fmt(_pos)} / ${_fmt(_dur)}', style: Theme.of(context).textTheme.bodySmall),
            ?widget.trailing,
          ],
        ),
      ),
    );
  }
}

/// Generic list tile for a document / any attachment.
class DocumentTile extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback onTap;
  final Widget? trailing;
  const DocumentTile({super.key, required this.attachment, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: AttachmentThumb(attachment: attachment, size: 44),
        title: Text(attachment.fileName, overflow: TextOverflow.ellipsis),
        subtitle: Text(Fmt.fileSize(attachment.size)),
        onTap: onTap,
        trailing: trailing,
      ),
    );
  }
}
