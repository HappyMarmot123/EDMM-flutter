class SentryConfig {
  const SentryConfig({
    required this.dsn,
    this.environment = 'production',
    this.release = '',
    this.dist = '',
    this.tracesSampleRate = 0.0,
  });

  factory SentryConfig.fromEnvironment() {
    const dsn = String.fromEnvironment('SENTRY_DSN');
    const environment = String.fromEnvironment(
      'SENTRY_ENVIRONMENT',
      defaultValue: 'production',
    );
    const release = String.fromEnvironment('SENTRY_RELEASE');
    const dist = String.fromEnvironment('SENTRY_DIST');
    const tracesSampleRate = String.fromEnvironment(
      'SENTRY_TRACES_SAMPLE_RATE',
    );
    return SentryConfig(
      dsn: dsn,
      environment: environment,
      release: release,
      dist: dist,
      tracesSampleRate: double.tryParse(tracesSampleRate) ?? 0.0,
    );
  }

  final String dsn;
  final String environment;
  final String release;
  final String dist;
  final double tracesSampleRate;

  bool get isEnabled => normalizedDsn.isNotEmpty;

  String get normalizedDsn => dsn.trim();
  String? get normalizedRelease =>
      release.trim().isEmpty ? null : release.trim();
  String? get normalizedDist => dist.trim().isEmpty ? null : dist.trim();
}
