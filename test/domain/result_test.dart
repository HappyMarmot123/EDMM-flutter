import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/domain/result.dart';

void main() {
  test('Ok holds value, Err holds failure, switch discriminates', () {
    Result<int> ok = const Ok(42);
    Result<int> err = Err(ServerFailure(502));

    String describe(Result<int> r) => switch (r) {
      Ok(:final value) => 'ok:$value',
      Err(:final error) => switch (error) {
        ServerFailure(:final statusCode) => 'server:$statusCode',
        NetworkFailure() => 'network',
        ParseFailure() => 'parse',
      },
    };

    expect(describe(ok), 'ok:42');
    expect(describe(err), 'server:502');
  });
}
