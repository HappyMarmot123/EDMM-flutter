import 'package:flutter/material.dart';

import '../../core/themes/edmm_theme_extensions.dart';
import '../../core/themes/edmm_theme_tokens.dart';

String _formatVolumePercent(double volume) =>
    '${(volume.clamp(0.0, 1.0) * 100).round()}%';

double _semanticAdjustmentFraction(TargetPlatform platform) =>
    switch (platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => 0.1,
      TargetPlatform.android ||
      TargetPlatform.fuchsia ||
      TargetPlatform.linux ||
      TargetPlatform.windows => 0.05,
    };

double _adjustVolumeForSemantics({
  required double volume,
  required TargetPlatform platform,
  required bool increase,
}) {
  final delta = _semanticAdjustmentFraction(platform);
  return (volume + (increase ? delta : -delta)).clamp(0.0, 1.0).toDouble();
}

class PlayerVolumeControls extends StatelessWidget {
  const PlayerVolumeControls({
    super.key,
    required this.isMuted,
    required this.volume,
    required this.muteLabel,
    required this.unmuteLabel,
    required this.onToggleMute,
    required this.onVolumeChanged,
    this.semanticLabel,
  });

  final bool isMuted;
  final double volume;
  final String muteLabel;
  final String unmuteLabel;
  final VoidCallback onToggleMute;
  final ValueChanged<double> onVolumeChanged;
  final String? semanticLabel;

  IconData get _volumeIcon {
    if (isMuted || volume <= 0) return Icons.volume_off;
    if (volume < 0.5) return Icons.volume_down;
    return Icons.volume_up;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).edmm;
    final platform = Theme.of(context).platform;
    final increasedVolume = _adjustVolumeForSemantics(
      volume: volume,
      platform: platform,
      increase: true,
    );
    final decreasedVolume = _adjustVolumeForSemantics(
      volume: volume,
      platform: platform,
      increase: false,
    );
    Widget slider = Slider(
      key: const Key('player-volume-slider'),
      activeColor: colors.playbackActive,
      value: volume,
      min: 0,
      max: 1,
      semanticFormatterCallback: _formatVolumePercent,
      onChanged: onVolumeChanged,
    );
    if (semanticLabel != null) {
      slider = Semantics(
        key: const Key('player-volume-semantics'),
        container: true,
        excludeSemantics: true,
        enabled: true,
        focusable: true,
        slider: true,
        label: semanticLabel,
        value: _formatVolumePercent(volume),
        increasedValue: _formatVolumePercent(increasedVolume),
        decreasedValue: _formatVolumePercent(decreasedVolume),
        onIncrease: () => onVolumeChanged(increasedVolume),
        onDecrease: () => onVolumeChanged(decreasedVolume),
        child: slider,
      );
    }

    return Row(
      key: const Key('player-volume-controls'),
      children: [
        IconButton(
          key: const Key('player-volume-mute-button'),
          tooltip: isMuted ? unmuteLabel : muteLabel,
          icon: Icon(_volumeIcon),
          onPressed: onToggleMute,
        ),
        Expanded(child: slider),
        ExcludeSemantics(
          child: Text(
            _formatVolumePercent(volume),
            style: EdmmTypography.timeData.copyWith(color: colors.textMuted),
          ),
        ),
      ],
    );
  }
}
