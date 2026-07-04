class AppConfig {
  const AppConfig({
    this.bffBaseUrl = 'https://edmm.vercel.app',
    this.timeout = const Duration(seconds: 15),
  });
  final String bffBaseUrl;
  final Duration timeout;
}
