import 'package:edmm/ui/core/layout/edmm_breakpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('width class and gutter boundaries are stable', () {
    expect(EdmmBreakpoints.widthClassFor(599), EdmmWidthClass.compact);
    expect(EdmmBreakpoints.widthClassFor(600), EdmmWidthClass.medium);
    expect(EdmmBreakpoints.widthClassFor(839), EdmmWidthClass.medium);
    expect(EdmmBreakpoints.widthClassFor(840), EdmmWidthClass.expanded);

    expect(EdmmBreakpoints.gutterFor(320), 16);
    expect(EdmmBreakpoints.gutterFor(600), 24);
    expect(EdmmBreakpoints.gutterFor(840), 32);
  });

  test('height class boundaries are stable', () {
    expect(EdmmBreakpoints.heightClassFor(499), EdmmHeightClass.tight);
    expect(EdmmBreakpoints.heightClassFor(500), EdmmHeightClass.compact);
    expect(EdmmBreakpoints.heightClassFor(719), EdmmHeightClass.compact);
    expect(EdmmBreakpoints.heightClassFor(720), EdmmHeightClass.regular);
  });

  test('content width contracts remain semantic and finite', () {
    expect(EdmmBreakpoints.readableContentMaxWidth, 720);
    expect(EdmmBreakpoints.standardContentMaxWidth, 720);
    expect(EdmmBreakpoints.wideContentMaxWidth, 1120);
    expect(EdmmBreakpoints.playerOnePaneMaxWidth, 560);
  });

  test('player two-pane predicate matches the canonical contract', () {
    expect(
      EdmmBreakpoints.usePlayerTwoPane(maxWidth: 599, maxHeight: 599),
      isFalse,
    );
    expect(
      EdmmBreakpoints.usePlayerTwoPane(maxWidth: 600, maxHeight: 500),
      isTrue,
    );
    expect(
      EdmmBreakpoints.usePlayerTwoPane(maxWidth: 600, maxHeight: 501),
      isFalse,
    );
    expect(
      EdmmBreakpoints.usePlayerTwoPane(maxWidth: 600, maxHeight: 600),
      isFalse,
    );
    expect(
      EdmmBreakpoints.usePlayerTwoPane(maxWidth: 839, maxHeight: 700),
      isFalse,
    );
    expect(
      EdmmBreakpoints.usePlayerTwoPane(maxWidth: 840, maxHeight: 900),
      isTrue,
    );
  });
}
