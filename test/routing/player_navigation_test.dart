import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:edmm/data/repositories/in_memory_local_library_repository.dart';
import 'package:edmm/domain/audio/audio_controller.dart';
import 'package:edmm/domain/models/cloudinary_category.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/playback/playback_snapshot.dart';
import 'package:edmm/domain/repositories/local_library_repository.dart';
import 'package:edmm/domain/repositories/track_repository.dart';
import 'package:edmm/domain/result.dart';
import 'package:edmm/domain/telemetry/catalog_search_telemetry.dart';
import 'package:edmm/domain/telemetry/playback_telemetry.dart';
import 'package:edmm/l10n/app_localizations.dart';
import 'package:edmm/routing/router.dart';

Track _t(String id) => Track(
  id: id,
  source: 'cloudinary',
  title: 'Song $id',
  artistId: 'a',
  artistName: 'Artist',
  durationMs: 60000,
  streamUrl: 'u',
  metadata: const {'resourceType': 'video'},
);

class _Repo implements TrackRepository {
  @override
  Future<Result<List<Track>>> getCatalog({
    required CloudinaryCategory category,
    String query = '',
    bool forceRefresh = false,
  }) async => Ok([_t('1'), _t('2')]);
}

class _Audio implements AudioController {
  final _snap = StreamController<PlaybackSnapshot>.broadcast();
  final _pos = StreamController<Duration>.broadcast();

  @override
  Stream<PlaybackSnapshot> get snapshot => _snap.stream;
  @override
  Stream<Duration> get position => _pos.stream;
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
  Future<void> dispose() async {
    await _snap.close();
    await _pos.close();
  }

  void emit(PlaybackSnapshot snapshot) => _snap.add(snapshot);
}

void main() {
  testWidgets(
    'returning from the fullscreen player keeps the catalog list visible',
    (tester) async {
      final audio = _Audio();
      addTearDown(audio.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<TrackRepository>.value(value: _Repo()),
            Provider<AudioController>.value(value: audio),
            Provider<LocalLibraryRepository>.value(
              value: InMemoryLocalLibraryRepository(),
            ),
            Provider<CatalogSearchTelemetrySink>.value(
              value: const NoopCatalogSearchTelemetrySink(),
            ),
            Provider<PlaybackTelemetrySink>.value(
              value: const NoopPlaybackTelemetrySink(),
            ),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: appRouter,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Catalog list loaded.
      expect(find.text('Song 1'), findsOneWidget);

      // Start playback so the mini player bar appears.
      audio.emit(
        PlaybackSnapshot(
          currentTrack: _t('1'),
          status: PlaybackStatus.playing,
          duration: const Duration(minutes: 1),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('player-mini-open')), findsOneWidget);

      // Open the player as a modal sheet from the mini bar.
      await tester.tap(find.byKey(const Key('player-mini-open')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('player-close-button')), findsOneWidget);

      // Dismiss the sheet -> the catalog list underneath stays intact.
      await tester.tap(find.byKey(const Key('player-close-button')));
      await tester.pumpAndSettle();

      // The list must still be visible — not stuck on an infinite spinner.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Song 1'), findsWidgets);
    },
  );
}
