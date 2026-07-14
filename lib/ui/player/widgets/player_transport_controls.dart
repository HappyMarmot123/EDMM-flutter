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
    return Wrap(
      key: const Key('player-transport-controls'),
      alignment: WrapAlignment.center,
      children: <Widget>[
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
            iconSize: 38,
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
          iconSize: 36,
          icon: const Icon(Icons.skip_previous),
          onPressed: onPrevious,
          style: secondaryActionStyle,
        ),
        IconButton(
          key: const Key('player-play-pause-button'),
          tooltip: isPlaying ? pauseLabel : playLabel,
          iconSize: 40,
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
          iconSize: 36,
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
            iconSize: 28,
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
      ],
    );
  }
}
