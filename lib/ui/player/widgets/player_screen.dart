import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/audio/audio_effects_controller.dart';
import '../../../domain/playback/playback_snapshot.dart';
import '../../../domain/result.dart';
import '../../../l10n/app_localizations.dart';
import '../view_model/player_view_model.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.viewModel, this.onClose});
  final PlayerViewModel viewModel;
  final VoidCallback? onClose;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _visualizerEnabled = false;
  String? _lastErrorToastToken;
  double _closeDragDy = 0;

  @override
  void dispose() {
    widget.viewModel.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

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
    _closeDragDy = 0;
  }

  void _handleCloseDragUpdate(DragUpdateDetails details) {
    _closeDragDy += details.primaryDelta ?? 0;
  }

  void _handleCloseDragEnd(DragEndDetails _) {
    if (_closeDragDy >= 48) {
      _closePlayer();
    }
    _closeDragDy = 0;
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
        appBar: AppBar(
          leading: GestureDetector(
            key: const Key('player-close-drag-area'),
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: _handleCloseDragStart,
            onVerticalDragUpdate: _handleCloseDragUpdate,
            onVerticalDragEnd: _handleCloseDragEnd,
            child: IconButton(
              key: const Key('player-close-button'),
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: _closePlayer,
            ),
          ),
          title: Text(l10n.nowPlaying),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
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
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _errorText(l10n, vm.snapshot.error!),
                                ),
                                duration: const Duration(seconds: 4),
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
                      content: Text(_errorText(l10n, vm.snapshot.error!)),
                      actions: [
                        TextButton(
                          onPressed: vm.dismissError,
                          child: Text(l10n.playerDismiss),
                        ),
                      ],
                    ),
                  ],
                  if (track == null)
                    Expanded(
                      child: Center(child: Text(l10n.playerNoTrackLoaded)),
                    )
                  else
                    Expanded(child: _buildExpandedBody(vm, l10n)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedBody(PlayerViewModel vm, AppLocalizations l10n) {
    final track = vm.snapshot.currentTrack!;

    return Column(
      children: [
        Text(
          _statusText(l10n, vm.snapshot.status),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Center(
            child: track.artworkUrl.isNotEmpty
                ? Image.network(
                    track.artworkUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.album, size: 160),
                  )
                : const Icon(Icons.album, size: 160),
          ),
        ),
        Text(track.title, style: Theme.of(context).textTheme.titleLarge),
        Text(track.artistName.isEmpty ? l10n.unknownArtist : track.artistName),
        if (_visualizerEnabled)
          SizedBox(
            height: 72,
            child: _PlaybackVisualizer(
              key: const Key('player-visualizer'),
              position: vm.position,
              trackId: track.id,
            ),
          ),
        const SizedBox(height: 16),
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
                  value: pos.inMilliseconds.clamp(0, total).toDouble(),
                  max: total.toDouble(),
                  onChanged: (value) =>
                      vm.seek(Duration(milliseconds: value.round())),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text(_fmt(pos)), Text(_fmt(vm.snapshot.duration))],
                ),
              ],
            );
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              key: const Key('player-shuffle-button'),
              iconSize: 38,
              icon: Icon(
                vm.isShuffleEnabled ? Icons.shuffle_on : Icons.shuffle,
                color: vm.isShuffleEnabled
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              onPressed: vm.toggleShuffle,
            ),
            const SizedBox(width: 8),
            IconButton(
              iconSize: 36,
              icon: const Icon(Icons.skip_previous),
              onPressed: vm.previous,
            ),
            IconButton(
              iconSize: 56,
              icon: Icon(
                vm.snapshot.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
              onPressed: vm.playPause,
            ),
            IconButton(
              iconSize: 36,
              icon: const Icon(Icons.skip_next),
              onPressed: vm.next,
            ),
            IconButton(
              key: const Key('player-visualizer-toggle'),
              iconSize: 28,
              icon: Icon(
                _visualizerEnabled
                    ? Icons.graphic_eq
                    : Icons.bar_chart_outlined,
              ),
              onPressed: () =>
                  setState(() => _visualizerEnabled = !_visualizerEnabled),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            IconButton(
              key: const Key('player-volume-mute-button'),
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
        _EqualizerPanel(viewModel: vm, l10n: l10n),
      ],
    );
  }
}

class _EqualizerPanel extends StatelessWidget {
  const _EqualizerPanel({required this.viewModel, required this.l10n});

  final PlayerViewModel viewModel;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final unavailableCopy =
        viewModel.equalizerSupport ==
            AudioEqualizerSupport.unsupportedOnPlatform
        ? l10n.playerEqualizerUnsupportedPlatform
        : l10n.playerEqualizerUnavailable;
    return SizedBox(
      key: const Key('player-eq-panel'),
      height: 92,
      child: viewModel.equalizerSupport != AudioEqualizerSupport.supported
          ? Center(
              child: Text(
                unavailableCopy,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.playerEqualizer,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    _EqualizerPresetChip(
                      key: const Key('player-eq-preset-flat'),
                      label: l10n.playerEqualizerPresetFlat,
                      tooltip: l10n.playerEqualizerPresetFlatHelp,
                      selected:
                          viewModel.equalizerPreset ==
                          AudioEqualizerPreset.flat,
                      onSelected: () => viewModel.setEqualizerPreset(
                        AudioEqualizerPreset.flat,
                      ),
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

class _PlaybackVisualizer extends StatelessWidget {
  const _PlaybackVisualizer({
    super.key,
    required this.position,
    required this.trackId,
  });

  final Stream<Duration> position;
  final String trackId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: position,
      builder: (context, snapshot) {
        return CustomPaint(
          painter: _VisualizerPainter(
            position: snapshot.data ?? Duration.zero,
            seed: trackId.hashCode,
            color: Theme.of(context).colorScheme.primary,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _VisualizerPainter extends CustomPainter {
  const _VisualizerPainter({
    required this.position,
    required this.seed,
    required this.color,
  });

  final Duration position;
  final int seed;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    const barCount = 24;
    final gap = size.width / (barCount * 3);
    final barWidth = (size.width - gap * (barCount - 1)) / barCount;
    final phase = position.inMilliseconds / 220.0;

    for (var i = 0; i < barCount; i++) {
      final wave = math.sin(phase + i * 0.72 + seed % 11);
      final pulse = math.cos(phase * 0.37 + i * 1.31);
      final normalized = ((wave + pulse) / 4.0 + 0.5).clamp(0.12, 1.0);
      final height = size.height * normalized;
      final left = i * (barWidth + gap);
      final top = (size.height - height) / 2;
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
    return oldDelegate.position != position ||
        oldDelegate.seed != seed ||
        oldDelegate.color != color;
  }
}
