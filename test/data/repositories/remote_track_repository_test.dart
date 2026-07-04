import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/repositories/track_repository.dart';
import 'package:edmm/domain/result.dart';
import 'package:edmm/data/repositories/remote_track_repository.dart';
import 'package:edmm/data/services/track_api_service.dart';

Track _audio(String t) => Track(id: t, source: 'cloudinary', title: t, artistId: 'a',
    artistName: 'A', durationMs: 1, streamUrl: 'u', metadata: const {'resourceType': 'video'});
Track _image(String t, String url) => Track(id: 'i$t', source: 'cloudinary', title: t,
    artistId: 'a', artistName: 'A', durationMs: 0, artworkUrl: url, streamUrl: url,
    metadata: const {'resourceType': 'image'});

class _FakeApi implements TrackApiService {
  _FakeApi({required this.audio, required this.images});
  final List<Track> Function() audio;
  final List<Track> Function() images;
  int audioCalls = 0;
  @override
  Future<List<Track>> fetchAudioTracks() async { audioCalls++; return audio(); }
  @override
  Future<List<Track>> fetchImageTracks() async => images();
}

void main() {
  test('merges artwork and caches (no refetch without forceRefresh)', () async {
    final api = _FakeApi(audio: () => [_audio('Bloom')], images: () => [_image('Bloom', 'art')]);
    final repo = RemoteTrackRepository(api);

    final r1 = await repo.getTracks();
    expect(r1, isA<Ok<List<Track>>>());
    expect((r1 as Ok<List<Track>>).value.single.artworkUrl, 'art');

    await repo.getTracks();
    expect(api.audioCalls, 1); // cached

    await repo.getTracks(forceRefresh: true);
    expect(api.audioCalls, 2);
  });

  test('image failure is best-effort; audio still returned', () async {
    final api = _FakeApi(audio: () => [_audio('Solo')], images: () => throw TrackApiException(statusCode: 500));
    final repo = RemoteTrackRepository(api);
    final r = await repo.getTracks();
    expect((r as Ok<List<Track>>).value.single.title, 'Solo');
  });

  test('audio failure yields Err(ServerFailure)', () async {
    final api = _FakeApi(audio: () => throw TrackApiException(statusCode: 502), images: () => []);
    final repo = RemoteTrackRepository(api);
    final r = await repo.getTracks();
    expect(r, isA<Err<List<Track>>>());
    expect((r as Err<List<Track>>).error, isA<ServerFailure>());
  });
}
