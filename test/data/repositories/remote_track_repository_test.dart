import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/domain/models/cloudinary_category.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/repositories/track_repository.dart';
import 'package:edmm/domain/result.dart';
import 'package:edmm/data/repositories/remote_track_repository.dart';
import 'package:edmm/data/services/track_api_service.dart';

Track _audio(String id) => Track(
  id: id,
  source: 'cloudinary',
  title: id,
  artistId: 'a',
  artistName: 'A',
  durationMs: 1,
  streamUrl: 'https://audio.example/$id.m4a',
  metadata: const {'resourceType': 'video'},
);

Track _image(String id, String artworkUrl) => Track(
  id: 'image-$id',
  source: 'cloudinary',
  title: id,
  artistId: 'a',
  artistName: 'A',
  artworkUrl: artworkUrl,
  durationMs: 0,
  streamUrl: artworkUrl,
  metadata: const {'resourceType': 'image'},
);

class _FakeApi implements TrackApiService {
  _FakeApi(this.next);
  final Map<String, List<Track>> Function() next;
  int callCount = 0;

  @override
  Future<List<Track>> fetchCatalog({
    required CloudinaryCategory category,
    String query = '',
  }) async {
    callCount += 1;
    return next()['${category.wire}|$query']!;
  }
}

class _SequencedApi implements TrackApiService {
  final responses = <Completer<List<Track>>>[];
  var calls = 0;

  @override
  Future<List<Track>> fetchCatalog({
    required CloudinaryCategory category,
    String query = '',
  }) => responses[calls++].future;
}

void main() {
  test('merges audio and image tracks and caches by category/query', () async {
    final api = _FakeApi(
      () => {
        'pop|': [_audio('Bloom')],
        'pop|ambient': [_audio('Ambient')],
      },
    );
    final TrackRepository repo = RemoteTrackRepository(api);
    final r1 = await repo.getCatalog(
      category: CloudinaryCategory.pop,
      query: '',
    );
    expect(r1, isA<Ok<List<Track>>>());
    expect((r1 as Ok<List<Track>>).value.single.id, 'Bloom');

    final r2 = await repo.getCatalog(
      category: CloudinaryCategory.pop,
      query: 'ambient',
    );
    expect((r2 as Ok<List<Track>>).value.single.id, 'Ambient');

    final r3 = await repo.getCatalog(
      category: CloudinaryCategory.pop,
      query: '',
    );
    expect((r3 as Ok<List<Track>>).value.single.id, 'Bloom');
    expect(api.callCount, 2);
  });

  test('audio failure yields Err(ServerFailure)', () async {
    final api = _FakeApi(() => throw TrackApiException(statusCode: 500));
    final TrackRepository repo = RemoteTrackRepository(api);
    final r = await repo.getCatalog(category: CloudinaryCategory.edm);
    expect(r, isA<Err<List<Track>>>());
    expect((r as Err<List<Track>>).error, isA<ServerFailure>());
  });

  test('merges artwork before filtering strictly unplayable audio', () async {
    final invalid = _audio('Broken').copyWith(streamUrl: '/relative.m4a');
    final api = _FakeApi(
      () => {
        'pop|': [
          _audio('Bloom'),
          invalid,
          _image('Bloom', 'https://images.example/bloom.jpg'),
        ],
      },
    );
    final TrackRepository repo = RemoteTrackRepository(api);

    final result = await repo.getCatalog(category: CloudinaryCategory.pop);

    final tracks = (result as Ok<List<Track>>).value;
    expect(tracks.map((track) => track.id), ['Bloom']);
    expect(tracks.single.artworkUrl, 'https://images.example/bloom.jpg');
  });

  test('an older fetch cannot overwrite a newer cache value', () async {
    final api = _SequencedApi();
    final older = Completer<List<Track>>();
    final newer = Completer<List<Track>>();
    api.responses.addAll([older, newer]);
    final repo = RemoteTrackRepository(api);

    final olderLoad = repo.getCatalog(
      category: CloudinaryCategory.pop,
      query: 'same',
      forceRefresh: true,
    );
    final newerLoad = repo.getCatalog(
      category: CloudinaryCategory.pop,
      query: 'same',
      forceRefresh: true,
    );
    newer.complete([_audio('New')]);
    await newerLoad;
    older.complete([_audio('Old')]);
    await olderLoad;

    final cached = await repo.getCatalog(
      category: CloudinaryCategory.pop,
      query: 'same',
    );
    expect((cached as Ok<List<Track>>).value.single.id, 'New');
    expect(api.calls, 2);
  });
}
