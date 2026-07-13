import 'dart:async';

import 'package:edmm/config/app_config.dart';
import 'package:edmm/config/sentry_config.dart';
import 'package:edmm/data/repositories/in_memory_local_library_repository.dart';
import 'package:edmm/data/services/track_api_service.dart';
import 'package:edmm/domain/audio/audio_controller.dart';
import 'package:edmm/domain/models/cloudinary_category.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/playback/playback_snapshot.dart';
import 'package:edmm/domain/repositories/local_library_repository.dart';
import 'package:edmm/domain/repositories/track_repository.dart';
import 'package:edmm/domain/result.dart';
import 'package:edmm/domain/telemetry/catalog_search_telemetry.dart';
import 'package:edmm/domain/telemetry/local_library_telemetry.dart';
import 'package:edmm/domain/telemetry/playback_telemetry.dart';
import 'package:edmm/main.dart';
import 'package:edmm/routing/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

const _track = Track(
  id: 'integration-track',
  source: 'cloudinary',
  title: 'Integration Track',
  artistId: 'integration-artist',
  artistName: 'Integration Artist',
  durationMs: 90000,
  streamUrl: 'https://example.com/integration.mp3',
  metadata: {'category': 'pop'},
);

class _TrackRepository implements TrackRepository {
  @override
  Future<Result<List<Track>>> getCatalog({
    required CloudinaryCategory category,
    String query = '',
    bool forceRefresh = false,
  }) async => const Ok([_track]);
}

class _Audio implements AudioController {
  final _snapshots = StreamController<PlaybackSnapshot>.broadcast();
  PlaybackSnapshot _latest = const PlaybackSnapshot();
  double _volume = 1;
  bool _shuffle = false;
  int loadCalls = 0;
  int playCalls = 0;

  @override
  Stream<Duration> get position => const Stream<Duration>.empty();

  @override
  Stream<PlaybackSnapshot> get snapshot async* {
    yield _latest;
    yield* _snapshots.stream;
  }

  @override
  bool get isShuffleEnabled => _shuffle;

  @override
  double get volume => _volume;

  @override
  Future<bool> loadQueue(List<Track> tracks, {int initialIndex = 0}) async {
    loadCalls += 1;
    _emit(
      PlaybackSnapshot(
        currentTrack: tracks[initialIndex],
        status: PlaybackStatus.paused,
        duration: tracks[initialIndex].duration,
        queueIndex: initialIndex,
      ),
    );
    return true;
  }

  @override
  Future<void> play() async {
    playCalls += 1;
    _emit(
      PlaybackSnapshot(
        currentTrack: _latest.currentTrack,
        status: PlaybackStatus.playing,
        duration: _latest.duration,
        queueIndex: _latest.queueIndex,
      ),
    );
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> next() async {}

  @override
  Future<void> previous() async {}

  @override
  Future<void> setShuffleEnabled(bool enabled) async => _shuffle = enabled;

  @override
  Future<void> setVolume(double volume) async => _volume = volume;

  @override
  Future<void> setMute(bool muted) async => _volume = muted ? 0 : 1;

  @override
  Future<void> dispose() async => _snapshots.close();

  void _emit(PlaybackSnapshot snapshot) {
    _latest = snapshot;
    _snapshots.add(snapshot);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'catalog track can be played, favorited, and added to a playlist',
    (tester) async {
      final audio = _Audio();
      final localLibrary = InMemoryLocalLibraryRepository();
      final client = http.Client();
      final api = TrackApiService(client, const AppConfig());
      addTearDown(audio.dispose);
      addTearDown(client.close);
      appRouter.go('/');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppConfig>.value(value: const AppConfig()),
            Provider<TrackApiService>.value(value: api),
            Provider<TrackRepository>.value(value: _TrackRepository()),
            Provider<LocalLibraryRepository>.value(value: localLibrary),
            Provider<AudioController>.value(value: audio),
            Provider<LocalLibraryTelemetrySink>.value(
              value: const NoopLocalLibraryTelemetrySink(),
            ),
            Provider<CatalogSearchTelemetrySink>.value(
              value: const NoopCatalogSearchTelemetrySink(),
            ),
            Provider<PlaybackTelemetrySink>.value(
              value: const NoopPlaybackTelemetrySink(),
            ),
            Provider<SentryConfig>.value(value: const SentryConfig(dsn: '')),
          ],
          child: const EdmmApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Integration Track'), findsOneWidget);
      await tester.tap(find.text('Integration Track'));
      await tester.pumpAndSettle();
      expect(audio.loadCalls, 1);
      expect(audio.playCalls, 1);

      await tester.tap(
        find.byKey(const Key('catalog-track-detail-integration-track')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Track details'), findsOneWidget);

      await tester.tap(find.byKey(const Key('track-detail-favorite')));
      await tester.pumpAndSettle();
      expect(await localLibrary.isFavorite(_track.id), isTrue);

      await tester.tap(find.byKey(const Key('track-detail-add-playlist')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('track-detail-create-playlist')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('track-detail-playlist-name')),
        'Integration playlist',
      );
      await tester.tap(
        find.byKey(const Key('track-detail-create-playlist-confirm')),
      );
      await tester.pumpAndSettle();

      final playlists = await localLibrary.getPlaylists();
      expect(playlists.single.name, 'Integration playlist');
      expect(await localLibrary.getPlaylistTrackIds(playlists.single.id!), [
        _track.id,
      ]);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('catalog-open-library')));
      await tester.pumpAndSettle();

      expect(find.text('Favorites'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('library-favorites-list')),
          matching: find.text('Integration Track'),
        ),
        findsOneWidget,
      );
      expect(find.text('Integration playlist'), findsOneWidget);
      await tester.tap(find.text('Integration playlist'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('playlist-detail-list')),
          matching: find.text('Integration Track'),
        ),
        findsOneWidget,
      );
    },
  );
}
