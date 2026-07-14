import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/layout/edmm_breakpoints.dart';
import '../../core/themes/edmm_theme_extensions.dart';
import '../../core/themes/edmm_theme_tokens.dart';
import '../../core/widgets/edmm_artwork.dart';
import '../../core/widgets/edmm_icon_action.dart';
import '../view_model/player_view_model.dart';

class PlayerMiniBar extends StatelessWidget {
  const PlayerMiniBar({super.key, required this.viewModel, this.onOpenPlayer});

  final PlayerViewModel viewModel;
  final VoidCallback? onOpenPlayer;

  IconData _volumeIcon(PlayerViewModel vm) {
    if (vm.isMuted || vm.volume <= 0) return Icons.volume_off;
    if (vm.volume < 0.5) return Icons.volume_down;
    return Icons.volume_up;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final track = viewModel.snapshot.currentTrack;
        if (track == null) return const SizedBox.shrink();
        final artist = track.artistName.trim().isEmpty
            ? l10n.unknownArtist
            : track.artistName;
        final colors = Theme.of(context).edmm;

        return SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(
            EdmmSpacing.sm,
            EdmmSpacing.xs,
            EdmmSpacing.sm,
            EdmmSpacing.xs,
          ),
          child: Material(
            key: const Key('player-mini-bar'),
            elevation: 0,
            color: colors.surfaceRose,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(EdmmRadii.medium),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _MiniPlaybackProgress(
                  key: ValueKey<String>('player-mini-progress-${track.id}'),
                  position: viewModel.position,
                  duration: viewModel.snapshot.duration,
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final showVolumeValue =
                        constraints.maxWidth >= EdmmBreakpoints.mediumMinWidth;
                    return ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: EdmmSizes.minTouchTarget + EdmmSpacing.xl,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Tooltip(
                              message: l10n.playerOpen,
                              excludeFromSemantics: true,
                              child: Semantics(
                                key: const Key('player-mini-open-semantics'),
                                container: true,
                                button: true,
                                enabled: onOpenPlayer != null,
                                label: l10n.playerOpen,
                                value: '${track.title}, $artist',
                                onTap: onOpenPlayer,
                                child: ExcludeSemantics(
                                  child: InkWell(
                                    key: const Key('player-mini-open'),
                                    onTap: onOpenPlayer,
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        EdmmSpacing.sm,
                                        EdmmSpacing.xs,
                                        EdmmSpacing.xxs,
                                        EdmmSpacing.xs,
                                      ),
                                      child: Row(
                                        children: <Widget>[
                                          SizedBox.square(
                                            dimension: EdmmSizes.minTouchTarget,
                                            child: EdmmArtwork(
                                              imageUrl: track.artworkUrl,
                                              radius: EdmmArtworkRadius.small,
                                              semantics: EdmmArtworkSemantics
                                                  .decorative,
                                            ),
                                          ),
                                          const SizedBox(width: EdmmSpacing.sm),
                                          Expanded(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Text(
                                                  track.title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: EdmmTypography
                                                      .trackTitle
                                                      .copyWith(
                                                        color:
                                                            colors.textPrimary,
                                                      ),
                                                ),
                                                Text(
                                                  artist,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: EdmmTypography.body
                                                      .copyWith(
                                                        color: colors.textMuted,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          EdmmIconAction(
                            label: viewModel.isMuted
                                ? l10n.playerUnmute
                                : l10n.playerMute,
                            icon: _volumeIcon(viewModel),
                            actionKey: const Key('player-mini-volume-mute'),
                            onPressed: viewModel.toggleMute,
                          ),
                          if (showVolumeValue)
                            SizedBox(
                              width: EdmmSizes.minTouchTarget,
                              child: Text(
                                '${(viewModel.volume * 100).round()}%',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: EdmmTypography.timeData.copyWith(
                                  color: colors.textMuted,
                                ),
                              ),
                            ),
                          EdmmIconAction(
                            label: viewModel.snapshot.isPlaying
                                ? l10n.playerPause
                                : l10n.playerPlay,
                            icon: viewModel.snapshot.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            actionKey: const Key('player-mini-play-pause'),
                            onPressed: viewModel.playPause,
                          ),
                          const SizedBox(width: EdmmSpacing.xxs),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MiniPlaybackProgress extends StatelessWidget {
  const _MiniPlaybackProgress({
    super.key,
    required this.position,
    required this.duration,
  });

  final Stream<Duration> position;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).edmm;
    return StreamBuilder<Duration>(
      stream: position,
      initialData: Duration.zero,
      builder: (context, snapshot) {
        final durationMs = duration.inMilliseconds;
        final positionMs = (snapshot.data ?? Duration.zero).inMilliseconds;
        final value = durationMs <= 0
            ? 0.0
            : (positionMs / durationMs).clamp(0.0, 1.0).toDouble();
        return ExcludeSemantics(
          child: SizedBox(
            height: 2,
            child: LinearProgressIndicator(
              key: const Key('player-mini-progress'),
              value: value,
              color: colors.playbackActive,
              backgroundColor: colors.outline,
            ),
          ),
        );
      },
    );
  }
}
