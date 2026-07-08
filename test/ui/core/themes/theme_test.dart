import 'package:edmm/ui/core/themes/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light theme uses EDMM rose and black tokens', () {
    final theme = AppTheme.light;

    expect(theme.colorScheme.primary, AppThemeTokens.rose);
    expect(theme.colorScheme.onPrimary, Colors.white);
    expect(theme.scaffoldBackgroundColor, AppThemeTokens.black);
    expect(theme.appBarTheme.backgroundColor, AppThemeTokens.black);
    expect(theme.cardTheme.color, AppThemeTokens.surface);
  });

  test('dark theme keeps the EDMM rose on near-black surfaces', () {
    final theme = AppTheme.dark;

    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, AppThemeTokens.rose);
    expect(theme.scaffoldBackgroundColor, AppThemeTokens.black);
    expect(theme.colorScheme.surface, AppThemeTokens.surface);
  });
}
