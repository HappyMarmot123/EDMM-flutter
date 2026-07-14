import 'package:edmm/ui/core/themes/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../design_system/edmm_test_host.dart';

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('dark theme maps semantic colors into Material roles', () {
    final theme = AppTheme.dark;
    final extension = theme.edmm;

    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, EdmmColors.brand);
    expect(theme.colorScheme.onPrimary, EdmmColors.onBrand);
    expect(theme.colorScheme.tertiary, EdmmColors.playbackActive);
    expect(theme.scaffoldBackgroundColor, EdmmColors.canvas);
    expect(theme.colorScheme.surface, EdmmColors.surface);
    expect(extension.surfaceRose, EdmmColors.surfaceRose);
    expect(extension.focusRing, EdmmColors.focusRing);
    expect(extension.playbackActive, EdmmColors.playbackActive);
    expect(extension.disabledContent, EdmmColors.disabledContent);
  });

  test('legacy token names are aliases rather than a second palette', () {
    expect(AppThemeTokens.black, EdmmColors.canvas);
    expect(AppThemeTokens.surfaceHigh, EdmmColors.surfaceRaised);
    expect(AppThemeTokens.rose, EdmmColors.brand);
    expect(AppThemeTokens.playbackActive, EdmmColors.playbackActive);
  });

  test('interactive component themes enforce tokenized defaults', () {
    final theme = AppTheme.dark;
    const states = <WidgetState>{};

    expect(
      theme.filledButtonTheme.style!.minimumSize!.resolve(states),
      const Size(48, 48),
    );
    expect(
      theme.elevatedButtonTheme.style!.minimumSize!.resolve(states),
      const Size(48, 48),
    );
    expect(
      theme.textButtonTheme.style!.minimumSize!.resolve(states),
      const Size(48, 48),
    );
    expect(
      theme.iconButtonTheme.style!.minimumSize!.resolve(states),
      const Size.square(48),
    );
    expect(
      (theme.inputDecorationTheme.focusedBorder! as OutlineInputBorder)
          .borderSide,
      const BorderSide(color: EdmmColors.focusRing, width: 2),
    );
    expect(
      (theme.inputDecorationTheme.focusedErrorBorder! as OutlineInputBorder)
          .borderSide,
      const BorderSide(color: EdmmColors.focusRing, width: 2),
    );
    expect(theme.chipTheme.selectedColor, EdmmColors.surfaceRose);
    expect(theme.sliderTheme.activeTrackColor, EdmmColors.playbackActive);
  });

  test('focused actions resolve a solid ring above other states', () {
    final theme = AppTheme.dark;
    const focused = <WidgetState>{WidgetState.focused};
    const focusedSelected = <WidgetState>{
      WidgetState.focused,
      WidgetState.selected,
    };
    const focusedDisabled = <WidgetState>{
      WidgetState.focused,
      WidgetState.disabled,
    };
    const disabled = <WidgetState>{WidgetState.disabled};
    final styles = <ButtonStyle>[
      theme.filledButtonTheme.style!,
      theme.elevatedButtonTheme.style!,
      theme.textButtonTheme.style!,
      theme.iconButtonTheme.style!,
    ];

    for (final style in styles) {
      expect(
        style.side!.resolve(focused),
        const BorderSide(color: EdmmColors.focusRing, width: 2),
      );
      expect(
        style.side!.resolve(focusedSelected),
        const BorderSide(color: EdmmColors.focusRing, width: 2),
      );
      expect(
        style.side!.resolve(focusedDisabled),
        const BorderSide(color: EdmmColors.focusRing, width: 2),
      );
      expect(
        style.foregroundColor!.resolve(disabled),
        EdmmColors.disabledContent,
      );
    }

    final filledStyle = theme.filledButtonTheme.style!;
    expect(
      filledStyle.backgroundColor!.resolve(focused),
      EdmmColors.surfaceRose,
    );
    expect(
      filledStyle.foregroundColor!.resolve(focused),
      EdmmColors.textPrimary,
    );
    expect(
      _contrastRatio(EdmmColors.focusRing, EdmmColors.surfaceRose),
      greaterThanOrEqualTo(3),
    );
    expect(
      _contrastRatio(EdmmColors.textPrimary, EdmmColors.surfaceRose),
      greaterThanOrEqualTo(4.5),
    );

    final chipSide = theme.chipTheme.side! as WidgetStateBorderSide;
    expect(
      chipSide.resolve(focusedSelected),
      const BorderSide(color: EdmmColors.focusRing, width: 2),
    );

    expect(
      chipSide.resolve(focusedDisabled),
      const BorderSide(color: EdmmColors.focusRing, width: 2),
    );

    final sliderOverlay = theme.sliderTheme.overlayColor! as WidgetStateColor;
    expect(sliderOverlay.resolve(focused), EdmmColors.focusRing);
    expect(
      sliderOverlay.resolve(const <WidgetState>{}),
      EdmmColors.playbackActive.withValues(alpha: 0.16),
    );
  });

  test('surface and feedback component themes are explicit', () {
    final theme = AppTheme.dark;

    expect(theme.appBarTheme.backgroundColor, EdmmColors.canvas);
    expect(theme.appBarTheme.titleTextStyle!.color, EdmmColors.textPrimary);
    expect(theme.bottomSheetTheme.modalBackgroundColor, EdmmColors.canvasDeep);
    expect(
      theme.bottomSheetTheme.modalBarrierColor,
      Colors.black.withValues(alpha: EdmmEffects.backdropScrimOpacity),
    );
    expect(theme.bannerTheme.backgroundColor, EdmmColors.surfaceRaised);
    expect(theme.bannerTheme.contentTextStyle!.color, EdmmColors.textPrimary);
    expect(theme.snackBarTheme.backgroundColor, EdmmColors.surfaceRaised);
    expect(theme.snackBarTheme.contentTextStyle!.color, EdmmColors.textPrimary);
    expect(theme.tooltipTheme.decoration, isNotNull);
    expect(
      theme.tooltipTheme.textStyle!.fontSize,
      EdmmTypography.tooltip.fontSize,
    );
    expect(theme.tooltipTheme.textStyle!.height, EdmmTypography.tooltip.height);
    expect(theme.progressIndicatorTheme.color, EdmmColors.brand);
    expect(theme.listTileTheme.selectedTileColor, EdmmColors.surfaceRose);
    expect(theme.listTileTheme.minTileHeight, EdmmSizes.minTouchTarget);
    expect(
      theme.listTileTheme.subtitleTextStyle!.fontSize,
      EdmmTypography.body.fontSize,
    );
    expect(
      theme.listTileTheme.subtitleTextStyle!.height,
      EdmmTypography.body.height,
    );
  });

  testWidgets('rendered default chrome keeps explicit text colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      EdmmTestHost(
        child: Scaffold(
          appBar: AppBar(title: const Text('App bar title')),
          body: Builder(
            builder: (context) => Column(
              children: [
                MaterialBanner(
                  content: const Text('Banner content'),
                  actions: [
                    TextButton(onPressed: () {}, child: const Text('Action')),
                  ],
                ),
                FilledButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Snack content')),
                    );
                  },
                  child: const Text('Show snack'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      DefaultTextStyle.of(
        tester.element(find.text('App bar title')),
      ).style.color,
      EdmmColors.textPrimary,
    );
    expect(
      DefaultTextStyle.of(
        tester.element(find.text('Banner content')),
      ).style.color,
      EdmmColors.textPrimary,
    );

    await tester.tap(find.text('Show snack'));
    await tester.pump();
    expect(
      DefaultTextStyle.of(
        tester.element(find.text('Snack content')),
      ).style.color,
      EdmmColors.textPrimary,
    );
  });

  test('theme extension copy preserves untouched semantic roles', () {
    final changed = EdmmThemeExtension.dark.copyWith(
      surfaceRose: Colors.purple,
    );

    expect(changed.surfaceRose, Colors.purple);
    expect(changed.brand, EdmmColors.brand);
    expect(changed.playbackActive, EdmmColors.playbackActive);
  });
}
