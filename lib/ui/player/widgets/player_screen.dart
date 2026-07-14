import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/audio/audio_visualizer_controller.dart';
import '../../../domain/playback/playback_snapshot.dart';
import '../../../domain/result.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/motion/edmm_motion.dart';
import '../../core/themes/edmm_theme_extensions.dart';
import '../../core/themes/edmm_theme_tokens.dart';
import '../../core/widgets/edmm_ambient_backdrop.dart';
import '../view_model/player_view_model.dart';
import 'player_adaptive_layout.dart';
import 'player_artwork_stage.dart';
import 'player_equalizer_panel.dart';
import 'player_progress_section.dart';
import 'player_transport_controls.dart';
import 'player_visualizer.dart';
import 'player_volume_controls.dart';

export 'player_progress_section.dart' show formatPlaybackDuration;
export 'player_visualizer.dart' show AudioSpectrumVisualizer;

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

  String? _lastErrorToastToken;
  double _dragOffset = 0;
  double _snapFrom = 0;
  late final AnimationController _snapController;

  @override
  void initState() {
    super.initState();
    _snapController =
        AnimationController(vsync: this, duration: EdmmMotion.standard)
          ..addListener(() {
            final t = EdmmMotion.enterCurve.transform(_snapController.value);
            setState(() => _dragOffset = _snapFrom * (1 - t));
          });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _snapController.duration = EdmmMotion.resolve(
      EdmmMotion.standard,
      reduceMotion: EdmmMotion.reducedMotionOf(context),
    );
  }

  @override
  void dispose() {
    _snapController.dispose();
    if (widget.disposeViewModel) {
      widget.viewModel.dispose();
    }
    super.dispose();
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
    _snapFrom = _dragOffset;
    if (_snapController.duration == Duration.zero) {
      setState(() => _dragOffset = 0);
      return;
    }
    _snapController.forward(from: 0);
  }

  ImageProvider<Object>? _artworkProvider(String? imageUrl) {
    final normalized = imageUrl?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return NetworkImage(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final routeVisible = TickerMode.valuesOf(context).enabled;
    final reduceMotion = EdmmMotion.reducedMotionOf(context);

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
          child: ListenableBuilder(
            listenable: widget.viewModel,
            builder: (context, _) {
              final vm = widget.viewModel;
              final track = vm.snapshot.currentTrack;
              if (!vm.shouldShowErrorBanner) {
                _lastErrorToastToken = null;
              }

              return EdmmAmbientBackdrop(
                variant: EdmmAmbientBackdropVariant.playerArtwork,
                artwork: _artworkProvider(track?.artworkUrl),
                child: Material(
                  color: Colors.transparent,
                  child: SafeArea(
                    child: Column(
                      children: <Widget>[
                        GestureDetector(
                          key: const Key('player-close-drag-area'),
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragStart: _handleCloseDragStart,
                          onVerticalDragUpdate: _handleCloseDragUpdate,
                          onVerticalDragEnd: _handleCloseDragEnd,
                          child: SizedBox(
                            width: double.infinity,
                            height: EdmmSizes.minTouchTarget,
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              if (vm.shouldShowErrorBanner) ...<Widget>[
                                Builder(
                                  builder: (context) {
                                    final errorToken = vm.latestErrorToken;
                                    if (errorToken != null &&
                                        errorToken != _lastErrorToastToken) {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            if (!mounted) return;
                                            final messenger =
                                                ScaffoldMessenger.of(context);
                                            messenger.clearSnackBars();
                                            messenger.showSnackBar(
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
                                  actions: <Widget>[
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
                                Expanded(
                                  child: _buildExpandedBody(
                                    vm,
                                    l10n,
                                    routeVisible: routeVisible,
                                    reduceMotion: reduceMotion,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedBody(
    PlayerViewModel vm,
    AppLocalizations l10n, {
    required bool routeVisible,
    required bool reduceMotion,
  }) {
    final track = vm.snapshot.currentTrack!;
    final visualizerAvailable =
        vm.visualizerSupport == AudioVisualizerSupport.supported;

    return PlayerAdaptiveLayout(
      builder: (context, density, artworkSize) {
        return PlayerAdaptiveContent(
          presentation: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _statusText(l10n, vm.snapshot.status),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              SizedBox(height: density.sectionGap),
              PlayerArtworkStage(
                imageUrl: track.artworkUrl,
                size: artworkSize,
                radius: density.artworkRadius,
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
                style: TextStyle(color: Theme.of(context).edmm.textMuted),
              ),
              if (vm.isVisualizerEnabled &&
                  visualizerAvailable &&
                  routeVisible) ...<Widget>[
                SizedBox(height: density.visualizerGap),
                SizedBox(
                  key: const Key('player-visualizer'),
                  height: density.visualizerHeight,
                  child: PlayerVisualizer(
                    spectrum: vm.spectrum,
                    status: vm.snapshot.status,
                    visible: routeVisible,
                    reduceMotion: reduceMotion,
                  ),
                ),
              ] else if (vm.isVisualizerEnabled &&
                  !visualizerAvailable) ...<Widget>[
                SizedBox(height: density.visualizerGap),
                Text(
                  l10n.playerVisualizerUnavailable,
                  key: const Key('player-visualizer-unavailable'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).edmm.textMuted,
                  ),
                ),
                if (routeVisible)
                  PlayerSpectrumRecoveryProbe(
                    key: const Key('player-visualizer-recovery-probe'),
                    spectrum: vm.spectrum,
                  ),
              ],
            ],
          ),
          controls: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              PlayerProgressSection(
                position: vm.position,
                duration: vm.snapshot.duration,
                onSeek: vm.seek,
                semanticLabel: l10n.playerProgress,
                semanticValueFormatter: (position, duration) =>
                    l10n.playerProgressValue(
                      formatPlaybackDuration(position),
                      formatPlaybackDuration(duration),
                    ),
              ),
              PlayerTransportControls(
                shuffleEnabled: vm.isShuffleEnabled,
                isPlaying: vm.snapshot.isPlaying,
                visualizerEnabled: vm.isVisualizerEnabled,
                visualizerAvailable: visualizerAvailable,
                shuffleLabel: l10n.playerShuffle,
                previousLabel: l10n.playerPrevious,
                playLabel: l10n.playerPlay,
                pauseLabel: l10n.playerPause,
                nextLabel: l10n.playerNext,
                visualizerEnableLabel: l10n.playerVisualizerEnable,
                visualizerDisableLabel: l10n.playerVisualizerDisable,
                visualizerUnavailableLabel: l10n.playerVisualizerUnavailable,
                visualizerLabel: l10n.playerVisualizer,
                onToggleShuffle: vm.toggleShuffle,
                onPrevious: vm.previous,
                onPlayPause: vm.playPause,
                onNext: vm.next,
                onToggleVisualizer: vm.toggleVisualizer,
              ),
              SizedBox(height: density.transportToVolumeGap),
              PlayerVolumeControls(
                isMuted: vm.isMuted,
                volume: vm.volume,
                muteLabel: l10n.playerMute,
                unmuteLabel: l10n.playerUnmute,
                onToggleMute: vm.toggleMute,
                onVolumeChanged: vm.setVolume,
                semanticLabel: l10n.playerVolume,
              ),
              PlayerEqualizerPanel(
                support: vm.equalizerSupport,
                preset: vm.equalizerPreset,
                compact: density.isCompact,
                equalizerLabel: l10n.playerEqualizer,
                unsupportedPlatformLabel:
                    l10n.playerEqualizerUnsupportedPlatform,
                unavailableLabel: l10n.playerEqualizerUnavailable,
                flatLabel: l10n.playerEqualizerPresetFlat,
                flatTooltip: l10n.playerEqualizerPresetFlatHelp,
                bassLabel: l10n.playerEqualizerPresetBass,
                bassTooltip: l10n.playerEqualizerPresetBassHelp,
                onPresetSelected: vm.setEqualizerPreset,
              ),
            ],
          ),
        );
      },
    );
  }
}
