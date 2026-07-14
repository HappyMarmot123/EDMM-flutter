import 'package:flutter/material.dart';

import 'edmm_theme_tokens.dart';

@immutable
class EdmmThemeExtension extends ThemeExtension<EdmmThemeExtension> {
  const EdmmThemeExtension({
    required this.canvasDeep,
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceRose,
    required this.brand,
    required this.brandSoft,
    required this.playbackActive,
    required this.textPrimary,
    required this.textMuted,
    required this.disabledContent,
    required this.onBrand,
    required this.outline,
    required this.outlineBrand,
    required this.focusRing,
    required this.error,
  });

  static const EdmmThemeExtension dark = EdmmThemeExtension(
    canvasDeep: EdmmColors.canvasDeep,
    canvas: EdmmColors.canvas,
    surface: EdmmColors.surface,
    surfaceRaised: EdmmColors.surfaceRaised,
    surfaceRose: EdmmColors.surfaceRose,
    brand: EdmmColors.brand,
    brandSoft: EdmmColors.brandSoft,
    playbackActive: EdmmColors.playbackActive,
    textPrimary: EdmmColors.textPrimary,
    textMuted: EdmmColors.textMuted,
    disabledContent: EdmmColors.disabledContent,
    onBrand: EdmmColors.onBrand,
    outline: EdmmColors.outline,
    outlineBrand: EdmmColors.outlineBrand,
    focusRing: EdmmColors.focusRing,
    error: EdmmColors.error,
  );

  final Color canvasDeep;
  final Color canvas;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceRose;
  final Color brand;
  final Color brandSoft;
  final Color playbackActive;
  final Color textPrimary;
  final Color textMuted;
  final Color disabledContent;
  final Color onBrand;
  final Color outline;
  final Color outlineBrand;
  final Color focusRing;
  final Color error;

  static EdmmThemeExtension of(BuildContext context) {
    final extension = Theme.of(context).extension<EdmmThemeExtension>();
    assert(extension != null, 'EdmmThemeExtension is missing from ThemeData.');
    return extension!;
  }

  @override
  EdmmThemeExtension copyWith({
    Color? canvasDeep,
    Color? canvas,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceRose,
    Color? brand,
    Color? brandSoft,
    Color? playbackActive,
    Color? textPrimary,
    Color? textMuted,
    Color? disabledContent,
    Color? onBrand,
    Color? outline,
    Color? outlineBrand,
    Color? focusRing,
    Color? error,
  }) {
    return EdmmThemeExtension(
      canvasDeep: canvasDeep ?? this.canvasDeep,
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceRose: surfaceRose ?? this.surfaceRose,
      brand: brand ?? this.brand,
      brandSoft: brandSoft ?? this.brandSoft,
      playbackActive: playbackActive ?? this.playbackActive,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      disabledContent: disabledContent ?? this.disabledContent,
      onBrand: onBrand ?? this.onBrand,
      outline: outline ?? this.outline,
      outlineBrand: outlineBrand ?? this.outlineBrand,
      focusRing: focusRing ?? this.focusRing,
      error: error ?? this.error,
    );
  }

  @override
  EdmmThemeExtension lerp(covariant EdmmThemeExtension? other, double t) {
    if (other == null) {
      return this;
    }
    return EdmmThemeExtension(
      canvasDeep: Color.lerp(canvasDeep, other.canvasDeep, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceRose: Color.lerp(surfaceRose, other.surfaceRose, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      playbackActive: Color.lerp(playbackActive, other.playbackActive, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      disabledContent: Color.lerp(disabledContent, other.disabledContent, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineBrand: Color.lerp(outlineBrand, other.outlineBrand, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

extension EdmmThemeDataX on ThemeData {
  EdmmThemeExtension get edmm {
    final value = extension<EdmmThemeExtension>();
    assert(value != null, 'EdmmThemeExtension is missing from ThemeData.');
    return value!;
  }
}
