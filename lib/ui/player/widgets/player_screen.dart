import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../domain/audio/audio_effects_controller.dart';
import '../../../domain/audio/audio_visualizer_controller.dart';
import '../../../domain/playback/playback_snapshot.dart';
import '../../../domain/result.dart';
import '../../../l10n/app_localizations.dart';
import '../view_model/player_view_model.dart';

String formatPlaybackDuration(Duration duration) {
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (duration.inHours > 0) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '${duration.inHours}:$minutes:$seconds';
  }
  return '${duration.inMinutes.toString().padLeft(2, '0')}:$seconds';
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.viewModel,
    this.onClose,
    this.disposeViewModel = true,
  });
  final PlayerViewModel viewModel;
  final VoidCallback? onClose;
  final bool disposeViewModel;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  static const double _dismissThreshold = 120;
  static const double _maxContentWidth = 560;

  String? _lastErrorToastToken;
  double _dragOffset = 0;
  double _snapFrom = 0;
  late final AnimationController _snapController;

  @override
  void initState() {
    super.initState();
    _snapController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addListener(() {
          final t = Curves.easeOut.transform(_snapController.value);
          setState(() => _dragOffset = _snapFrom * (1 - t));
        });
  }

  @override
  void dispose() {
    _snapController.dispose();
    if (widget.disposeViewModel) {
      widget.viewModel.dispose();
    }
    super.dispose();
  }

  IconData _volumeIcon(PlayerViewModel vm) {
    if (vm.isMuted || vm.volume <= 0) return Icons.volume_off;
    if (vm.volume < 0.5) return Icons.volume_down;
    return Icons.volume_up;
  }

  String _statusText(AppLocalizations l10n, PlaybackStatus status) =>
      switch (status) {
        PlaybackStatus.idle => l10n.playbackStatusIdle,
        PlaybackStatus.loading => l10n.playbackStatusLoading,
        PlaybackStatus.ready => l10n.playbackStatusReady,
        PlaybackStatus.playing => l10n.playbackStatusPlaying,
        PlaybackStatus.paused => l10n.playbackStatusPaused,
        PlaybackStatus.completed => l10n.playbackStatusCompleted,
        PlaybackStatus.error => l10n.playbackStatusError,
      };

  String _errorText(AppLocalizations l10n, Failure failure) =>
      switch (failure) {
        NetworkFailure() => l10n.playbackErrorNetwork,
        ServerFailure(:final statusCode) => l10n.playbackErrorServer(
          statusCode,
        ),
        ParseFailure() => l10n.playbackErrorInvalidData,
      };

  void _closePlayer() {
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _handleCloseDragStart(DragStartDetails _) {
    _snapController.stop();
  }

  void _handleCloseDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = math.max(0, _dragOffset + (details.primaryDelta ?? 0));
    });
  }

  void _handleCloseDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dragOffset > _dismissThreshold || velocity > 800) {
      _closePlayer();
      return;
    }
    // 임계값 미만이면 원위치로 스냅백.
    _snapFrom = _dragOffset;
    _snapController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: widget.onClose == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _closePlayer();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Transform.translate(
          offset: Offset(0, _dragOffset),
          child: Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SafeArea(
              child: Column(
                children: [
                  GestureDetector(
                    key: const Key('player-close-drag-area'),
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: _handleCloseDragStart,
                    onVerticalDragUpdate: _handleCloseDragUpdate,
                    onVerticalDragEnd: _handleCloseDragEnd,
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: Center(
                        child: IconButton(
                          key: const Key('player-close-button'),
                          icon: const Icon(Icons.keyboard_arrow_down),
                          tooltip: l10n.playerDismiss,
                          onPressed: _closePlayer,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: ListenableBuilder(
                        listenable: widget.viewModel,
                        builder: (context, _) {
                          final vm = widget.viewModel;
                          final track = vm.snapshot.currentTrack;
                          if (!vm.shouldShowErrorBanner) {
                            _lastErrorToastToken = null;
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (vm.shouldShowErrorBanner) ...[
                                Builder(
                                  builder: (context) {
                                    final errorToken = vm.latestErrorToken;
                                    if (errorToken != null &&
                                        errorToken != _lastErrorToastToken) {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).clearSnackBars();
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  _errorText(
                                                    l10n,
                                                    vm.snapshot.error!,
                                                  ),
                                                ),
                                                duration: const Duration(
                                                  seconds: 4,
                                                ),
                                              ),
                                            );
                                          });
                                      _lastErrorToastToken = errorToken;
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                                MaterialBanner(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.errorContainer,
                                  content: Text(
                                    _errorText(l10n, vm.snapshot.error!),
                                  ),
                                  actions: [
                                    if (vm.canRetryPlayback)
                                      TextButton(
                                        onPressed: vm.retryPlayback,
                                        child: Text(l10n.retry),
                                      ),
                                    TextButton(
                                      onPressed: vm.dismissError,
                                      child: Text(l10n.playerDismiss),
                                    ),
                                  ],
                                ),
                              ],
                              if (track == null)
                                Expanded(
                                  child: Center(
                                    child: Text(l10n.playerNoTrackLoaded),
                                  ),
                                )
                              else
                                Expanded(child: _buildExpandedBody(vm, l10n)),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedBody(PlayerViewModel vm, AppLocalizations l10n) {
    final track = vm.snapshot.currentTrack!;
    final visualizerAvailable =
        vm.visualizerSupport == AudioVisualizerSupport.supported;

    return LayoutBuilder(
      builder: (context, constraints) {
        final density = _PlayerLayoutDensity.forHeight(constraints.maxHeight);
        final contentWidth = math.min(_maxContentWidth, constraints.maxWidth);
        final artworkMax = math.min(260.0, math.max(96.0, contentWidth * 0.72));
        final artworkSize = math.min(
          artworkMax,
          math.max(
            density.minimumArtworkSize,
            constraints.maxHeight - density.controlsHeightBudget,
          ),
        );

        return Center(
          child: SizedBox(
            width: contentWidth,
            child: SingleChildScrollView(
              key: const Key('player-scroll-view'),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  key: const Key('player-content-column'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _statusText(l10n, vm.snapshot.status),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    SizedBox(height: density.sectionGap),
                    Center(
                      child: SizedBox.square(
                        key: const Key('player-artwork'),
                        dimension: artworkSize,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            density.artworkRadius,
                          ),
                          child: ColoredBox(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            child: track.artworkUrl.isNotEmpty
                                ? Image.network(
                                    track.artworkUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(Icons.album, size: 120),
                                  )
                                : const Icon(Icons.album, size: 120),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: density.sectionGap),
                    Text(
                      track.title,
                      maxLines: density.metadataMaxLines,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      track.artistName.isEmpty
                          ? l10n.unknownArtist
                          : track.artistName,
                      maxLines: density.metadataMaxLines,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    if (vm.isVisualizerEnabled && visualizerAvailable) ...[
                      SizedBox(height: density.visualizerGap),
                      SizedBox(
                        height: density.visualizerHeight,
                        child: _PlaybackVisualizer(
                          key: const Key('player-visualizer'),
                          spectrum: vm.spectrum,
                        ),
                      ),
                    ] else if (vm.isVisualizerEnabled)
                      _SpectrumRecoveryListener(spectrum: vm.spectrum),
                    SizedBox(height: density.controlsGap),
                    StreamBuilder<Duration>(
                      stream: vm.position,
                      builder: (context, snap) {
                        final pos = snap.data ?? Duration.zero;
                        final total = vm.snapshot.duration.inMilliseconds == 0
                            ? 1
                            : vm.snapshot.duration.inMilliseconds;
                        return Column(
                          children: [
                            Slider(
                              key: const Key('player-progress-slider'),
                              value: pos.inMilliseconds
                                  .clamp(0, total)
                                  .toDouble(),
                              max: total.toDouble(),
                              onChanged: (value) => vm.seek(
                                Duration(milliseconds: value.round()),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(formatPlaybackDuration(pos)),
                                Text(
                                  formatPlaybackDuration(vm.snapshot.duration),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    Wrap(
                      key: const Key('player-transport-controls'),
                      alignment: WrapAlignment.center,
                      children: [
                        Semantics(
                          key: const Key('player-shuffle-semantics'),
                          selected: vm.isShuffleEnabled,
                          child: IconButton(
                            key: const Key('player-shuffle-button'),
                            tooltip: l10n.playerShuffle,
                            iconSize: 38,
                            icon: Icon(
                              vm.isShuffleEnabled
                                  ? Icons.shuffle_on
                                  : Icons.shuffle,
                              color: vm.isShuffleEnabled
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            onPressed: vm.toggleShuffle,
                          ),
                        ),
                        IconButton(
                          key: const Key('player-previous-button'),
                          tooltip: l10n.playerPrevious,
                          iconSize: 36,
                          icon: const Icon(Icons.skip_previous),
                          onPressed: vm.previous,
                        ),
                        IconButton(
                          key: const Key('player-play-pause-button'),
                          tooltip: vm.snapshot.isPlaying
                              ? l10n.playerPause
                              : l10n.playerPlay,
                          iconSize: 56,
                          icon: Icon(
                            vm.snapshot.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                          ),
                          onPressed: vm.playPause,
                        ),
                        IconButton(
                          key: const Key('player-next-button'),
                          tooltip: l10n.playerNext,
                          iconSize: 36,
                          icon: const Icon(Icons.skip_next),
                          onPressed: vm.next,
                        ),
                        IconButton(
                          key: const Key('player-visualizer-toggle'),
                          tooltip: !visualizerAvailable
                              ? l10n.playerVisualizerUnavailable
                              : vm.isVisualizerEnabled
                              ? l10n.playerVisualizerDisable
                              : l10n.playerVisualizerEnable,
                          iconSize: 28,
                          icon: Icon(
                            vm.isVisualizerEnabled
                                ? Icons.graphic_eq
                                : Icons.bar_chart_outlined,
                          ),
                          onPressed: visualizerAvailable
                              ? vm.toggleVisualizer
                              : null,
                        ),
                      ],
                    ),
                    SizedBox(height: density.transportToVolumeGap),
                    Row(
                      key: const Key('player-volume-controls'),
                      children: [
                        IconButton(
                          key: const Key('player-volume-mute-button'),
                          tooltip: vm.isMuted
                              ? l10n.playerUnmute
                              : l10n.playerMute,
                          icon: Icon(_volumeIcon(vm)),
                          onPressed: vm.toggleMute,
                        ),
                        Expanded(
                          child: Slider(
                            key: const Key('player-volume-slider'),
                            value: vm.volume,
                            min: 0,
                            max: 1,
                            onChanged: vm.setVolume,
                          ),
                        ),
                        Text('${(vm.volume * 100).round()}%'),
                      ],
                    ),
                    _EqualizerPanel(
                      viewModel: vm,
                      l10n: l10n,
                      compact: density.isCompact,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _PlayerLayoutDensity {
  tight,
  compact,
  regular;

  static _PlayerLayoutDensity forHeight(double height) {
    if (height < 500) return tight;
    if (height < 720) return compact;
    return regular;
  }

  bool get isCompact => this != regular;

  double get minimumArtworkSize => switch (this) {
    tight => 64,
    compact => 80,
    regular => 120,
  };

  // Keeps metadata, progress, transport, volume, and equalizer controls visible;
  // artwork consumes only the remaining vertical space.
  double get controlsHeightBudget => switch (this) {
    tight || compact => 410,
    regular => 460,
  };

  double get sectionGap => switch (this) {
    tight => 2,
    compact => 4,
    regular => 12,
  };

  double get controlsGap => switch (this) {
    tight => 2,
    compact => 6,
    regular => 16,
  };

  double get artworkRadius => switch (this) {
    tight => 12,
    compact => 14,
    regular => 20,
  };

  int get metadataMaxLines => isCompact ? 1 : 2;

  double get visualizerGap => switch (this) {
    tight => 0,
    compact => 2,
    regular => 6,
  };

  double get visualizerHeight => switch (this) {
    tight => 28,
    compact => 40,
    regular => 72,
  };

  double get transportToVolumeGap => isCompact ? 0 : 4;
}

class _EqualizerPanel extends StatelessWidget {
  const _EqualizerPanel({
    required this.viewModel,
    required this.l10n,
    required this.compact,
  });

  final PlayerViewModel viewModel;
  final AppLocalizations l10n;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final unavailableCopy =
        viewModel.equalizerSupport ==
            AudioEqualizerSupport.unsupportedOnPlatform
        ? l10n.playerEqualizerUnsupportedPlatform
        : l10n.playerEqualizerUnavailable;
    return ConstrainedBox(
      key: const Key('player-eq-panel'),
      constraints: BoxConstraints(minHeight: compact ? 48 : 72),
      child: viewModel.equalizerSupport != AudioEqualizerSupport.supported
          ? Center(
              child: Text(
                unavailableCopy,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          : Wrap(
              alignment: compact ? WrapAlignment.center : WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: compact ? 2 : 6,
              children: [
                Text(
                  l10n.playerEqualizer,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                _EqualizerPresetChip(
                  key: const Key('player-eq-preset-flat'),
                  label: l10n.playerEqualizerPresetFlat,
                  tooltip: l10n.playerEqualizerPresetFlatHelp,
                  selected:
                      viewModel.equalizerPreset == AudioEqualizerPreset.flat,
                  onSelected: () =>
                      viewModel.setEqualizerPreset(AudioEqualizerPreset.flat),
                ),
                _EqualizerPresetChip(
                  key: const Key('player-eq-preset-bass'),
                  label: l10n.playerEqualizerPresetBass,
                  tooltip: l10n.playerEqualizerPresetBassHelp,
                  selected:
                      viewModel.equalizerPreset ==
                      AudioEqualizerPreset.bassBoost,
                  onSelected: () => viewModel.setEqualizerPreset(
                    AudioEqualizerPreset.bassBoost,
                  ),
                ),
              ],
            ),
    );
  }
}

class _EqualizerPresetChip extends StatelessWidget {
  const _EqualizerPresetChip({
    super.key,
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final String tooltip;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _SpectrumRecoveryListener extends StatelessWidget {
  const _SpectrumRecoveryListener({required this.spectrum});

  final Stream<AudioSpectrumFrame> spectrum;

  @override
  Widget build(BuildContext context) {
    // Native support updates share this lazy stream subscription. Keeping an
    // invisible listener lets a later playable PCM format restore the display.
    return StreamBuilder<AudioSpectrumFrame>(
      stream: spectrum,
      builder: (context, snapshot) => const SizedBox.shrink(),
    );
  }
}

class _PlaybackVisualizer extends StatelessWidget {
  const _PlaybackVisualizer({super.key, required this.spectrum});

  final Stream<AudioSpectrumFrame> spectrum;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AudioSpectrumFrame>(
      stream: spectrum,
      builder: (context, snapshot) {
        return AudioSpectrumVisualizer(
          key: const Key('player-visualizer-bars'),
          magnitudes: snapshot.data?.magnitudes ?? const <double>[],
        );
      },
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
        color: Theme.of(context).colorScheme.primary,
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

    for (var i = 0; i < barCount; i++) {
      final normalized = magnitudes[i].clamp(0.0, 1.0);
      final height = size.height * normalized;
      final left = i * (barWidth + gap);
      final top = size.height - height;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barWidth, height),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VisualizerPainter oldDelegate) {
    return !listEquals(oldDelegate.magnitudes, magnitudes) ||
        oldDelegate.color != color;
  }
}
