import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../domain/audio/audio_controller.dart';
import '../domain/logic/playback_persistence.dart';
import '../domain/repositories/local_library_repository.dart';
import '../domain/repositories/track_repository.dart';
import '../domain/telemetry/catalog_search_telemetry.dart';
import '../domain/telemetry/playback_telemetry.dart';
import '../ui/catalog_search/view_model/catalog_search_view_model.dart';
import '../ui/catalog_search/widgets/catalog_search_screen.dart';
import '../ui/player/view_model/player_view_model.dart';
import '../ui/player/widgets/player_screen.dart';
import '../ui/player/widgets/track_deep_link_screen.dart';
import 'routes.dart';

final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(
      path: Routes.trackDetail,
      redirect: (_, state) {
        final id = state.pathParameters['id'];
        if (id == null || id.isEmpty) {
          return Routes.trackList;
        }
        return null;
      },
      builder: (context, state) {
        final trackId = state.pathParameters['id'] ?? '';
        return TrackDeepLinkScreen(
          trackId: trackId,
          trackRepository: context.read<TrackRepository>(),
          localLibrary: context.read<LocalLibraryRepository>(),
          audio: context.read<AudioController>(),
          telemetry: context.read<PlaybackTelemetrySink>(),
        );
      },
    ),
    GoRoute(
      path: Routes.trackList,
      builder: (context, state) {
        final repo = context.read<TrackRepository>();
        final audio = context.read<AudioController>();
        final localLibrary = context.read<LocalLibraryRepository>();
        final telemetry = context.read<CatalogSearchTelemetrySink>();
        final view = switch (state.uri.queryParameters['view']) {
          'recent' => CatalogView.recent,
          'edm' => CatalogView.edm,
          'pop' => CatalogView.pop,
          _ => null,
        };
        return CatalogSearchScreen(
          viewModel: CatalogSearchViewModel(
            repo,
            audio,
            localLibrary,
            initialView: view,
            initialTrackId: state.uri.queryParameters['track'],
            telemetry: telemetry,
          ),
          playerViewModel: PlayerViewModel(
            audio,
            localLibrary: localLibrary,
            telemetry: context.read<PlaybackTelemetrySink>(),
          ),
          onOpenPlayer: () => context.go(Routes.player),
          onPlay: (queue, index) async {
            unawaited(persistPlaybackSelection(localLibrary, queue, index));
            await audio.loadQueue(queue, initialIndex: index);
            await audio.play();
          },
        );
      },
    ),
    GoRoute(
      path: Routes.player,
      builder: (context, state) => PlayerScreen(
        viewModel: PlayerViewModel(
          context.read<AudioController>(),
          localLibrary: context.read<LocalLibraryRepository>(),
          telemetry: context.read<PlaybackTelemetrySink>(),
        ),
      ),
    ),
  ],
);
