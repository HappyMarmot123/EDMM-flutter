import 'dart:ui' show Tristate;

import 'package:edmm/ui/core/widgets/edmm_filter_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../design_system/edmm_test_host.dart';

void main() {
  testWidgets('filter pills wrap at 320dp with large text without shrinking', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var selected = '';
    await pumpEdmmTestHost(
      tester,
      viewport: EdmmTestViewports.compactPhone,
      textScale: 2,
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              EdmmFilterPill(
                key: const Key('filter-pop'),
                label: 'Pop',
                count: 120,
                selected: true,
                onPressed: () => selected = 'pop',
              ),
              EdmmFilterPill(
                key: const Key('filter-edm'),
                label: 'EDM',
                count: 80,
                selected: false,
                onPressed: () => selected = 'edm',
                showCount: false,
              ),
              const EdmmFilterPill(
                key: Key('filter-recent'),
                label: 'Recent',
                count: 3,
                selected: false,
                onPressed: null,
                showCount: false,
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(FittedBox), findsNothing);
    expect(find.text('Pop (120)'), findsOneWidget);
    expect(find.text('EDM'), findsOneWidget);
    expect(find.text('EDM (80)'), findsNothing);
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Recent (3)'), findsNothing);
    for (final key in const <Key>[
      Key('filter-pop'),
      Key('filter-edm'),
      Key('filter-recent'),
    ]) {
      final rect = tester.getRect(find.byKey(key));
      expect(rect.height, greaterThanOrEqualTo(48));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
    }
    expect(
      tester
          .getSemantics(find.byKey(const Key('filter-pop')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(
      tester.getSemantics(find.byKey(const Key('filter-pop'))).label,
      'Pop (120)',
    );
    expect(
      tester.getSemantics(find.byKey(const Key('filter-edm'))).label,
      'EDM',
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('filter-recent')))
          .flagsCollection
          .isEnabled,
      Tristate.isFalse,
    );
    expect(
      tester.getSemantics(find.byKey(const Key('filter-recent'))).label,
      'Recent',
    );

    await tester.tap(find.byKey(const Key('filter-edm')));
    await tester.pump();
    expect(selected, 'edm');
    semantics.dispose();
  });
}
