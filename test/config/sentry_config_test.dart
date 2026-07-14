import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/config/sentry_config.dart';

void main() {
  test('disabled when DSN is empty', () {
    const config = SentryConfig(dsn: '');
    expect(config.isEnabled, isFalse);
  });

  test('enabled when DSN is configured and trims whitespace', () {
    const config = SentryConfig(dsn: ' https://public@example.sentry.io/1 ');
    expect(config.isEnabled, isTrue);
    expect(config.normalizedDsn, 'https://public@example.sentry.io/1');
  });

  test('uses production as default environment', () {
    const config = SentryConfig(dsn: 'x');
    expect(config.environment, 'production');
  });
}
