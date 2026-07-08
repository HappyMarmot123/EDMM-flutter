import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/l10n/app_localizations.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/models/cloudinary_category.dart';
import 'package:edmm/domain/repositories/track_repository.dart';
import 'package:edmm/domain/result.dart';
import 'package:edmm/domain/audio/audio_controller.dart';
import 'package:edmm/domain/playback/playback_snapshot.dart';
import 'package:edmm/ui/catalog_search/view_model/catalog_search_view_model.dart';
import 'package:edmm/ui/catalog_search/widgets/catalog_search_screen.dart';

class _Repo implements TrackRepository {
  @override
  Future<Result<List<Track>>> getCatalog({
    required CloudinaryCategory category,
    String query = '',
    bool forceRefresh = false,
  }) async =>
      const Ok<List<Track>>([]);
}

class _Audio implements AudioController {
  @override
  Stream<Duration> get position => Stream<Duration>.empty();
  @override
  Stream<PlaybackSnapshot> get snapshot => Stream<PlaybackSnapshot>.empty();
  @override
  bool get isShuffleEnabled => false;
  @override
  double get volume => 1.0;
  @override
  Future<void> loadQueue(List<Track> tracks, {int initialIndex = 0}) async {}
  @override
  Future<void> setShuffleEnabled(bool enabled) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setMute(bool muted) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> next() async {}
  @override
  Future<void> previous() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('home shell renders the empty catalog state via a real load', (tester) async {
    final vm = CatalogSearchViewModel(_Repo(), _Audio(), searchDebounce: Duration.zero);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CatalogSearchScreen(viewModel: vm, onPlay: (_, _) {}),
    ));
    await tester.pumpAndSettle();
    expect(find.text('No tracks'), findsOneWidget);
  });
}
