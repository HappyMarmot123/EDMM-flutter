import 'dart:io';

import 'package:edmm/data/repositories/file_local_library_repository.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Track _track(String id) => Track(
  id: id,
  source: 'cloudinary',
  title: id,
  artistId: 'artist-$id',
  artistName: 'Artist $id',
  durationMs: 1234,
  streamUrl: 'https://example.com/$id',
  metadata: const {},
);

void main() {
  group('FileLocalLibraryRepository', () {
    test(
      'persists and restores favorites, playlists, recents, cache, and settings',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final dir = await Directory.systemTemp.createTemp(
          'edmm-file-local-library-repo-',
        );
        final file = File('${dir.path}/edmm_local_library.json');
        addTearDown(() => dir.delete(recursive: true));

        final repo = await FileLocalLibraryRepository.open(
          filePath: file.path,
          prefs: prefs,
        );

        await repo.setFavorite('track-1', true);
        await repo.setFavorite('track-2', true);

        final playlistId = await repo.createPlaylist('Mix');
        await repo.addTrackToPlaylist(playlistId, 'track-1');
        await repo.addTrackToPlaylist(playlistId, 'track-2');

        await repo.recordRecentPlay('track-1');
        await repo.recordRecentPlay('track-2');

        await repo.cacheTrack(_track('track-1'));
        await repo.cacheTrack(_track('track-2'));

        await repo.setAudioSetting('shuffle', 'true');

        final reopen = await FileLocalLibraryRepository.open(
          filePath: file.path,
          prefs: prefs,
        );

        expect(
          (await reopen.getFavorites()).map((row) => row.trackId).toList(),
          ['track-2', 'track-1'],
        );
        final playlists = await reopen.getPlaylists();
        expect(playlists, hasLength(1));
        expect(playlists.first.name, 'Mix');
        expect(await reopen.getPlaylistTrackIds(playlistId), [
          'track-1',
          'track-2',
        ]);
        expect(await reopen.getRecentTrackIds(), ['track-2', 'track-1']);
        expect((await reopen.getCachedTrack('track-2'))?.id, 'track-2');
        expect(await reopen.getAudioSetting('shuffle'), 'true');
      },
    );

    test('handles corrupted JSON file safely without throwing', () async {
      SharedPreferences.setMockInitialValues({
        'audio_setting:shuffle': 'false',
      });
      final prefs = await SharedPreferences.getInstance();

      final dir = await Directory.systemTemp.createTemp(
        'edmm-file-local-library-corrupt-',
      );
      final file = File('${dir.path}/edmm_local_library.json');
      await file.writeAsString('{not-json}', flush: true);
      addTearDown(() => dir.delete(recursive: true));

      final repo = await FileLocalLibraryRepository.open(
        filePath: file.path,
        prefs: prefs,
      );

      expect(await repo.getFavorites(), isEmpty);
      expect(await repo.getPlaylists(), isEmpty);
      expect(await repo.getRecentTrackIds(), isEmpty);
      expect(await repo.getCachedTrack('any'), isNull);
      expect(await repo.getAudioSetting('shuffle'), 'false');

      await repo.setFavorite('track-safe', true);
      expect(await repo.isFavorite('track-safe'), true);
    });
  });
}
