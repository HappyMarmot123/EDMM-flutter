import 'package:flutter/material.dart';

import '../../../domain/models/track.dart';
import '../../core/themes/edmm_theme_tokens.dart';
import '../../core/widgets/edmm_track_row.dart';

class CatalogTrackList extends StatelessWidget {
  const CatalogTrackList({
    super.key,
    required this.tracks,
    required this.currentTrackId,
    required this.selectedTrackId,
    required this.isCurrentPlaying,
    required this.unknownArtistLabel,
    required this.currentPlayingSemanticLabel,
    required this.currentPausedSemanticLabel,
    required this.unplayableSemanticLabel,
    required this.detailsLabel,
    required this.onPlay,
    this.header,
    this.onOpenTrack,
  });

  final List<Track> tracks;
  final String? currentTrackId;
  final String? selectedTrackId;
  final bool isCurrentPlaying;
  final String unknownArtistLabel;
  final String currentPlayingSemanticLabel;
  final String currentPausedSemanticLabel;
  final String unplayableSemanticLabel;
  final String detailsLabel;
  final void Function(List<Track> queue, int index) onPlay;
  final Widget? header;
  final ValueChanged<Track>? onOpenTrack;

  @override
  Widget build(BuildContext context) {
    final headerOffset = header == null ? 0 : 1;
    return ListView.builder(
      key: const Key('catalog-track-list'),
      itemCount: tracks.length + headerOffset,
      itemBuilder: (context, index) {
        if (header != null && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: EdmmSpacing.sm),
            child: header,
          );
        }

        final trackIndex = index - headerOffset;
        final track = tracks[trackIndex];
        final state = _stateFor(track);
        final stateSemanticLabel = switch (state) {
          EdmmTrackRowState.playingCurrent => currentPlayingSemanticLabel,
          EdmmTrackRowState.current => currentPausedSemanticLabel,
          EdmmTrackRowState.unplayable => unplayableSemanticLabel,
          _ => null,
        };
        final row = EdmmTrackRow(
          key: Key('catalog-track-${track.id}'),
          title: track.title,
          artist: track.artistName.trim().isEmpty
              ? unknownArtistLabel
              : track.artistName,
          artworkUrl: track.artworkUrl,
          duration: track.duration,
          state: state,
          stateSemanticLabel: stateSemanticLabel,
          primaryActionKey: Key('catalog-track-primary-${track.id}'),
          onTap: track.isPlayable ? () => onPlay(tracks, trackIndex) : null,
          detailsLabel: onOpenTrack == null ? null : detailsLabel,
          detailsActionKey: Key('catalog-track-detail-${track.id}'),
          onDetails: onOpenTrack == null ? null : () => onOpenTrack!(track),
        );

        if (trackIndex == tracks.length - 1) {
          return row;
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: EdmmSpacing.xxs),
          child: row,
        );
      },
    );
  }

  EdmmTrackRowState _stateFor(Track track) {
    if (!track.isPlayable) {
      return EdmmTrackRowState.unplayable;
    }
    if (track.id == currentTrackId) {
      return isCurrentPlaying
          ? EdmmTrackRowState.playingCurrent
          : EdmmTrackRowState.current;
    }
    if (track.id == selectedTrackId) {
      return EdmmTrackRowState.selected;
    }
    return EdmmTrackRowState.defaultState;
  }
}
