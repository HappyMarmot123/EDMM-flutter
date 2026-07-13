import 'package:flutter/material.dart';

import '../../../domain/models/library_track_item.dart';
import '../../../l10n/app_localizations.dart';

class LocalLibraryTrackTile extends StatelessWidget {
  const LocalLibraryTrackTile({
    super.key,
    required this.item,
    required this.onOpenTrack,
    this.onPlay,
    this.onRemove,
    this.playButtonKey,
  });

  final LibraryTrackItem item;
  final VoidCallback onOpenTrack;
  final VoidCallback? onPlay;
  final VoidCallback? onRemove;
  final Key? playButtonKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final track = item.track;
    return ListTile(
      onTap: onOpenTrack,
      leading: track == null || track.artworkUrl.isEmpty
          ? const Icon(Icons.music_note)
          : Image.network(
              track.artworkUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(Icons.music_note),
            ),
      title: Text(track?.title ?? item.trackId),
      subtitle: Text(
        track == null
            ? l10n.trackUnavailable
            : (track.artistName.isEmpty
                  ? l10n.unknownArtist
                  : track.artistName),
      ),
      trailing: onPlay == null && onRemove == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onPlay != null)
                  IconButton(
                    key: playButtonKey,
                    tooltip: l10n.trackPlay,
                    onPressed: onPlay,
                    icon: const Icon(Icons.play_arrow),
                  ),
                if (onRemove != null)
                  PopupMenuButton<int>(
                    tooltip: l10n.removeFromPlaylist,
                    icon: const Icon(Icons.more_vert),
                    onSelected: (_) => onRemove!(),
                    itemBuilder: (context) => [
                      PopupMenuItem<int>(
                        value: 0,
                        child: Text(l10n.removeFromPlaylist),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}
