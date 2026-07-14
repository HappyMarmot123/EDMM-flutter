import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('EdmmApp explicitly pins the product to dark mode', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('darkTheme: AppTheme.dark'));
    expect(source, contains('themeMode: ThemeMode.dark'));
    expect(source, isNot(contains('theme: AppTheme.light')));
  });
}
