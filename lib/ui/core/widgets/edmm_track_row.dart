import 'package:flutter/material.dart';

import '../themes/edmm_theme_extensions.dart';
import '../themes/edmm_theme_tokens.dart';
import 'edmm_artwork.dart';
import 'edmm_icon_action.dart';
import 'edmm_surface.dart';
import 'edmm_timecode.dart';

enum EdmmTrackRowState {
  defaultState,
  selected,
  current,
  playingCurrent,
  unplayable,
  error,
}

class EdmmTrackRow extends StatelessWidget {
  const EdmmTrackRow({
    super.key,
    required this.title,
    required this.artist,
    this.artworkUrl,
    this.artworkProvider,
    this.duration,
    this.state = EdmmTrackRowState.defaultState,
    this.stateSemanticLabel,
    this.onTap,
    this.primaryActionKey,
    this.onDetails,
    this.detailsLabel,
    this.detailsActionKey,
  }) : assert(
         artworkUrl == null || artworkProvider == null,
         'Provide either artworkUrl or artworkProvider, not both.',
       ),
       assert(
         (onDetails == null) == (detailsLabel == null),
         'detailsLabel and onDetails must be provided together.',
       );

  final String title;
  final String artist;
  final String? artworkUrl;
  final ImageProvider<Object>? artworkProvider;
  final Duration? duration;
  final EdmmTrackRowState state;
  final String? stateSemanticLabel;
  final VoidCallback? onTap;
  final Key? primaryActionKey;
  final VoidCallback? onDetails;
  final String? detailsLabel;
  final Key? detailsActionKey;

  @override
  Widget build(BuildContext context) {
    assert(title.trim().isNotEmpty, 'EdmmTrackRow requires a title.');
    assert(artist.trim().isNotEmpty, 'EdmmTrackRow requires an artist.');
    final colors = Theme.of(context).edmm;
    final isBlocked =
        state == EdmmTrackRowState.unplayable ||
        state == EdmmTrackRowState.error;
    final primaryOnTap = isBlocked ? null : onTap;
    final isSelected = switch (state) {
      EdmmTrackRowState.selected ||
      EdmmTrackRowState.current ||
      EdmmTrackRowState.playingCurrent => true,
      _ => false,
    };
    final isLive =
        state == EdmmTrackRowState.current ||
        state == EdmmTrackRowState.playingCurrent ||
        state == EdmmTrackRowState.error;
    final semanticLabel = <String>[
      title.trim(),
      artist.trim(),
      if (duration != null) formatEdmmTimecode(duration!),
      if (stateSemanticLabel?.trim().isNotEmpty ?? false)
        stateSemanticLabel!.trim(),
    ].join(', ');

    return EdmmSurface(
      variant: state == EdmmTrackRowState.error
          ? EdmmSurfaceVariant.outlined
          : EdmmSurfaceVariant.plain,
      tone: isSelected ? EdmmSurfaceTone.rose : EdmmSurfaceTone.neutral,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: EdmmSpacing.sm,
            vertical: EdmmSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  key: primaryActionKey,
                  container: true,
                  button: true,
                  enabled: primaryOnTap != null,
                  selected: isSelected ? true : null,
                  liveRegion: isLive,
                  label: semanticLabel,
                  onTap: primaryOnTap,
                  child: ExcludeSemantics(
                    child: InkWell(
                      onTap: primaryOnTap,
                      borderRadius: BorderRadius.circular(EdmmRadii.small),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: EdmmSpacing.xxs,
                        ),
                        child: Row(
                          children: <Widget>[
                            SizedBox.square(
                              dimension: EdmmSizes.minTouchTarget,
                              child: EdmmArtwork(
                                imageUrl: artworkUrl,
                                imageProvider: artworkProvider,
                                radius: EdmmArtworkRadius.small,
                                semantics: EdmmArtworkSemantics.decorative,
                              ),
                            ),
                            const SizedBox(width: EdmmSpacing.sm),
                            Expanded(
                              child: _TrackSummary(
                                title: title,
                                artist: artist,
                                duration: duration,
                                state: state,
                              ),
                            ),
                            if (_stateIcon != null) ...<Widget>[
                              const SizedBox(width: EdmmSpacing.xs),
                              Icon(
                                _stateIcon,
                                key: Key('edmm-track-state-${state.name}'),
                                color: _stateIconColor(colors),
                                size: 20,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (onDetails != null) ...<Widget>[
                const SizedBox(width: EdmmSpacing.xs),
                EdmmIconAction(
                  label: detailsLabel!,
                  icon: Icons.info_outline,
                  actionKey: detailsActionKey,
                  onPressed: onDetails,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData? get _stateIcon => switch (state) {
    EdmmTrackRowState.defaultState => null,
    EdmmTrackRowState.selected => Icons.check_circle,
    EdmmTrackRowState.current => Icons.radio_button_checked,
    EdmmTrackRowState.playingCurrent => Icons.graphic_eq,
    EdmmTrackRowState.unplayable => Icons.block,
    EdmmTrackRowState.error => Icons.error_outline,
  };

  Color _stateIconColor(EdmmThemeExtension colors) => switch (state) {
    EdmmTrackRowState.selected => colors.brand,
    EdmmTrackRowState.current => colors.brandSoft,
    EdmmTrackRowState.playingCurrent => colors.playbackActive,
    EdmmTrackRowState.unplayable => colors.textMuted,
    EdmmTrackRowState.error => colors.error,
    EdmmTrackRowState.defaultState => colors.textMuted,
  };
}

class _TrackSummary extends StatelessWidget {
  const _TrackSummary({
    required this.title,
    required this.artist,
    required this.duration,
    required this.state,
  });

  final String title;
  final String artist;
  final Duration? duration;
  final EdmmTrackRowState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).edmm;
    final isDisabled = state == EdmmTrackRowState.unplayable;
    final titleColor = switch (state) {
      EdmmTrackRowState.error => colors.error,
      EdmmTrackRowState.unplayable => colors.disabledContent,
      _ => colors.textPrimary,
    };
    final detailColor = isDisabled ? colors.disabledContent : colors.textMuted;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: EdmmTypography.trackTitle.copyWith(color: titleColor),
        ),
        Text(
          artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: EdmmTypography.body.copyWith(color: detailColor),
        ),
        if (duration != null) ...<Widget>[
          const SizedBox(height: EdmmSpacing.xxs),
          EdmmTimecode(value: duration!),
        ],
      ],
    );
  }
}
