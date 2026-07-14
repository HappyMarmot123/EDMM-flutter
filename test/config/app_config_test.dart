import 'package:edmm/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults to production config', () {
    const config = AppConfig.fromEnvironment();

    expect(config.environment, 'production');
    expect(config.bffBaseUrl, 'https://edmm.vercel.app');
    expect(config.timeout, const Duration(seconds: 15));
  });

  test('trims explicit BFF URL and environment values', () {
    const config = AppConfig(
      environment: ' staging ',
      bffBaseUrl: ' https://staging.example.com ',
    );

    expect(config.normalizedEnvironment, 'staging');
    expect(config.normalizedBffBaseUrl, 'https://staging.example.com');
  });

  test('falls back to production URL when explicit URL is blank', () {
    const config = AppConfig(bffBaseUrl: '  ');

    expect(config.normalizedBffBaseUrl, 'https://edmm.vercel.app');
  });
}
