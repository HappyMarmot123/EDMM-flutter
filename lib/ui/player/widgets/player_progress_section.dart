import 'package:flutter/material.dart';

import '../../core/themes/edmm_theme_extensions.dart';
import '../../core/themes/edmm_theme_tokens.dart';

String formatPlaybackDuration(Duration duration) {
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (duration.inHours > 0) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    return '${duration.inHours}:$minutes:$seconds';
  }
  return '${duration.inMinutes.toString().padLeft(2, '0')}:$seconds';
}

typedef PlayerProgressSemanticValueFormatter =
    String Function(Duration position, Duration duration);

double _semanticAdjustmentFraction(TargetPlatform platform) =>
    switch (platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => 0.1,
      TargetPlatform.android ||
      TargetPlatform.fuchsia ||
      TargetPlatform.linux ||
      TargetPlatform.windows => 0.05,
    };

double _adjustProgressForSemantics({
  required double value,
  required double max,
  required TargetPlatform platform,
  required bool increase,
}) {
  final delta = max * _semanticAdjustmentFraction(platform);
  return (value + (increase ? delta : -delta)).clamp(0.0, max).toDouble();
}

class PlayerProgressSection extends StatelessWidget {
  const PlayerProgressSection({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.semanticLabel,
    this.semanticValueFormatter,
  });

  final Stream<Duration> position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final String? semanticLabel;
  final PlayerProgressSemanticValueFormatter? semanticValueFormatter;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).edmm;
    return StreamBuilder<Duration>(
      stream: position,
      builder: (context, snapshot) {
        final currentPosition = snapshot.data ?? Duration.zero;
        final total = duration.inMilliseconds == 0
            ? 1
            : duration.inMilliseconds;
        final sliderValue = currentPosition.inMilliseconds
            .clamp(0, total)
            .toDouble();
        final platform = Theme.of(context).platform;
        final increasedValue = _adjustProgressForSemantics(
          value: sliderValue,
          max: total.toDouble(),
          platform: platform,
          increase: true,
        );
        final decreasedValue = _adjustProgressForSemantics(
          value: sliderValue,
          max: total.toDouble(),
          platform: platform,
          increase: false,
        );

        String formatSemanticValue(double value) {
          final formatter = semanticValueFormatter;
          if (formatter != null) {
            return formatter(Duration(milliseconds: value.round()), duration);
          }
          return '${((value / total) * 100).round()}%';
        }

        Widget slider = Slider(
          key: const Key('player-progress-slider'),
          activeColor: colors.playbackActive,
          value: sliderValue,
          max: total.toDouble(),
          semanticFormatterCallback: semanticValueFormatter == null
              ? null
              : formatSemanticValue,
          onChanged: (value) {
            onSeek(Duration(milliseconds: value.round()));
          },
        );
        if (semanticLabel != null) {
          slider = Semantics(
            key: const Key('player-progress-semantics'),
            container: true,
            excludeSemantics: true,
            enabled: true,
            focusable: true,
            slider: true,
            label: semanticLabel,
            value: formatSemanticValue(sliderValue),
            increasedValue: formatSemanticValue(increasedValue),
            decreasedValue: formatSemanticValue(decreasedValue),
            onIncrease: () =>
                onSeek(Duration(milliseconds: increasedValue.round())),
            onDecrease: () =>
                onSeek(Duration(milliseconds: decreasedValue.round())),
            child: slider,
          );
        }

        return Column(
          children: <Widget>[
            slider,
            ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    formatPlaybackDuration(currentPosition),
                    style: EdmmTypography.timeData.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                  Text(
                    formatPlaybackDuration(duration),
                    style: EdmmTypography.timeData.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
