import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'config/sentry_config.dart';
import 'data/audio/just_audio_controller.dart';
import 'data/repositories/file_local_library_repository.dart';
import 'data/repositories/in_memory_local_library_repository.dart';
import 'data/repositories/remote_track_repository.dart';
import 'data/repositories/noop_local_library_repository.dart';
import 'data/services/track_api_service.dart';
import 'data/telemetry/sentry_telemetry.dart';
import 'domain/audio/audio_controller.dart';
import 'domain/repositories/local_library_repository.dart';
import 'domain/repositories/track_repository.dart';
import 'domain/telemetry/catalog_search_telemetry.dart';
import 'domain/telemetry/local_library_telemetry.dart';
import 'domain/telemetry/playback_telemetry.dart';
import 'l10n/app_localizations.dart';
import 'routing/router.dart';
import 'ui/core/themes/theme.dart';

typedef SharedPreferencesFactory = Future<SharedPreferences> Function();
typedef FileLocalLibraryRepositoryFactory =
    Future<LocalLibraryRepository> Function(SharedPreferences prefs);
typedef LocalLibraryRepositoryFactory = LocalLibraryRepository Function();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sentryConfig = SentryConfig.fromEnvironment();

  if (sentryConfig.isEnabled) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryConfig.normalizedDsn;
        options.environment = sentryConfig.environment;
        options.release = sentryConfig.normalizedRelease;
        options.dist = sentryConfig.normalizedDist;
        options.tracesSampleRate = sentryConfig.tracesSampleRate;
        options.sendDefaultPii = false;
      },
      appRunner: () => _bootstrapAndRunApp(
        sentryConfig: sentryConfig,
        sentryReporter: SentryTelemetryReporter(),
      ),
    );
    return;
  }

  await _bootstrapAndRunApp(sentryConfig: sentryConfig);
}

Future<void> _bootstrapAndRunApp({
  required SentryConfig sentryConfig,
  SentryTelemetryReporter? sentryReporter,
}) async {
  const config = AppConfig.fromEnvironment();
  final AudioController audio = await AudioService.init<JustAudioController>(
    builder: JustAudioController.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.edmm.edmm.audio',
      androidNotificationChannelName: 'EDMM playback',
      androidNotificationOngoing: true,
    ),
  );
  final api = TrackApiService(http.Client(), config);
  final TrackRepository repo = RemoteTrackRepository(api);
  final catalogSearchTelemetry = sentryReporter == null
      ? const NoopCatalogSearchTelemetrySink()
      : SentryCatalogSearchTelemetrySink(sentryReporter);
  final localLibraryTelemetry = sentryReporter == null
      ? const NoopLocalLibraryTelemetrySink()
      : SentryLocalLibraryTelemetrySink(sentryReporter);
  final playbackTelemetry = sentryReporter == null
      ? const NoopPlaybackTelemetrySink()
      : SentryPlaybackTelemetrySink(sentryReporter);
  final LocalLibraryRepository localLibrary =
      await createLocalLibraryRepository(telemetry: localLibraryTelemetry);

  final app = MultiProvider(
    providers: [
      Provider<AppConfig>.value(value: config),
      Provider<TrackApiService>.value(value: api),
      Provider<TrackRepository>.value(value: repo),
      Provider<LocalLibraryRepository>.value(value: localLibrary),
      Provider<AudioController>.value(value: audio),
      Provider<LocalLibraryTelemetrySink>.value(value: localLibraryTelemetry),
      Provider<CatalogSearchTelemetrySink>.value(value: catalogSearchTelemetry),
      Provider<PlaybackTelemetrySink>.value(value: playbackTelemetry),
      Provider<SentryConfig>.value(value: sentryConfig),
    ],
    child: const EdmmApp(),
  );

  runApp(sentryConfig.isEnabled ? SentryWidget(child: app) : app);
}

Future<LocalLibraryRepository> createLocalLibraryRepository({
  LocalLibraryTelemetrySink telemetry = const NoopLocalLibraryTelemetrySink(),
  SharedPreferencesFactory? prefsFactory,
  FileLocalLibraryRepositoryFactory? fileRepositoryFactory,
  LocalLibraryRepositoryFactory? inMemoryRepositoryFactory,
  LocalLibraryRepository? noopRepository,
  bool debugLogging = kDebugMode,
}) async {
  final resolvePrefs = prefsFactory ?? SharedPreferences.getInstance;
  final createFileRepository =
      fileRepositoryFactory ??
      ((prefs) => FileLocalLibraryRepository.open(prefs: prefs));
  final createInMemoryRepository =
      inMemoryRepositoryFactory ?? InMemoryLocalLibraryRepository.new;
  final resolvedNoopRepository =
      noopRepository ?? const NoopLocalLibraryRepository();

  try {
    final prefs = await resolvePrefs();
    return await createFileRepository(prefs);
  } catch (error, stackTrace) {
    telemetry.emit(
      LocalLibraryTelemetryEvent.fallbackUsed(
        attemptedRepository: 'file',
        fallbackRepository: 'in_memory',
        error: error,
      ),
    );
    if (debugLogging) {
      debugPrint(
        'File local library repository init failed, using in-memory repository: $error\n$stackTrace',
      );
    }
  }

  try {
    return createInMemoryRepository();
  } catch (error, stackTrace) {
    telemetry.emit(
      LocalLibraryTelemetryEvent.fallbackUsed(
        attemptedRepository: 'in_memory',
        fallbackRepository: 'noop',
        error: error,
      ),
    );
    if (debugLogging) {
      debugPrint(
        'In-memory local library repository init failed, using noop repository: $error\n$stackTrace',
      );
    }
    return resolvedNoopRepository;
  }
}

class EdmmApp extends StatelessWidget {
  const EdmmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: appRouter,
    );
  }
}
