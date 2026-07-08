import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../domain/audio/audio_controller.dart';
import '../domain/repositories/track_repository.dart';
import '../ui/catalog_search/view_model/catalog_search_view_model.dart';
import '../ui/catalog_search/widgets/catalog_search_screen.dart';
import '../ui/player/view_model/player_view_model.dart';
import '../ui/player/widgets/player_screen.dart';
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
        return trackDetailLocation(id);
      },
    ),
    GoRoute(
      path: Routes.trackList,
      builder: (context, state) {
        final repo = context.read<TrackRepository>();
        final audio = context.read<AudioController>();
        final view = switch (state.uri.queryParameters['view']) {
          'edm' => CatalogView.edm,
          'pop' => CatalogView.pop,
          _ => null,
        };
        return CatalogSearchScreen(
          viewModel: CatalogSearchViewModel(
            repo,
            audio,
            initialView: view,
            initialTrackId: state.uri.queryParameters['track'],
          ),
          onPlay: (queue, index) async {
            await audio.loadQueue(queue, initialIndex: index);
            await audio.play();
            if (context.mounted) context.go(Routes.player);
          },
        );
      },
    ),
    GoRoute(
      path: Routes.player,
      builder: (context, state) =>
          PlayerScreen(viewModel: PlayerViewModel(context.read<AudioController>())),
    ),
  ],
);
