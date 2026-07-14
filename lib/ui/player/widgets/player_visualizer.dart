import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../domain/audio/audio_visualizer_controller.dart';
import '../../../domain/playback/playback_snapshot.dart';
import '../../core/motion/edmm_motion.dart';
import '../../core/themes/edmm_theme_extensions.dart';

/// Keeps native spectrum support discovery alive without presenting frames.
///
/// The repo-local just_audio fork updates `audioSpectrumSupportStream` from
/// inside the lazy native subscription owned by `audioSpectrumStream`. While
/// the unavailable UI is visible, this probe supplies that required spectrum
/// listener so a later native supported event can reach the ViewModel.
class PlayerSpectrumRecoveryProbe extends StatefulWidget {
  const PlayerSpectrumRecoveryProbe({super.key, required this.spectrum});

  final Stream<AudioSpectrumFrame> spectrum;

  @override
  State<PlayerSpectrumRecoveryProbe> createState() =>
      _PlayerSpectrumRecoveryProbeState();
}

class _PlayerSpectrumRecoveryProbeState
    extends State<PlayerSpectrumRecoveryProbe> {
  StreamSubscription<AudioSpectrumFrame>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant PlayerSpectrumRecoveryProbe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spectrum != widget.spectrum) {
      unawaited(_subscription?.cancel());
      _subscribe();
    }
  }

  void _subscribe() {
    _subscription = widget.spectrum.listen(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class PlayerVisualizer extends StatefulWidget {
  const PlayerVisualizer({
    super.key,
    required this.spectrum,
    this.status = PlaybackStatus.playing,
    this.visible = true,
    this.reduceMotion = false,
  });

  final Stream<AudioSpectrumFrame> spectrum;
  final PlaybackStatus status;
  final bool visible;
  final bool reduceMotion;

  @override
  State<PlayerVisualizer> createState() => _PlayerVisualizerState();
}

class _PlayerVisualizerState extends State<PlayerVisualizer> {
  static const List<double> _initialMagnitudes = <double>[
    0.12,
    0.18,
    0.14,
    0.22,
    0.16,
    0.2,
    0.13,
    0.17,
  ];

  StreamSubscription<AudioSpectrumFrame>? _subscription;
  AudioSpectrumFrame? _lastFrame;
  Duration? _lastPresentedTimestamp;

  bool get _shouldSubscribe =>
      widget.visible && widget.status == PlaybackStatus.playing;

  @override
  void initState() {
    super.initState();
    _syncSubscription();
  }

  @override
  void didUpdateWidget(covariant PlayerVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spectrum != widget.spectrum ||
        oldWidget.status != widget.status ||
        oldWidget.visible != widget.visible ||
        oldWidget.reduceMotion != widget.reduceMotion) {
      _syncSubscription();
    }
  }

  void _syncSubscription() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _lastPresentedTimestamp = null;
    if (!_shouldSubscribe) return;

    _subscription = widget.spectrum.listen((frame) {
      if (!mounted || !_shouldSubscribe) return;
      final previousTimestamp = _lastPresentedTimestamp;
      if (widget.reduceMotion && previousTimestamp != null) {
        final elapsed = frame.timestamp - previousTimestamp;
        if (!elapsed.isNegative && elapsed < EdmmMotion.emphasis) return;
      }
      _lastPresentedTimestamp = frame.timestamp;
      setState(() => _lastFrame = frame);
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    if (!_shouldSubscribe) {
      return const _StaticSpectrumBaseline();
    }

    return RepaintBoundary(
      key: const Key('player-visualizer-repaint-boundary'),
      child: AudioSpectrumVisualizer(
        key: const Key('player-visualizer-bars'),
        magnitudes: _lastFrame?.magnitudes ?? _initialMagnitudes,
      ),
    );
  }
}

class _StaticSpectrumBaseline extends StatelessWidget {
  const _StaticSpectrumBaseline();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).edmm.playbackActive.withValues(alpha: 0.28);
    return Align(
      key: const Key('player-visualizer-static'),
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: 8,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List<Widget>.generate(
            12,
            (index) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AudioSpectrumVisualizer extends StatelessWidget {
  const AudioSpectrumVisualizer({super.key, required this.magnitudes});

  final List<double> magnitudes;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _VisualizerPainter(
        magnitudes: magnitudes,
        color: Theme.of(context).edmm.playbackActive,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _VisualizerPainter extends CustomPainter {
  const _VisualizerPainter({required this.magnitudes, required this.color});

  final List<double> magnitudes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final barCount = magnitudes.length;
    if (barCount == 0 || size.isEmpty) return;
    final gap = size.width / (barCount * 3);
    final barWidth = (size.width - gap * (barCount - 1)) / barCount;
    final segmentHeight = math.min(4.0, math.max(2.0, barWidth * 0.42));
    const segmentGap = 2.0;

    for (var i = 0; i < barCount; i++) {
      final normalized = magnitudes[i].clamp(0.0, 1.0);
      final targetHeight = size.height * normalized;
      final left = i * (barWidth + gap);
      var drawnHeight = 0.0;
      while (drawnHeight < targetHeight) {
        final height = math.min(segmentHeight, targetHeight - drawnHeight);
        final bottom = size.height - drawnHeight;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, bottom - height, barWidth, height),
            Radius.circular(math.min(2.0, barWidth / 2)),
          ),
          paint,
        );
        drawnHeight += segmentHeight + segmentGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VisualizerPainter oldDelegate) {
    return !listEquals(oldDelegate.magnitudes, magnitudes) ||
        oldDelegate.color != color;
  }
}
