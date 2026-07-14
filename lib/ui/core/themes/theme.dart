import 'package:flutter/material.dart';

import 'edmm_theme_extensions.dart';
import 'edmm_theme_tokens.dart';

export 'edmm_theme_extensions.dart';
export 'edmm_theme_tokens.dart';

abstract final class AppThemeTokens {
  static const Color black = EdmmColors.canvas;
  static const Color surface = EdmmColors.surface;
  static const Color surfaceHigh = EdmmColors.surfaceRaised;
  static const Color rose = EdmmColors.brand;
  static const Color roseSoft = EdmmColors.brandSoft;
  static const Color playbackActive = EdmmColors.playbackActive;
  static const Color text = EdmmColors.textPrimary;
  static const Color muted = EdmmColors.textMuted;
  static const Color outline = EdmmColors.outline;
}

abstract final class AppTheme {
  static final ThemeData dark = _darkTheme();

  @Deprecated('EDMM is dark-only. Use AppTheme.dark.')
  static ThemeData get light => dark;

  static ThemeData _darkTheme() {
    const colorScheme = ColorScheme.dark(
      primary: EdmmColors.brand,
      onPrimary: EdmmColors.onBrand,
      primaryContainer: EdmmColors.surfaceRose,
      onPrimaryContainer: EdmmColors.brandSoft,
      secondary: EdmmColors.brandSoft,
      onSecondary: EdmmColors.onBrand,
      secondaryContainer: EdmmColors.surfaceRaised,
      onSecondaryContainer: EdmmColors.textPrimary,
      tertiary: EdmmColors.playbackActive,
      onTertiary: EdmmColors.onBrand,
      tertiaryContainer: EdmmColors.surfaceRose,
      onTertiaryContainer: EdmmColors.textPrimary,
      error: EdmmColors.error,
      onError: EdmmColors.onBrand,
      errorContainer: EdmmColors.errorContainer,
      onErrorContainer: EdmmColors.onErrorContainer,
      surface: EdmmColors.surface,
      onSurface: EdmmColors.textPrimary,
      surfaceDim: EdmmColors.canvasDeep,
      surfaceBright: EdmmColors.surfaceRaised,
      surfaceContainerLowest: EdmmColors.canvasDeep,
      surfaceContainerLow: EdmmColors.canvas,
      surfaceContainer: EdmmColors.surface,
      surfaceContainerHigh: EdmmColors.surfaceRaised,
      surfaceContainerHighest: EdmmColors.surfaceRaised,
      onSurfaceVariant: EdmmColors.textMuted,
      outline: EdmmColors.outline,
      outlineVariant: EdmmColors.outlineSubtle,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: EdmmColors.textPrimary,
      onInverseSurface: EdmmColors.canvas,
      inversePrimary: EdmmColors.onBrand,
      surfaceTint: Colors.transparent,
    );
    final textTheme =
        const TextTheme(
          displayLarge: EdmmTypography.display,
          displayMedium: EdmmTypography.display,
          displaySmall: EdmmTypography.compactDisplay,
          headlineLarge: EdmmTypography.screenTitle,
          headlineMedium: EdmmTypography.screenTitle,
          headlineSmall: EdmmTypography.screenTitle,
          titleLarge: EdmmTypography.sectionTitle,
          titleMedium: EdmmTypography.trackTitle,
          titleSmall: EdmmTypography.trackTitle,
          bodyLarge: EdmmTypography.bodyStrong,
          bodyMedium: EdmmTypography.body,
          bodySmall: EdmmTypography.body,
          labelLarge: EdmmTypography.buttonLabel,
          labelMedium: EdmmTypography.utilityLabel,
          labelSmall: EdmmTypography.timeData,
        ).apply(
          bodyColor: EdmmColors.textPrimary,
          displayColor: EdmmColors.textPrimary,
        );
    const smallShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(EdmmRadii.small)),
    );
    const mediumShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(EdmmRadii.medium)),
    );
    const largeTopShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(EdmmRadii.large),
      ),
    );
    final transparentFocusSide = WidgetStateProperty.resolveWith<BorderSide?>((
      states,
    ) {
      if (states.contains(WidgetState.focused)) {
        return const BorderSide(color: EdmmColors.focusRing, width: 2);
      }
      return const BorderSide(color: Colors.transparent, width: 2);
    });
    final outlinedFocusSide = WidgetStateProperty.resolveWith<BorderSide?>((
      states,
    ) {
      if (states.contains(WidgetState.focused)) {
        return const BorderSide(color: EdmmColors.focusRing, width: 2);
      }
      return const BorderSide(color: EdmmColors.outline, width: 2);
    });
    final chipFocusSide = WidgetStateBorderSide.resolveWith((states) {
      if (states.contains(WidgetState.focused)) {
        return const BorderSide(color: EdmmColors.focusRing, width: 2);
      }
      return const BorderSide(color: EdmmColors.outline, width: 2);
    });
    final filledBackgroundColor = WidgetStateProperty.resolveWith<Color?>((
      states,
    ) {
      if (states.contains(WidgetState.disabled)) {
        return EdmmColors.surfaceRaised;
      }
      if (states.contains(WidgetState.focused)) {
        return EdmmColors.surfaceRose;
      }
      return EdmmColors.brand;
    });
    final filledForegroundColor = WidgetStateProperty.resolveWith<Color?>((
      states,
    ) {
      if (states.contains(WidgetState.disabled)) {
        return EdmmColors.disabledContent;
      }
      if (states.contains(WidgetState.focused)) {
        return EdmmColors.textPrimary;
      }
      return EdmmColors.onBrand;
    });
    final sliderOverlayColor = WidgetStateColor.resolveWith((states) {
      if (states.contains(WidgetState.focused)) {
        return EdmmColors.focusRing;
      }
      return EdmmColors.playbackActive.withValues(alpha: 0.16);
    });

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      extensions: const <ThemeExtension<dynamic>>[EdmmThemeExtension.dark],
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: EdmmColors.canvas,
      canvasColor: EdmmColors.canvas,
      cardColor: EdmmColors.surface,
      dividerColor: EdmmColors.outline,
      disabledColor: EdmmColors.disabledContent,
      focusColor: EdmmColors.focusRing,
      hoverColor: EdmmColors.brand.withValues(alpha: 0.08),
      highlightColor: EdmmColors.brand.withValues(alpha: 0.08),
      splashColor: EdmmColors.brand.withValues(alpha: 0.12),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: const IconThemeData(color: EdmmColors.textPrimary, size: 24),
      appBarTheme: AppBarTheme(
        backgroundColor: EdmmColors.canvas,
        foregroundColor: EdmmColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: EdmmTypography.sectionTitle.copyWith(
          color: EdmmColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: EdmmColors.textPrimary, size: 24),
      ),
      cardTheme: const CardThemeData(
        color: EdmmColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(EdmmRadii.medium)),
          side: BorderSide(color: EdmmColors.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              minimumSize: const Size(
                EdmmSizes.minTouchTarget,
                EdmmSizes.minTouchTarget,
              ),
              padding: const EdgeInsets.symmetric(horizontal: EdmmSpacing.lg),
              backgroundColor: EdmmColors.brand,
              foregroundColor: EdmmColors.onBrand,
              disabledBackgroundColor: EdmmColors.surfaceRaised,
              disabledForegroundColor: EdmmColors.disabledContent,
              textStyle: EdmmTypography.buttonLabel,
              shape: mediumShape,
            ).copyWith(
              side: transparentFocusSide,
              backgroundColor: filledBackgroundColor,
              foregroundColor: filledForegroundColor,
            ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(
            EdmmSizes.minTouchTarget,
            EdmmSizes.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: EdmmSpacing.lg),
          backgroundColor: EdmmColors.surfaceRaised,
          foregroundColor: EdmmColors.textPrimary,
          disabledBackgroundColor: EdmmColors.surface,
          disabledForegroundColor: EdmmColors.disabledContent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          textStyle: EdmmTypography.buttonLabel,
          shape: mediumShape,
        ).copyWith(side: outlinedFocusSide),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(
            EdmmSizes.minTouchTarget,
            EdmmSizes.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: EdmmSpacing.md),
          foregroundColor: EdmmColors.brand,
          disabledForegroundColor: EdmmColors.disabledContent,
          textStyle: EdmmTypography.buttonLabel,
          shape: smallShape,
        ).copyWith(side: transparentFocusSide),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(EdmmSizes.minTouchTarget),
          foregroundColor: EdmmColors.textPrimary,
          disabledForegroundColor: EdmmColors.disabledContent,
          highlightColor: EdmmColors.brand.withValues(alpha: 0.12),
          shape: smallShape,
        ).copyWith(side: transparentFocusSide),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EdmmColors.surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: EdmmSpacing.md,
          vertical: EdmmSpacing.sm,
        ),
        constraints: const BoxConstraints(minHeight: EdmmSizes.minTouchTarget),
        labelStyle: EdmmTypography.bodyStrong.copyWith(
          color: EdmmColors.textPrimary,
        ),
        hintStyle: EdmmTypography.body.copyWith(color: EdmmColors.textMuted),
        helperStyle: EdmmTypography.body.copyWith(color: EdmmColors.textMuted),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(EdmmRadii.medium)),
          borderSide: BorderSide(color: EdmmColors.outline),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(EdmmRadii.medium)),
          borderSide: BorderSide(color: EdmmColors.outline),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(EdmmRadii.medium)),
          borderSide: BorderSide(color: EdmmColors.focusRing, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(EdmmRadii.medium)),
          borderSide: BorderSide(color: EdmmColors.error),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(EdmmRadii.medium)),
          borderSide: BorderSide(color: EdmmColors.focusRing, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: EdmmColors.surfaceRaised,
        disabledColor: EdmmColors.surfaceRaised.withValues(alpha: 0.5),
        selectedColor: EdmmColors.surfaceRose,
        secondarySelectedColor: EdmmColors.surfaceRose,
        surfaceTintColor: Colors.transparent,
        showCheckmark: true,
        checkmarkColor: EdmmColors.brand,
        side: chipFocusSide,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(
          horizontal: EdmmSpacing.sm,
          vertical: EdmmSpacing.xs,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: EdmmSpacing.xs),
        labelStyle: EdmmTypography.bodyStrong.copyWith(
          color: EdmmColors.textPrimary,
        ),
        secondaryLabelStyle: EdmmTypography.bodyStrong.copyWith(
          color: EdmmColors.brand,
        ),
        brightness: Brightness.dark,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: EdmmColors.playbackActive,
        inactiveTrackColor: EdmmColors.outline,
        thumbColor: EdmmColors.playbackActive,
        overlayColor: sliderOverlayColor,
        valueIndicatorColor: EdmmColors.textPrimary,
        valueIndicatorTextStyle: EdmmTypography.timeData.copyWith(
          color: EdmmColors.canvas,
        ),
        trackHeight: 4,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: EdmmColors.canvasDeep,
        modalBackgroundColor: EdmmColors.canvasDeep,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Colors.black.withValues(
          alpha: EdmmEffects.backdropScrimOpacity,
        ),
        elevation: 0,
        modalElevation: 0,
        shape: largeTopShape,
        clipBehavior: Clip.antiAlias,
        showDragHandle: false,
      ),
      bannerTheme: MaterialBannerThemeData(
        backgroundColor: EdmmColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        contentTextStyle: EdmmTypography.body.copyWith(
          color: EdmmColors.textPrimary,
        ),
        padding: const EdgeInsets.all(EdmmSpacing.md),
        leadingPadding: const EdgeInsets.only(right: EdmmSpacing.sm),
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: EdmmColors.surfaceRaised,
        actionTextColor: EdmmColors.brand,
        disabledActionTextColor: EdmmColors.disabledContent,
        contentTextStyle: EdmmTypography.body.copyWith(
          color: EdmmColors.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: mediumShape,
        insetPadding: const EdgeInsets.all(EdmmSpacing.md),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(
          color: EdmmColors.textPrimary,
          borderRadius: BorderRadius.all(Radius.circular(EdmmRadii.small)),
        ),
        textStyle: EdmmTypography.tooltip.copyWith(color: EdmmColors.canvas),
        padding: const EdgeInsets.symmetric(
          horizontal: EdmmSpacing.sm,
          vertical: EdmmSpacing.xs,
        ),
        waitDuration: const Duration(milliseconds: 500),
        showDuration: const Duration(seconds: 2),
        preferBelow: true,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: EdmmColors.brand,
        circularTrackColor: EdmmColors.outline,
        linearTrackColor: EdmmColors.surfaceRose,
        linearMinHeight: 2,
      ),
      listTileTheme: ListTileThemeData(
        shape: mediumShape,
        selectedColor: EdmmColors.brand,
        iconColor: EdmmColors.brandSoft,
        textColor: EdmmColors.textPrimary,
        titleTextStyle: EdmmTypography.trackTitle.copyWith(
          color: EdmmColors.textPrimary,
        ),
        subtitleTextStyle: EdmmTypography.body.copyWith(
          color: EdmmColors.textMuted,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: EdmmSpacing.md),
        tileColor: Colors.transparent,
        selectedTileColor: EdmmColors.surfaceRose,
        horizontalTitleGap: EdmmSpacing.sm,
        minVerticalPadding: EdmmSpacing.xs,
        minLeadingWidth: EdmmSizes.minTouchTarget,
        minTileHeight: EdmmSizes.minTouchTarget,
      ),
      dividerTheme: const DividerThemeData(
        color: EdmmColors.outline,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
