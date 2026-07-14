import 'package:flutter/material.dart';

import '../../../domain/models/track.dart';
import '../../../l10n/app_localizations.dart';
import '../../core/layout/edmm_breakpoints.dart';
import '../../core/themes/edmm_theme_extensions.dart';
import '../../core/themes/edmm_theme_tokens.dart';
import '../../core/widgets/edmm_artwork.dart';
import '../../core/widgets/edmm_content_layout.dart';
import '../../core/widgets/edmm_section_label.dart';
import '../../core/widgets/edmm_surface.dart';
import 'track_metadata_grid.dart';

class TrackDetailContent extends StatelessWidget {
  const TrackDetailContent({
    super.key,
    required this.track,
    required this.onPlay,
    this.storageError,
  });

  final Track track;
  final ValueChanged<Track> onPlay;
  final Object? storageError;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final useTwoPane = availableWidth >= EdmmBreakpoints.mediumMinWidth;

        return EdmmContentLayout(
          width: EdmmContentWidth.wide,
          child: SingleChildScrollView(
            key: const Key('track-detail-scroll'),
            padding: const EdgeInsets.symmetric(vertical: EdmmSpacing.xl),
            child: useTwoPane
                ? Row(
                    key: const Key('track-detail-two-pane'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Flexible(
                        flex: 4,
                        child: Align(
                          alignment: AlignmentDirectional.topCenter,
                          child: _TrackArtwork(track: track),
                        ),
                      ),
                      const SizedBox(width: EdmmSpacing.xl),
                      Expanded(
                        flex: 6,
                        child: _TrackInformation(
                          track: track,
                          storageError: storageError,
                          onPlay: onPlay,
                        ),
                      ),
                    ],
                  )
                : Column(
                    key: const Key('track-detail-one-pane'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Align(
                        alignment: AlignmentDirectional.topCenter,
                        child: _TrackArtwork(track: track),
                      ),
                      const SizedBox(height: EdmmSpacing.xl),
                      _TrackInformation(
                        track: track,
                        storageError: storageError,
                        onPlay: onPlay,
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _TrackArtwork extends StatelessWidget {
  const _TrackArtwork({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: const Key('track-detail-artwork'),
      constraints: const BoxConstraints(
        maxWidth: EdmmBreakpoints.standardContentMaxWidth / 2,
      ),
      child: EdmmArtwork(
        imageUrl: track.artworkUrl,
        radius: EdmmArtworkRadius.large,
      ),
    );
  }
}

class _TrackInformation extends StatelessWidget {
  const _TrackInformation({
    required this.track,
    required this.storageError,
    required this.onPlay,
  });

  final Track track;
  final Object? storageError;
  final ValueChanged<Track> onPlay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).edmm;
    final metadata = track.metadata.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));
    final coreMetadata = <TrackMetadataItem>[
      TrackMetadataItem(
        label: l10n.albumLabel,
        value: track.albumName?.trim().isNotEmpty == true
            ? track.albumName!
            : l10n.unknownAlbum,
      ),
      TrackMetadataItem(label: l10n.sourceLabel, value: track.source),
      TrackMetadataItem(
        label: l10n.durationLabel,
        value: _formatDuration(track.duration),
      ),
    ];
    final additionalMetadata = <TrackMetadataItem>[
      for (final entry in metadata)
        TrackMetadataItem(
          label: entry.key,
          value: _formatMetadata(entry.value),
        ),
    ];

    return Column(
      key: const Key('track-detail-heading'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          track.title,
          softWrap: true,
          style: EdmmTypography.screenTitle.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: EdmmSpacing.xxs),
        Text(
          track.artistName.isEmpty ? l10n.unknownArtist : track.artistName,
          softWrap: true,
          style: EdmmTypography.bodyStrong.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: EdmmSpacing.lg),
        FilledButton.icon(
          key: const Key('track-detail-play'),
          onPressed: track.isPlayable ? () => onPlay(track) : null,
          icon: const Icon(Icons.play_arrow),
          label: Text(l10n.trackPlay),
        ),
        if (storageError != null) ...<Widget>[
          const SizedBox(height: EdmmSpacing.sm),
          _StorageError(message: l10n.localStorageError),
        ],
        const SizedBox(height: EdmmSpacing.xl),
        TrackMetadataGrid(
          key: const Key('track-detail-core-metadata'),
          items: coreMetadata,
        ),
        if (additionalMetadata.isNotEmpty) ...<Widget>[
          const SizedBox(height: EdmmSpacing.xl),
          EdmmSectionLabel(label: l10n.metadataTitle, isHeader: true),
          const SizedBox(height: EdmmSpacing.sm),
          TrackMetadataGrid(
            key: const Key('track-detail-additional-metadata'),
            items: additionalMetadata,
          ),
        ],
      ],
    );
  }
}

class _StorageError extends StatelessWidget {
  const _StorageError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).edmm;
    return Semantics(
      liveRegion: true,
      child: EdmmSurface(
        variant: EdmmSurfaceVariant.outlined,
        child: Padding(
          padding: const EdgeInsets.all(EdmmSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.error_outline, color: colors.error),
              const SizedBox(width: EdmmSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: EdmmTypography.body.copyWith(color: colors.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${duration.inMinutes}:${seconds.toString().padLeft(2, '0')}';
}

String _formatMetadata(Object? value) {
  if (value is Iterable) {
    return value.join(', ');
  }
  return value?.toString() ?? '—';
}
