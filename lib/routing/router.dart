import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../domain/audio/audio_controller.dart';
import '../domain/repositories/track_repository.dart';
import '../ui/player/view_model/player_view_model.dart';
import '../ui/player/widgets/player_screen.dart';
import '../ui/track_list/view_model/track_list_view_model.dart';
import '../ui/track_list/widgets/track_list_screen.dart';
import 'routes.dart';

final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(
      path: Routes.trackList,
      builder: (context, state) {
        final repo = context.read<TrackRepository>();
        final audio = context.read<AudioController>();
        return TrackListScreen(
          viewModel: TrackListViewModel(repo)..load(),
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
