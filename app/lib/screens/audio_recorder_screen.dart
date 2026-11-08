import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../platform/platform.dart';
import '../utils/ui.dart';

/// Result of an audio recording.
class AudioResult {
  final Uint8List bytes;
  final String extension;
  final String mime;
  AudioResult(this.bytes, this.extension, this.mime);
}

/// Simple recorder: one big button to start, one to stop. Pops with an
/// [AudioResult].
class AudioRecorderScreen extends StatefulWidget {
  const AudioRecorderScreen({super.key});

  @override
  State<AudioRecorderScreen> createState() => _AudioRecorderScreenState();
}

class _AudioRecorderScreenState extends State<AudioRecorderScreen> {
  final _rec = AudioRecorder();
  bool _recording = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  String _ext = 'm4a';
  String _mime = 'audio/mp4';
  String? _path;

  @override
  void dispose() {
    _timer?.cancel();
    _rec.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final l = context.l;
    try {
      if (!await _rec.hasPermission()) {
        if (mounted) context.toast(l.micPermissionDenied);
        return;
      }
      var encoder = AudioEncoder.aacLc;
      if (!await _rec.isEncoderSupported(encoder)) {
        // Browsers without AAC (Firefox) record Opus; WAV works everywhere but is big.
        final opus = kIsWeb && await _rec.isEncoderSupported(AudioEncoder.opus);
        encoder = opus ? AudioEncoder.opus : AudioEncoder.wav;
        _ext = opus ? 'webm' : 'wav';
        _mime = opus ? 'audio/webm' : 'audio/wav';
      }
      _path = await newRecordingPath(_ext);
      await _rec.start(RecordConfig(encoder: encoder, numChannels: 1), path: _path!);
      _elapsed = Duration.zero;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _elapsed += const Duration(seconds: 1));
      });
      setState(() => _recording = true);
    } catch (e) {
      if (mounted) context.toast(l.errorMessage('$e'));
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    final path = await _rec.stop() ?? _path;
    setState(() => _recording = false);
    if (path == null) return;
    final bytes = await takeRecording(path);
    if (mounted) Navigator.pop(context, AudioResult(bytes, _ext, _mime));
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_recording,
      child: Scaffold(
        appBar: AppBar(title: Text(l.audioRecorder)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_fmt(_elapsed), style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 8),
              Text(_recording ? l.recording : ''),
              const SizedBox(height: 32),
              SizedBox(
                width: 120,
                height: 120,
                child: FloatingActionButton.large(
                  heroTag: 'rec',
                  backgroundColor: _recording ? cs.error : cs.primaryContainer,
                  foregroundColor: _recording ? cs.onError : cs.onPrimaryContainer,
                  onPressed: _recording ? _stop : _start,
                  child: Icon(_recording ? Icons.stop : Icons.mic, size: 56),
                ),
              ),
              const SizedBox(height: 16),
              Text(_recording ? l.stopRecording : l.startRecording, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}
