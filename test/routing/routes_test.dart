import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/routing/routes.dart';

void main() {
  test('trackDetailLocation encodes the id into the player deep link', () {
    expect(trackDetailLocation('abc'), '/track/abc');
    expect(trackDetailLocation('a b/c'), '/track/a%20b%2Fc');
  });

  test('search route keeps the list visible after starting playback', () {
    final routerSource = File('lib/routing/router.dart').readAsStringSync();

    expect(
      routerSource,
      isNot(contains('if (context.mounted) context.go(Routes.player);')),
    );
    expect(routerSource, contains('playerViewModel: PlayerViewModel('));
    expect(
      routerSource,
      contains('onOpenPlayer: () => context.go(Routes.player)'),
    );
  });
}
