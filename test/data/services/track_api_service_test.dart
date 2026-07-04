// test/data/services/track_api_service_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:edmm/config/app_config.dart';
import 'package:edmm/data/services/track_api_service.dart';

const _config = AppConfig();

List<Map<String, dynamic>> _one(String rt) => [
      {'id': 'x', 'source': 'cloudinary', 'title': 'T', 'artistId': 'a',
       'artistName': 'A', 'durationMs': 1000, 'streamUrl': 'u',
       'metadata': {'resourceType': rt}},
    ];

void main() {
  test('fetchAudioTracks hits /video?filterPlayable=true and parses', () async {
    late Uri seen;
    final svc = TrackApiService(
      MockClient((req) async { seen = req.url; return http.Response(jsonEncode(_one('video')), 200); }),
      _config,
    );
    final tracks = await svc.fetchAudioTracks();
    expect(seen.path, '/api/cloudinary/tracks/video');
    expect(seen.queryParameters['filterPlayable'], 'true');
    expect(tracks.single.title, 'T');
  });

  test('non-200 throws TrackApiException with statusCode', () async {
    final svc = TrackApiService(MockClient((req) async => http.Response('{"error":"x"}', 502)), _config);
    expect(() => svc.fetchImageTracks(),
        throwsA(isA<TrackApiException>().having((e) => e.statusCode, 'statusCode', 502)));
  });
}
