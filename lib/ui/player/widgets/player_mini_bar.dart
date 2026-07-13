import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
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

        return SafeArea(
          top: false,
          child: Material(
            key: const Key('player-mini-bar'),
            elevation: 8,
            color: Theme.of(context).colorScheme.surface,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 360;
                return ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 72),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: l10n.playerOpen,
                          child: InkWell(
                            key: const Key('player-mini-open'),
                            onTap: onOpenPlayer,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  if (track.artworkUrl.isNotEmpty)
                                    Image.network(
                                      track.artworkUrl,
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.music_note,
                                                size: 40,
                                              ),
                                    )
                                  else
                                    const Icon(Icons.music_note, size: 40),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          track.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleSmall,
                                        ),
                                        Text(
                                          track.artistName.isEmpty
                                              ? l10n.unknownArtist
                                              : track.artistName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
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
                      IconButton(
                        key: const Key('player-mini-volume-mute'),
                        tooltip: viewModel.isMuted
                            ? l10n.playerUnmute
                            : l10n.playerMute,
                        icon: Icon(_volumeIcon(viewModel)),
                        onPressed: viewModel.toggleMute,
                      ),
                      if (!compact)
                        SizedBox(
                          width: 44,
                          child: Text(
                            '${(viewModel.volume * 100).round()}%',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      IconButton(
                        key: const Key('player-mini-play-pause'),
                        tooltip: viewModel.snapshot.isPlaying
                            ? l10n.playerPause
                            : l10n.playerPlay,
                        icon: Icon(
                          viewModel.snapshot.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                        ),
                        onPressed: viewModel.playPause,
                        iconSize: 36,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
