import 'package:edmm/ui/core/themes/edmm_theme_tokens.dart';
import 'package:edmm/ui/player/widgets/player_transport_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../design_system/edmm_test_host.dart';

void main() {
  testWidgets(
    'fullscreen transport controls keep a balanced responsive geometry',
    (tester) async {
      const buttonKeys = <Key>[
        Key('player-shuffle-button'),
        Key('player-previous-button'),
        Key('player-play-pause-button'),
        Key('player-next-button'),
        Key('player-visualizer-toggle'),
      ];

      for (final testCase in const <({double width, double gap})>[
        (width: 288, gap: EdmmSpacing.xs),
        (width: 268, gap: 3),
      ]) {
        await pumpEdmmTestHost(
          tester,
          viewport: Size(testCase.width, 120),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: testCase.width,
                child: PlayerTransportControls(
                  shuffleEnabled: false,
                  isPlaying: false,
                  visualizerEnabled: true,
                  visualizerAvailable: true,
                  shuffleLabel: 'Shuffle',
                  previousLabel: 'Previous',
                  playLabel: 'Play',
                  pauseLabel: 'Pause',
                  nextLabel: 'Next',
                  visualizerEnableLabel: 'Show spectrum',
                  visualizerDisableLabel: 'Hide spectrum',
                  visualizerUnavailableLabel: 'Spectrum unavailable',
                  onToggleShuffle: _noop,
                  onPrevious: _noop,
                  onPlayPause: _noop,
                  onNext: _noop,
                  onToggleVisualizer: _noop,
                ),
              ),
            ),
          ),
        );

        final rects = buttonKeys
            .map((key) => tester.getRect(find.byKey(key)))
            .toList(growable: false);
        expect(rects.map((rect) => rect.size), const <Size>[
          Size.square(EdmmSizes.minTouchTarget),
          Size.square(EdmmSizes.minTouchTarget),
          Size.square(EdmmSizes.prominentAction),
          Size.square(EdmmSizes.minTouchTarget),
          Size.square(EdmmSizes.minTouchTarget),
        ]);

        for (final rect in rects.skip(1)) {
          expect(rect.center.dy, closeTo(rects.first.center.dy, 0.01));
        }
        for (var index = 1; index < rects.length; index++) {
          expect(
            rects[index].left - rects[index - 1].right,
            closeTo(testCase.gap, 0.01),
          );
        }
        expect(
          tester.getSize(find.byKey(const Key('player-transport-controls'))),
          Size(testCase.width, EdmmSizes.prominentAction),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('fullscreen transport icon sizes preserve action hierarchy', (
    tester,
  ) async {
    await pumpEdmmTestHost(
      tester,
      viewport: const Size(320, 120),
      child: const Scaffold(body: _TransportFixture()),
    );

    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('player-shuffle-button')))
          .iconSize,
      24,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('player-previous-button')))
          .iconSize,
      24,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('player-play-pause-button')))
          .iconSize,
      32,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('player-next-button')))
          .iconSize,
      24,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('player-visualizer-toggle')))
          .iconSize,
      24,
    );
  });
}

class _TransportFixture extends StatelessWidget {
  const _TransportFixture();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: PlayerTransportControls(
        shuffleEnabled: false,
        isPlaying: false,
        visualizerEnabled: true,
        visualizerAvailable: true,
        shuffleLabel: 'Shuffle',
        previousLabel: 'Previous',
        playLabel: 'Play',
        pauseLabel: 'Pause',
        nextLabel: 'Next',
        visualizerEnableLabel: 'Show spectrum',
        visualizerDisableLabel: 'Hide spectrum',
        visualizerUnavailableLabel: 'Spectrum unavailable',
        onToggleShuffle: _noop,
        onPrevious: _noop,
        onPlayPause: _noop,
        onNext: _noop,
        onToggleVisualizer: _noop,
      ),
    );
  }
}

void _noop() {}
