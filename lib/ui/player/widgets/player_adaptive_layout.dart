import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/layout/edmm_breakpoints.dart';
import '../../core/themes/edmm_theme_tokens.dart';

typedef PlayerAdaptiveContentBuilder =
    Widget Function(
      BuildContext context,
      PlayerLayoutDensity density,
      double artworkSize,
    );

class PlayerAdaptiveContent extends StatelessWidget {
  const PlayerAdaptiveContent({
    super.key,
    required this.presentation,
    required this.controls,
  });

  final Widget presentation;
  final Widget controls;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[presentation, controls],
    );
  }
}

class PlayerAdaptiveLayout extends StatelessWidget {
  const PlayerAdaptiveLayout({super.key, required this.builder});

  final PlayerAdaptiveContentBuilder builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoPane = EdmmBreakpoints.usePlayerTwoPane(
          maxWidth: constraints.maxWidth,
          maxHeight: constraints.maxHeight,
        );
        final density = PlayerLayoutDensity.fromHeightClass(
          EdmmBreakpoints.heightClassFor(constraints.maxHeight),
        );
        final gutter = EdmmBreakpoints.gutterFor(constraints.maxWidth);
        final maxContentWidth = useTwoPane
            ? EdmmBreakpoints.wideContentMaxWidth
            : EdmmBreakpoints.playerOnePaneMaxWidth;
        final availableWidth = math.max(0.0, constraints.maxWidth - gutter * 2);
        final contentWidth = math.min(maxContentWidth, availableWidth);
        final paneGap = useTwoPane ? density.twoPaneGap : 0.0;
        final paneWidth = useTwoPane
            ? math.max(0.0, (contentWidth - paneGap) / 2)
            : contentWidth;
        final artworkSize = _artworkSize(
          paneWidth: paneWidth,
          maxHeight: constraints.maxHeight,
          density: density,
          useTwoPane: useTwoPane,
        );
        final builtContent = builder(context, density, artworkSize);
        final content = builtContent is PlayerAdaptiveContent
            ? builtContent
            : PlayerAdaptiveContent(
                presentation: builtContent,
                controls: const SizedBox.shrink(),
              );
        final layout = useTwoPane
            ? Row(
                key: const Key('player-two-pane'),
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: KeyedSubtree(
                      key: const Key('player-presentation-pane'),
                      child: content.presentation,
                    ),
                  ),
                  SizedBox(width: paneGap),
                  Expanded(
                    child: KeyedSubtree(
                      key: const Key('player-controls-pane'),
                      child: content.controls,
                    ),
                  ),
                ],
              )
            : Column(
                key: const Key('player-one-pane'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  KeyedSubtree(
                    key: const Key('player-presentation-pane'),
                    child: content.presentation,
                  ),
                  SizedBox(height: density.controlsGap),
                  KeyedSubtree(
                    key: const Key('player-controls-pane'),
                    child: content.controls,
                  ),
                ],
              );

        return Center(
          child: SizedBox(
            width: contentWidth,
            child: SingleChildScrollView(
              key: const Key('player-scroll-view'),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: KeyedSubtree(
                  key: const Key('player-content-column'),
                  child: layout,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _artworkSize({
    required double paneWidth,
    required double maxHeight,
    required PlayerLayoutDensity density,
    required bool useTwoPane,
  }) {
    final artworkMax = math.min(
      useTwoPane ? 300.0 : 260.0,
      math.max(96.0, paneWidth * (useTwoPane ? 0.78 : 0.72)),
    );
    final heightBudget =
        maxHeight -
        (useTwoPane
            ? density.presentationHeightBudget
            : density.controlsHeightBudget);
    return math.min(
      artworkMax,
      math.max(density.minimumArtworkSize, heightBudget),
    );
  }
}

enum PlayerLayoutDensity {
  tight,
  compact,
  regular;

  static PlayerLayoutDensity fromHeightClass(EdmmHeightClass heightClass) =>
      switch (heightClass) {
        EdmmHeightClass.tight => tight,
        EdmmHeightClass.compact => compact,
        EdmmHeightClass.regular => regular,
      };

  static PlayerLayoutDensity forHeight(double height) =>
      fromHeightClass(EdmmBreakpoints.heightClassFor(height));

  bool get isCompact => this != regular;

  double get minimumArtworkSize => switch (this) {
    tight => 64,
    compact => 80,
    regular => 120,
  };

  double get controlsHeightBudget => switch (this) {
    tight || compact => 410,
    regular => 460,
  };

  double get presentationHeightBudget => switch (this) {
    tight => 104,
    compact => 128,
    regular => 152,
  };

  double get sectionGap => switch (this) {
    tight => EdmmSpacing.xxs / 2,
    compact => EdmmSpacing.xxs,
    regular => EdmmSpacing.sm,
  };

  double get controlsGap => switch (this) {
    tight => EdmmSpacing.xxs / 2,
    compact => EdmmSpacing.xs,
    regular => EdmmSpacing.md,
  };

  double get twoPaneGap => switch (this) {
    tight => EdmmSpacing.md,
    compact => EdmmSpacing.xl,
    regular => EdmmSpacing.xxl,
  };

  double get artworkRadius => switch (this) {
    tight || compact => EdmmRadii.medium,
    regular => EdmmRadii.large,
  };

  int get metadataMaxLines => isCompact ? 1 : 2;

  double get visualizerGap => switch (this) {
    tight => 0,
    compact => EdmmSpacing.xxs / 2,
    regular => EdmmSpacing.xs,
  };

  double get visualizerHeight => switch (this) {
    tight => EdmmSpacing.xl + EdmmSpacing.xxs,
    compact => EdmmSpacing.xxxl,
    regular => EdmmSizes.minTouchTarget + EdmmSpacing.xl,
  };

  double get transportToVolumeGap => isCompact ? 0 : EdmmSpacing.xxs;
}
