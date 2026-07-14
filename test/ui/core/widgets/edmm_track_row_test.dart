import 'dart:ui' show Tristate;

import 'package:edmm/ui/core/themes/theme.dart';
import 'package:edmm/ui/core/widgets/edmm_track_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../design_system/edmm_test_host.dart';

void main() {
  testWidgets('base states expose icons and injected semantic labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpEdmmTestHost(
      tester,
      viewport: const Size(390, 844),
      child: Scaffold(
        body: Column(
          children: <Widget>[
            for (final state in EdmmTrackRowState.values)
              EdmmTrackRow(
                title: 'Track ${state.name}',
                artist: 'EDMM',
                state: state,
                stateSemanticLabel: 'State ${state.name}',
                primaryActionKey: Key('primary-${state.name}'),
                onTap: () {},
              ),
          ],
        ),
      ),
    );

    expect(
      find.byKey(const Key('edmm-track-state-defaultState')),
      findsNothing,
    );
    for (final state in EdmmTrackRowState.values.skip(1)) {
      expect(find.byKey(Key('edmm-track-state-${state.name}')), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(Key('primary-${state.name}'))).label,
        contains('State ${state.name}'),
      );
    }

    for (final state in <EdmmTrackRowState>[
      EdmmTrackRowState.selected,
      EdmmTrackRowState.current,
      EdmmTrackRowState.playingCurrent,
    ]) {
      expect(
        tester
            .getSemantics(find.byKey(Key('primary-${state.name}')))
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
    }
    for (final state in <EdmmTrackRowState>[
      EdmmTrackRowState.unplayable,
      EdmmTrackRowState.error,
    ]) {
      expect(
        tester
            .getSemantics(find.byKey(Key('primary-${state.name}')))
            .flagsCollection
            .isEnabled,
        Tristate.isFalse,
      );
    }
    semantics.dispose();
  });

  testWidgets('primary and detail callbacks stay independent', (tester) async {
    var primaryTaps = 0;
    var detailTaps = 0;
    await pumpEdmmTestHost(
      tester,
      child: Scaffold(
        body: EdmmTrackRow(
          title: 'Midnight Signal',
          artist: 'Rose Circuit',
          duration: const Duration(minutes: 4, seconds: 12),
          primaryActionKey: const Key('primary-action'),
          onTap: () => primaryTaps++,
          detailsLabel: 'Track details',
          detailsActionKey: const Key('details-action'),
          onDetails: () => detailTaps++,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('primary-action')));
    await tester.pump();
    expect(primaryTaps, 1);
    expect(detailTaps, 0);

    await tester.tap(find.byKey(const Key('details-action')));
    await tester.pump();
    expect(primaryTaps, 1);
    expect(detailTaps, 1);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('details-action')))
          .tooltip,
      'Track details',
    );
  });

  testWidgets('blocked primary state preserves the detail action', (
    tester,
  ) async {
    var primaryTaps = 0;
    var detailTaps = 0;
    await pumpEdmmTestHost(
      tester,
      child: Scaffold(
        body: EdmmTrackRow(
          title: 'Unavailable Track',
          artist: 'EDMM',
          state: EdmmTrackRowState.unplayable,
          stateSemanticLabel: 'Unavailable',
          primaryActionKey: const Key('blocked-primary'),
          onTap: () => primaryTaps++,
          detailsLabel: 'Why unavailable',
          detailsActionKey: const Key('blocked-details'),
          onDetails: () => detailTaps++,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('blocked-primary')));
    await tester.tap(find.byKey(const Key('blocked-details')));
    await tester.pump();
    expect(primaryTaps, 0);
    expect(detailTaps, 1);
  });

  testWidgets('row fits 320px at text scale 2 with 48dp actions', (
    tester,
  ) async {
    await pumpEdmmTestHost(
      tester,
      viewport: EdmmTestViewports.compactPhone,
      textScale: 2,
      child: Scaffold(
        body: EdmmTrackRow(
          key: const Key('scaled-row'),
          title: 'A very long electronic dance track title for compact screens',
          artist: 'An equally descriptive artist and collaboration name',
          duration: const Duration(hours: 1, minutes: 2, seconds: 3),
          state: EdmmTrackRowState.playingCurrent,
          stateSemanticLabel: 'Playing now',
          onTap: () {},
          detailsLabel: 'Open track details',
          detailsActionKey: const Key('scaled-details'),
          onDetails: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(FittedBox), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('scaled-details'))),
      const Size.square(EdmmSizes.minTouchTarget),
    );
    expect(
      tester.getSize(find.byKey(const Key('scaled-row'))).width,
      EdmmTestViewports.compactPhone.width,
    );
  });

  testWidgets('artwork stays decorative when row text already identifies it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpEdmmTestHost(
      tester,
      child: Scaffold(
        body: EdmmTrackRow(
          title: 'One Announcement',
          artist: 'EDMM',
          stateSemanticLabel: 'Available',
          primaryActionKey: const Key('one-announcement'),
          onTap: () {},
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byKey(const Key('one-announcement'))).label,
      'One Announcement, EDMM, Available',
    );
    expect(find.bySemanticsLabel(RegExp('artwork|cover')), findsNothing);
    semantics.dispose();
  });

  test('detail label and callback are an atomic pair', () {
    expect(
      () => EdmmTrackRow(
        title: 'Track',
        artist: 'Artist',
        detailsLabel: 'Details',
      ),
      throwsAssertionError,
    );
  });
}
