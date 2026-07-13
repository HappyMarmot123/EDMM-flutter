import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/routing/routes.dart';

void main() {
  test('trackDetailLocation encodes the id into the player deep link', () {
    expect(trackDetailLocation('abc'), '/track/abc');
    expect(trackDetailLocation('a b/c'), '/track/a%20b%2Fc');
  });
}
