import 'package:edmm/ui/core/layout/edmm_breakpoints.dart';
import 'package:edmm/ui/core/widgets/edmm_content_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../design_system/edmm_test_host.dart';

void main() {
  for (final (viewportWidth, gutter) in <(double, double)>[
    (320, EdmmBreakpoints.compactGutter),
    (600, EdmmBreakpoints.mediumGutter),
    (840, EdmmBreakpoints.expandedGutter),
  ]) {
    testWidgets('uses a ${gutter}dp gutter at ${viewportWidth}dp', (
      tester,
    ) async {
      await pumpEdmmTestHost(
        tester,
        viewport: Size(viewportWidth, 568),
        child: const Scaffold(
          body: EdmmContentLayout(
            child: ColoredBox(key: Key('content'), color: Colors.transparent),
          ),
        ),
      );

      final rect = tester.getRect(find.byKey(const Key('content')));
      expect(rect.left, gutter);
      expect(rect.width, viewportWidth - (gutter * 2));
    });
  }

  testWidgets('centers standard and wide tokenized max widths', (tester) async {
    await pumpEdmmTestHost(
      tester,
      viewport: const Size(1200, 800),
      child: const Scaffold(
        body: EdmmContentLayout(
          child: ColoredBox(
            key: Key('wide-content'),
            color: Colors.transparent,
          ),
        ),
      ),
    );

    var rect = tester.getRect(find.byKey(const Key('wide-content')));
    expect(rect.width, EdmmBreakpoints.wideContentMaxWidth);
    expect(rect.left, 40);

    await pumpEdmmTestHost(
      tester,
      viewport: const Size(1200, 800),
      child: const Scaffold(
        body: EdmmContentLayout(
          width: EdmmContentWidth.standard,
          child: ColoredBox(
            key: Key('standard-content'),
            color: Colors.transparent,
          ),
        ),
      ),
    );

    rect = tester.getRect(find.byKey(const Key('standard-content')));
    expect(rect.width, EdmmBreakpoints.standardContentMaxWidth);
    expect(rect.left, 240);
  });

  testWidgets('owns no scrolling and supports 320px at text scale 2', (
    tester,
  ) async {
    await pumpEdmmTestHost(
      tester,
      viewport: EdmmTestViewports.compactPhone,
      textScale: 2,
      child: const Scaffold(
        body: EdmmContentLayout(
          width: EdmmContentWidth.standard,
          child: Text(
            'A long content title that remains caller-owned and may wrap.',
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Scrollable), findsNothing);
    expect(find.byType(FittedBox), findsNothing);
  });
}
