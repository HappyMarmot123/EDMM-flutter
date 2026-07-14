import 'package:flutter/material.dart';

import '../../core/themes/edmm_theme_extensions.dart';
import '../../core/themes/edmm_theme_tokens.dart';

class PlayerTransportControls extends StatelessWidget {
  const PlayerTransportControls({
    super.key,
    required this.shuffleEnabled,
    required this.isPlaying,
    required this.visualizerEnabled,
    required this.visualizerAvailable,
    required this.shuffleLabel,
    required this.previousLabel,
    required this.playLabel,
    required this.pauseLabel,
    required this.nextLabel,
    required this.visualizerEnableLabel,
    required this.visualizerDisableLabel,
    required this.visualizerUnavailableLabel,
    required this.onToggleShuffle,
    required this.onPrevious,
    required this.onPlayPause,
    required this.onNext,
    required this.onToggleVisualizer,
    this.visualizerLabel,
  });

  final bool shuffleEnabled;
  final bool isPlaying;
  final bool visualizerEnabled;
  final bool visualizerAvailable;
  final String shuffleLabel;
  final String previousLabel;
  final String playLabel;
  final String pauseLabel;
  final String nextLabel;
  final String visualizerEnableLabel;
  final String visualizerDisableLabel;
  final String visualizerUnavailableLabel;
  final VoidCallback onToggleShuffle;
  final VoidCallback onPrevious;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onToggleVisualizer;
  final String? visualizerLabel;

  static const double _utilityIconSize = 24;
  static const double _primaryIconSize = 32;
  static const double _controlWidths =
      EdmmSizes.minTouchTarget * 4 + EdmmSizes.prominentAction;
  static const int _controlGaps = 4;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).edmm;
    final secondaryActionStyle = IconButton.styleFrom(
      fixedSize: const Size.square(EdmmSizes.minTouchTarget),
      padding: EdgeInsets.zero,
    );
    final visualizerActionLabel = !visualizerAvailable
        ? visualizerUnavailableLabel
        : visualizerEnabled
        ? visualizerDisableLabel
        : visualizerEnableLabel;
    final controls = <Widget>[
      Semantics(
        key: const Key('player-shuffle-semantics'),
        excludeSemantics: true,
        label: shuffleLabel,
        button: true,
        toggled: shuffleEnabled,
        onTap: onToggleShuffle,
        child: IconButton(
          key: const Key('player-shuffle-button'),
          tooltip: shuffleLabel,
          iconSize: _utilityIconSize,
          icon: Icon(
            shuffleEnabled ? Icons.shuffle_on : Icons.shuffle,
            color: shuffleEnabled ? colors.playbackActive : null,
          ),
          onPressed: onToggleShuffle,
          style: secondaryActionStyle,
        ),
      ),
      IconButton(
        key: const Key('player-previous-button'),
        tooltip: previousLabel,
        iconSize: _utilityIconSize,
        icon: const Icon(Icons.skip_previous),
        onPressed: onPrevious,
        style: secondaryActionStyle,
      ),
      IconButton(
        key: const Key('player-play-pause-button'),
        tooltip: isPlaying ? pauseLabel : playLabel,
        iconSize: _primaryIconSize,
        icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
        onPressed: onPlayPause,
        style: IconButton.styleFrom(
          fixedSize: const Size.square(EdmmSizes.prominentAction),
          padding: EdgeInsets.zero,
          backgroundColor: colors.brand,
          foregroundColor: colors.onBrand,
        ),
      ),
      IconButton(
        key: const Key('player-next-button'),
        tooltip: nextLabel,
        iconSize: _utilityIconSize,
        icon: const Icon(Icons.skip_next),
        onPressed: onNext,
        style: secondaryActionStyle,
      ),
      Semantics(
        key: const Key('player-visualizer-semantics'),
        excludeSemantics: true,
        label: visualizerLabel ?? visualizerActionLabel,
        button: true,
        enabled: visualizerAvailable,
        toggled: visualizerEnabled,
        onTap: visualizerAvailable ? onToggleVisualizer : null,
        child: IconButton(
          key: const Key('player-visualizer-toggle'),
          tooltip: visualizerActionLabel,
          iconSize: _utilityIconSize,
          icon: Icon(
            visualizerEnabled ? Icons.graphic_eq : Icons.bar_chart_outlined,
            color: visualizerEnabled && visualizerAvailable
                ? colors.playbackActive
                : null,
          ),
          onPressed: visualizerAvailable ? onToggleVisualizer : null,
          style: secondaryActionStyle,
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : _controlWidths + EdmmSpacing.xs * _controlGaps;
        final spacing = ((availableWidth - _controlWidths) / _controlGaps)
            .clamp(0.0, EdmmSpacing.xs)
            .toDouble();

        return Wrap(
          key: const Key('player-transport-controls'),
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: spacing,
          runSpacing: EdmmSpacing.xs,
          children: controls,
        );
      },
    );
  }
}
