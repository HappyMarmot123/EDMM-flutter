import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'data/audio/just_audio_controller.dart';
import 'data/repositories/file_local_library_repository.dart';
import 'data/repositories/in_memory_local_library_repository.dart';
import 'data/repositories/remote_track_repository.dart';
import 'data/repositories/noop_local_library_repository.dart';
import 'data/services/track_api_service.dart';
import 'domain/audio/audio_controller.dart';
import 'domain/repositories/local_library_repository.dart';
import 'domain/repositories/track_repository.dart';
import 'domain/telemetry/catalog_search_telemetry.dart';
import 'l10n/app_localizations.dart';
import 'routing/router.dart';
import 'ui/core/themes/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const config = AppConfig();
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
  final LocalLibraryRepository localLibrary =
      await _createLocalLibraryRepository();

  runApp(
    MultiProvider(
      providers: [
        Provider<AppConfig>.value(value: config),
        Provider<TrackApiService>.value(value: api),
        Provider<TrackRepository>.value(value: repo),
        Provider<LocalLibraryRepository>.value(value: localLibrary),
        Provider<AudioController>.value(value: audio),
        Provider<CatalogSearchTelemetrySink>.value(
          value: const NoopCatalogSearchTelemetrySink(),
        ),
      ],
      child: const EdmmApp(),
    ),
  );
}

Future<LocalLibraryRepository> _createLocalLibraryRepository() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return await FileLocalLibraryRepository.open(prefs: prefs);
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint(
        'File local library repository init failed, using in-memory repository: $error\n$stackTrace',
      );
    }
  }

  try {
    return InMemoryLocalLibraryRepository();
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint(
        'In-memory local library repository init failed, using noop repository: $error\n$stackTrace',
      );
    }
    return const NoopLocalLibraryRepository();
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
