import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'data/audio/just_audio_controller.dart';
import 'data/repositories/remote_track_repository.dart';
import 'data/services/track_api_service.dart';
import 'domain/audio/audio_controller.dart';
import 'domain/repositories/track_repository.dart';
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

  runApp(MultiProvider(
    providers: [
      Provider<AppConfig>.value(value: config),
      Provider<TrackApiService>.value(value: api),
      Provider<TrackRepository>.value(value: repo),
      Provider<AudioController>.value(value: audio),
    ],
    child: const EdmmApp(),
  ));
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
