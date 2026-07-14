import 'package:flutter/material.dart';

import '../../../domain/audio/audio_effects_controller.dart';
import '../../core/themes/edmm_theme_tokens.dart';

class PlayerEqualizerPanel extends StatelessWidget {
  const PlayerEqualizerPanel({
    super.key,
    required this.support,
    required this.preset,
    required this.compact,
    required this.equalizerLabel,
    required this.unsupportedPlatformLabel,
    required this.unavailableLabel,
    required this.flatLabel,
    required this.flatTooltip,
    required this.bassLabel,
    required this.bassTooltip,
    required this.onPresetSelected,
  });

  final AudioEqualizerSupport support;
  final AudioEqualizerPreset preset;
  final bool compact;
  final String equalizerLabel;
  final String unsupportedPlatformLabel;
  final String unavailableLabel;
  final String flatLabel;
  final String flatTooltip;
  final String bassLabel;
  final String bassTooltip;
  final ValueChanged<AudioEqualizerPreset> onPresetSelected;

  @override
  Widget build(BuildContext context) {
    final unavailableCopy =
        support == AudioEqualizerSupport.unsupportedOnPlatform
        ? unsupportedPlatformLabel
        : unavailableLabel;

    return ConstrainedBox(
      key: const Key('player-eq-panel'),
      constraints: BoxConstraints(
        minHeight: compact
            ? EdmmSizes.minTouchTarget
            : EdmmSizes.minTouchTarget + EdmmSpacing.xl,
      ),
      child: support != AudioEqualizerSupport.supported
          ? Center(
              child: Text(
                unavailableCopy,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          : Wrap(
              alignment: compact ? WrapAlignment.center : WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: EdmmSpacing.xs,
              runSpacing: compact ? EdmmSpacing.xxs / 2 : EdmmSpacing.xxs,
              children: [
                Text(
                  equalizerLabel,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                _EqualizerPresetChip(
                  key: const Key('player-eq-preset-flat'),
                  label: flatLabel,
                  tooltip: flatTooltip,
                  selected: preset == AudioEqualizerPreset.flat,
                  onSelected: () => onPresetSelected(AudioEqualizerPreset.flat),
                ),
                _EqualizerPresetChip(
                  key: const Key('player-eq-preset-bass'),
                  label: bassLabel,
                  tooltip: bassTooltip,
                  selected: preset == AudioEqualizerPreset.bassBoost,
                  onSelected: () =>
                      onPresetSelected(AudioEqualizerPreset.bassBoost),
                ),
              ],
            ),
    );
  }
}

class _EqualizerPresetChip extends StatelessWidget {
  const _EqualizerPresetChip({
    super.key,
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final String tooltip;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}
