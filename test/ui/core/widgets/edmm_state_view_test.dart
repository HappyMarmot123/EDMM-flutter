import 'package:edmm/ui/core/widgets/edmm_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../design_system/edmm_test_host.dart';

void main() {
  testWidgets('error announces caller text and keeps retry independent', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var retries = 0;
    await pumpEdmmTestHost(
      tester,
      child: Scaffold(
        body: EdmmStateView(
          key: const Key('error-state'),
          kind: EdmmStateKind.error,
          title: 'Could not load tracks',
          message: 'Check your connection.',
          actionLabel: 'Try again',
          onAction: () => retries++,
        ),
      ),
    );

    final node = tester.getSemantics(find.byKey(const Key('error-state')));
    expect(node.label, 'Could not load tracks. Check your connection.');
    expect(node.flagsCollection.isLiveRegion, isTrue);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(retries, 1);
    semantics.dispose();
  });

  testWidgets('empty and search-empty have distinct non-color cues', (
    tester,
  ) async {
    await pumpEdmmTestHost(
      tester,
      child: const Scaffold(
        body: Column(
          children: <Widget>[
            EdmmStateView(kind: EdmmStateKind.empty, title: 'Nothing here'),
            EdmmStateView(kind: EdmmStateKind.searchEmpty, title: 'No matches'),
          ],
        ),
      ),
    );

    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    expect(find.byIcon(Icons.search_off), findsOneWidget);
  });

  testWidgets('loading pulse keeps fixed geometry', (tester) async {
    await pumpEdmmTestHost(
      tester,
      child: const Scaffold(
        body: EdmmStateView(
          kind: EdmmStateKind.loading,
          title: 'Loading tracks',
        ),
      ),
    );

    final skeleton = find.byKey(const Key('edmm-state-skeleton'));
    final pulse = find.byKey(const Key('edmm-state-skeleton-pulse'));
    final beforeRect = tester.getRect(skeleton);
    final beforeOpacity = tester.widget<FadeTransition>(pulse).opacity.value;
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.getRect(skeleton), beforeRect);
    expect(
      tester.widget<FadeTransition>(pulse).opacity.value,
      isNot(beforeOpacity),
    );
  });

  testWidgets('reduced motion stops the loading pulse', (tester) async {
    await pumpEdmmTestHost(
      tester,
      disableAnimations: true,
      child: const Scaffold(
        body: EdmmStateView(
          kind: EdmmStateKind.loading,
          title: 'Loading tracks',
        ),
      ),
    );

    final skeleton = find.byKey(const Key('edmm-state-skeleton'));
    final pulse = find.byKey(const Key('edmm-state-skeleton-pulse'));
    final beforeRect = tester.getRect(skeleton);
    final beforeOpacity = tester.widget<FadeTransition>(pulse).opacity.value;
    await tester.pump(const Duration(seconds: 2));

    expect(tester.getRect(skeleton), beforeRect);
    expect(tester.widget<FadeTransition>(pulse).opacity.value, beforeOpacity);
  });

  testWidgets('state view fits a 320px screen at text scale 2', (tester) async {
    await pumpEdmmTestHost(
      tester,
      viewport: EdmmTestViewports.compactPhone,
      textScale: 2,
      child: Scaffold(
        body: EdmmStateView(
          kind: EdmmStateKind.error,
          title: 'The music catalog could not be loaded',
          message: 'Please check the connection and try once more.',
          actionLabel: 'Try again',
          onAction: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(FittedBox), findsNothing);
  });

  test('action label and callback are an atomic pair', () {
    expect(
      () => EdmmStateView(
        kind: EdmmStateKind.error,
        title: 'Error',
        actionLabel: 'Retry',
      ),
      throwsAssertionError,
    );
  });
}
