import 'package:edmm/ui/core/motion/edmm_motion.dart';
import 'package:edmm/ui/core/themes/edmm_theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrastRatio(Color foreground, Color background) {
  final lighter = foreground.computeLuminance() > background.computeLuminance()
      ? foreground.computeLuminance()
      : background.computeLuminance();
  final darker = foreground.computeLuminance() > background.computeLuminance()
      ? background.computeLuminance()
      : foreground.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('semantic colors preserve Rose Black Archive roles', () {
    expect(EdmmColors.canvasDeep, const Color(0xFF030206));
    expect(EdmmColors.canvas, const Color(0xFF050306));
    expect(EdmmColors.surfaceRose, const Color(0xFF2B111C));
    expect(EdmmColors.brand, const Color(0xFFFF98A2));
    expect(EdmmColors.playbackActive, const Color(0xFFFD6D94));
    expect(EdmmColors.disabledContent, const Color(0x61CDBDC7));
    expect(EdmmColors.focusRing, EdmmColors.brand);
    expect(EdmmColors.brand, isNot(EdmmColors.playbackActive));
  });

  test('representative text, action, and focus pairs meet contrast gates', () {
    expect(
      _contrastRatio(EdmmColors.textPrimary, EdmmColors.canvas),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(EdmmColors.textMuted, EdmmColors.surface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(EdmmColors.onBrand, EdmmColors.brand),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrastRatio(EdmmColors.focusRing, EdmmColors.canvas),
      greaterThanOrEqualTo(3),
    );
    expect(
      _contrastRatio(EdmmColors.playbackActive, EdmmColors.canvasDeep),
      greaterThanOrEqualTo(3),
    );
  });

  test('spacing, radius, size, and effect contracts are complete', () {
    expect(
      const <double>[
        EdmmSpacing.xxs,
        EdmmSpacing.xs,
        EdmmSpacing.sm,
        EdmmSpacing.md,
        EdmmSpacing.lg,
        EdmmSpacing.xl,
        EdmmSpacing.xxl,
        EdmmSpacing.xxxl,
        EdmmSpacing.display,
      ],
      const <double>[4, 8, 12, 16, 20, 24, 32, 40, 48],
    );
    expect(
      const <double>[
        EdmmRadii.small,
        EdmmRadii.medium,
        EdmmRadii.large,
        EdmmRadii.pill,
      ],
      const <double>[8, 12, 20, 999],
    );
    expect(EdmmSizes.minTouchTarget, 48);
    expect(EdmmSizes.prominentAction, 64);
    expect(EdmmEffects.backdropScrimOpacity, 0.72);
    expect(EdmmEffects.artworkBackdropBlurSigma, 28);
    expect(EdmmEffects.artworkDecodeLongestSide, 1024);
  });

  test('typography exposes hierarchy and tabular time figures', () {
    expect(EdmmTypography.display.fontSize, 32);
    expect(EdmmTypography.display.fontWeight, FontWeight.w900);
    expect(EdmmTypography.screenTitle.fontSize, 26);
    expect(EdmmTypography.trackTitle.fontSize, 15);
    expect(EdmmTypography.body.fontSize, 14);
    expect(EdmmTypography.utilityLabel.letterSpacing, 0.6);
    expect(EdmmTypography.timeData.fontFeatures, hasLength(1));
    expect(EdmmTypography.timeData.fontFeatures!.single.feature, 'tnum');
    expect(EdmmTypography.tooltip.fontSize, 12);
    expect(EdmmTypography.tooltip.height, 16 / 12);
  });

  test('motion timing and reduced-motion resolver are deterministic', () {
    expect(EdmmMotion.quick, const Duration(milliseconds: 120));
    expect(EdmmMotion.standard, const Duration(milliseconds: 180));
    expect(EdmmMotion.emphasis, const Duration(milliseconds: 280));
    expect(EdmmMotion.ambient, const Duration(milliseconds: 450));
    expect(
      EdmmMotion.resolve(EdmmMotion.standard, reduceMotion: false),
      EdmmMotion.standard,
    );
    expect(
      EdmmMotion.resolve(EdmmMotion.ambient, reduceMotion: true),
      Duration.zero,
    );
  });

  testWidgets('context resolver reads disableAnimations', (tester) async {
    late Duration resolved;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            resolved = EdmmMotion.resolveForContext(
              context,
              EdmmMotion.emphasis,
            );
            return const SizedBox();
          },
        ),
      ),
    );

    expect(resolved, Duration.zero);
  });

  testWidgets('context resolver reads accessibleNavigation', (tester) async {
    late Duration resolved;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(accessibleNavigation: true),
        child: Builder(
          builder: (context) {
            resolved = EdmmMotion.resolveForContext(
              context,
              EdmmMotion.standard,
            );
            return const SizedBox();
          },
        ),
      ),
    );

    expect(resolved, Duration.zero);
  });

  testWidgets('context resolver preserves motion without MediaQuery', (
    tester,
  ) async {
    late Duration resolved;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          resolved = EdmmMotion.resolveForContext(context, EdmmMotion.quick);
          return const SizedBox();
        },
      ),
    );

    expect(resolved, EdmmMotion.quick);
  });
}
