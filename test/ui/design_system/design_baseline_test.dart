import 'package:edmm/l10n/app_localizations.dart';
import 'package:edmm/ui/core/themes/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'edmm_test_host.dart';

const _probeKey = Key('design-baseline-probe');

Widget _probe() => const SizedBox.expand(key: _probeKey);

void main() {
  for (final testCase in const [
    (
      label: 'compact English motion-on',
      viewport: EdmmTestViewports.compactPhone,
      locale: Locale('en'),
      textScale: 1.0,
      disableAnimations: false,
    ),
    (
      label: 'standard Korean large-text motion-off',
      viewport: EdmmTestViewports.standardPhone,
      locale: Locale('ko'),
      textScale: 2.0,
      disableAnimations: true,
    ),
    (
      label: 'tablet English motion-on',
      viewport: EdmmTestViewports.tabletPortrait,
      locale: Locale('en'),
      textScale: 1.0,
      disableAnimations: false,
    ),
  ]) {
    testWidgets('test host applies ${testCase.label} fixture', (tester) async {
      await pumpEdmmTestHost(
        tester,
        viewport: testCase.viewport,
        locale: testCase.locale,
        textScale: testCase.textScale,
        disableAnimations: testCase.disableAnimations,
        child: _probe(),
      );

      final context = tester.element(find.byKey(_probeKey));
      final mediaQuery = MediaQuery.of(context);

      expect(tester.getSize(find.byKey(_probeKey)), testCase.viewport);
      expect(mediaQuery.size, testCase.viewport);
      expect(mediaQuery.devicePixelRatio, 1);
      expect(mediaQuery.textScaler.scale(10), 10 * testCase.textScale);
      expect(mediaQuery.disableAnimations, testCase.disableAnimations);
      expect(Localizations.localeOf(context), testCase.locale);
      expect(
        AppLocalizations.of(context).localeName,
        testCase.locale.languageCode,
      );
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(
        Theme.of(context).colorScheme.primary,
        AppTheme.dark.colorScheme.primary,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('test host injects DPR, safe area, and view insets', (
    tester,
  ) async {
    const safeArea = EdgeInsets.only(top: 47, bottom: 34);
    const viewInsets = EdgeInsets.only(bottom: 280);

    await pumpEdmmTestHost(
      tester,
      viewport: EdmmTestViewports.compactPhone,
      devicePixelRatio: 2,
      safeArea: safeArea,
      viewInsets: viewInsets,
      child: _probe(),
    );

    final mediaQuery = MediaQuery.of(tester.element(find.byKey(_probeKey)));
    expect(mediaQuery.size, EdmmTestViewports.compactPhone);
    expect(mediaQuery.devicePixelRatio, 2);
    expect(mediaQuery.padding, safeArea);
    expect(mediaQuery.viewPadding, safeArea);
    expect(mediaQuery.viewInsets, viewInsets);
  });
}
