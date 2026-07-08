class AppConfig {
  const AppConfig({
    this.environment = productionEnvironment,
    this.bffBaseUrl = productionBffBaseUrl,
    this.timeout = const Duration(seconds: 15),
  });

  const AppConfig.fromEnvironment()
    : environment = const String.fromEnvironment(
        'APP_ENV',
        defaultValue: productionEnvironment,
      ),
      bffBaseUrl = const String.fromEnvironment(
        'BFF_BASE_URL',
        defaultValue: productionBffBaseUrl,
      ),
      timeout = const Duration(
        seconds: int.fromEnvironment('BFF_TIMEOUT_SECONDS', defaultValue: 15),
      );

  static const String productionEnvironment = 'production';
  static const String productionBffBaseUrl = 'https://edmm.vercel.app';

  final String environment;
  final String bffBaseUrl;
  final Duration timeout;

  String get normalizedEnvironment {
    final trimmed = environment.trim();
    return trimmed.isEmpty ? productionEnvironment : trimmed;
  }

  String get normalizedBffBaseUrl {
    final trimmed = bffBaseUrl.trim();
    return trimmed.isEmpty ? productionBffBaseUrl : trimmed;
  }
}
