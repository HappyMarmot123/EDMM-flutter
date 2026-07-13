import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../domain/audio/audio_controller.dart';
import '../domain/logic/playback_persistence.dart';
import '../domain/logic/track_resolver.dart';
import '../domain/models/track.dart';
import '../domain/repositories/local_library_repository.dart';
import '../domain/repositories/track_repository.dart';
import '../domain/telemetry/catalog_search_telemetry.dart';
import '../domain/telemetry/playback_telemetry.dart';
import '../ui/catalog_search/view_model/catalog_search_view_model.dart';
import '../ui/catalog_search/widgets/catalog_search_screen.dart';
import '../ui/core/widgets/playback_shell.dart';
import '../ui/library/view_model/library_view_model.dart';
import '../ui/library/view_model/playlist_detail_view_model.dart';
import '../ui/library/widgets/library_screen.dart';
import '../ui/library/widgets/playlist_detail_screen.dart';
import '../ui/track_detail/view_model/track_detail_view_model.dart';
import '../ui/track_detail/widgets/track_detail_screen.dart';
import 'routes.dart';

final GoRouter appRouter = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) => PlaybackShell(
        key: const ValueKey('playback-shell'),
        audio: context.read<AudioController>(),
        localLibrary: context.read<LocalLibraryRepository>(),
        telemetry: context.read<PlaybackTelemetrySink>(),
        child: child,
      ),
      routes: [
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
              onOpenLibrary: () => context.push(libraryLocation()),
              onOpenTrack: (track) =>
                  context.push(trackDetailLocation(track.id), extra: track),
              onPlay: (queue, index) => unawaited(
                _startPlayback(
                  audio: audio,
                  localLibrary: localLibrary,
                  queue: queue,
                  index: index,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: Routes.library,
          builder: (context, state) {
            final localLibrary = context.read<LocalLibraryRepository>();
            final audio = context.read<AudioController>();
            return LibraryScreen(
              viewModel: LibraryViewModel(localLibrary),
              onOpenTrack: (trackId) =>
                  context.push(trackDetailLocation(trackId)),
              onOpenPlaylist: (playlist) {
                final id = playlist.id;
                if (id != null) context.push(playlistDetailLocation(id));
              },
              onPlay: (queue, index) => unawaited(
                _startPlayback(
                  audio: audio,
                  localLibrary: localLibrary,
                  queue: queue,
                  index: index,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: Routes.playlistDetail,
          redirect: (_, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '');
            return id == null || id < 0 ? Routes.library : null;
          },
          builder: (context, state) {
            final playlistId = int.parse(state.pathParameters['id']!);
            final localLibrary = context.read<LocalLibraryRepository>();
            final audio = context.read<AudioController>();
            return PlaylistDetailScreen(
              viewModel: PlaylistDetailViewModel(
                localLibrary,
                playlistId: playlistId,
              ),
              onOpenTrack: (trackId) =>
                  context.push(trackDetailLocation(trackId)),
              onPlay: (queue, index) => unawaited(
                _startPlayback(
                  audio: audio,
                  localLibrary: localLibrary,
                  queue: queue,
                  index: index,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: Routes.trackDetail,
          redirect: (_, state) {
            final id = state.pathParameters['id'];
            return id == null || id.isEmpty ? Routes.trackList : null;
          },
          builder: (context, state) {
            final trackId = state.pathParameters['id'] ?? '';
            final localLibrary = context.read<LocalLibraryRepository>();
            final audio = context.read<AudioController>();
            final seed = switch (state.extra) {
              Track track when track.id == trackId => track,
              _ => null,
            };
            return TrackDetailScreen(
              viewModel: TrackDetailViewModel(
                trackId: trackId,
                initialTrack: seed,
                resolver: TrackResolver(
                  context.read<TrackRepository>(),
                  localLibrary,
                ),
                localLibrary: localLibrary,
              ),
              onPlay: (track) => unawaited(
                _startPlayback(
                  audio: audio,
                  localLibrary: localLibrary,
                  queue: [track],
                  index: 0,
                ),
              ),
            );
          },
        ),
      ],
    ),
  ],
);

final Expando<_PlaybackRequestState> _playbackRequestStates =
    Expando<_PlaybackRequestState>();

class _PlaybackRequestState {
  int generation = 0;
}

Future<void> _startPlayback({
  required AudioController audio,
  required LocalLibraryRepository localLibrary,
  required List<Track> queue,
  required int index,
}) async {
  final state = _playbackRequestStates[audio] ??= _PlaybackRequestState();
  final generation = ++state.generation;
  final loaded = await audio.loadQueue(queue, initialIndex: index);
  if (!loaded || generation != state.generation) return;
  unawaited(persistPlaybackSelection(localLibrary, queue, index));
  await audio.play();
}
