import 'dart:ui' show Tristate;

import 'package:edmm/ui/core/themes/theme.dart';
import 'package:edmm/ui/core/widgets/edmm_icon_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../design_system/edmm_test_host.dart';

void main() {
  testWidgets('icon action exposes label, states, callback, and 48dp target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await pumpEdmmTestHost(
      tester,
      child: Scaffold(
        body: Row(
          children: <Widget>[
            EdmmIconAction(
              key: const Key('selected-action'),
              label: 'Selected action',
              icon: Icons.check_circle_outline,
              selectedIcon: Icons.check_circle,
              selected: true,
              actionKey: const Key('selected-action-button'),
              onPressed: () => taps++,
            ),
            const EdmmIconAction(
              key: Key('disabled-action'),
              label: 'Disabled action',
              icon: Icons.block,
              onPressed: null,
            ),
          ],
        ),
      ),
    );

    final selectedRect = tester.getRect(
      find.byKey(const Key('selected-action')),
    );
    expect(selectedRect.width, greaterThanOrEqualTo(48));
    expect(selectedRect.height, greaterThanOrEqualTo(48));
    expect(
      tester
          .getSemantics(find.byKey(const Key('selected-action')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(
      tester
          .getSemantics(find.byKey(const Key('disabled-action')))
          .flagsCollection
          .isEnabled,
      Tristate.isFalse,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('selected-action-button')))
          .tooltip,
      'Selected action',
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('selected-action')),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('selected-action')));
    await tester.pump();
    expect(taps, 1);
    semantics.dispose();
  });

  testWidgets('focus ring and pressed feedback do not change geometry', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await pumpEdmmTestHost(
      tester,
      child: Scaffold(
        body: Center(
          child: EdmmIconAction(
            key: const Key('focus-action'),
            label: 'Focus action',
            icon: Icons.graphic_eq,
            selected: true,
            focusNode: focusNode,
            onPressed: () {},
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();
    final finder = find.byKey(const Key('focus-action'));
    final before = tester.getRect(finder);
    final button = tester.widget<IconButton>(
      find.descendant(of: finder, matching: find.byType(IconButton)),
    );
    expect(
      button.style!.side!.resolve(const <WidgetState>{WidgetState.focused}),
      const BorderSide(color: EdmmColors.focusRing, width: 2),
    );

    final gesture = await tester.startGesture(before.center);
    await tester.pump();
    expect(tester.getRect(finder), before);
    await gesture.up();
    await tester.pump();
  });

  testWidgets('prominent action uses the tokenized 64dp target', (
    tester,
  ) async {
    await pumpEdmmTestHost(
      tester,
      child: Scaffold(
        body: EdmmIconAction(
          key: const Key('prominent-action'),
          label: 'Play',
          icon: Icons.play_arrow,
          emphasis: EdmmIconActionEmphasis.prominent,
          onPressed: () {},
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('prominent-action'))),
      const Size.square(EdmmSizes.prominentAction),
    );
  });
}
