import 'package:flutter/material.dart';

abstract final class AppThemeTokens {
  static const Color black = Color(0xFF09090B);
  static const Color surface = Color(0xFF141116);
  static const Color surfaceHigh = Color(0xFF1F1820);
  static const Color rose = Color(0xFFE11D48);
  static const Color roseSoft = Color(0xFFFFD7DF);
  static const Color text = Color(0xFFF8FAFC);
  static const Color muted = Color(0xFFB8AAB0);
  static const Color outline = Color(0xFF3A2B32);
}

abstract final class AppTheme {
  static final ThemeData light = _theme();
  static final ThemeData dark = _theme();

  static ThemeData _theme() {
    final colorScheme = const ColorScheme.dark(
      primary: AppThemeTokens.rose,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF5F1124),
      onPrimaryContainer: AppThemeTokens.roseSoft,
      secondary: Color(0xFFF472B6),
      onSecondary: AppThemeTokens.black,
      secondaryContainer: AppThemeTokens.surfaceHigh,
      onSecondaryContainer: AppThemeTokens.text,
      surface: AppThemeTokens.surface,
      onSurface: AppThemeTokens.text,
      error: Color(0xFFFF6B7A),
      onError: AppThemeTokens.black,
      errorContainer: Color(0xFF4B1118),
      onErrorContainer: Color(0xFFFFD8DE),
      outline: AppThemeTokens.outline,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppThemeTokens.black,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppThemeTokens.black,
        foregroundColor: AppThemeTokens.text,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppThemeTokens.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppThemeTokens.outline),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppThemeTokens.surfaceHigh,
          foregroundColor: AppThemeTokens.text,
          disabledBackgroundColor: AppThemeTokens.surface,
          disabledForegroundColor: AppThemeTokens.muted,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppThemeTokens.roseSoft),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppThemeTokens.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppThemeTokens.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppThemeTokens.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppThemeTokens.rose, width: 1.4),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppThemeTokens.rose,
        thumbColor: AppThemeTokens.rose,
        inactiveTrackColor: AppThemeTokens.outline,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppThemeTokens.text),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppThemeTokens.roseSoft,
        textColor: AppThemeTokens.text,
      ),
    );
  }
}
