import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:edmm/main.dart';

void main() {
  testWidgets('home screen shows setup message and counter increments', (
    tester,
  ) async {
    await tester.pumpWidget(const EdmmApp());
    await tester.pumpAndSettle();

    expect(find.text('Flutter project setup complete'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });
}
