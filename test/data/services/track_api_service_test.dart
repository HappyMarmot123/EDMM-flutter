// test/data/services/track_api_service_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:edmm/config/app_config.dart';
import 'package:edmm/data/services/track_api_service.dart';
import 'package:edmm/domain/models/cloudinary_category.dart';

const _config = AppConfig();

List<Map<String, dynamic>> _one(String rt) => [
  {
    'id': 'x',
    'source': 'cloudinary',
    'title': 'T',
    'artistId': 'a',
    'artistName': 'A',
    'durationMs': 1000,
    'streamUrl': 'u',
    'metadata': {'resourceType': rt},
  },
];

void main() {
  test('fetchCatalog hits unified endpoint and parses', () async {
    late Uri seen;
    final svc = TrackApiService(
      MockClient((req) async {
        seen = req.url;
        return http.Response(jsonEncode(_one('video')), 200);
      }),
      _config,
    );
    final tracks = await svc.fetchCatalog(
      category: CloudinaryCategory.pop,
      query: 'beat',
    );
    expect(seen.path, '/api/cloudinary/tracks');
    expect(seen.queryParameters['q'], 'beat');
    expect(seen.queryParameters['resourceType'], 'all');
    expect(seen.queryParameters['category'], 'pop');
    expect(seen.queryParameters['v'], '2');
    expect(tracks.single.title, 'T');
  });

  test(
    'fetchCatalog preserves the configured base port and path prefix',
    () async {
      late Uri seen;
      final svc = TrackApiService(
        MockClient((req) async {
          seen = req.url;
          return http.Response('[]', 200);
        }),
        const AppConfig(bffBaseUrl: 'http://localhost:4321/gateway/v1'),
      );

      await svc.fetchCatalog(category: CloudinaryCategory.pop);

      expect(seen.scheme, 'http');
      expect(seen.host, 'localhost');
      expect(seen.port, 4321);
      expect(seen.path, '/gateway/v1/api/cloudinary/tracks');
      expect(seen.queryParameters['v'], '2');
    },
  );

  test('non-200 throws TrackApiException with statusCode', () async {
    final svc = TrackApiService(
      MockClient((req) async => http.Response('{"error":"x"}', 502)),
      _config,
    );
    expect(
      () => svc.fetchCatalog(category: CloudinaryCategory.edm),
      throwsA(
        isA<TrackApiException>().having((e) => e.statusCode, 'statusCode', 502),
      ),
    );
  });

  test('network failure throws TrackApiException with cause', () async {
    final svc = TrackApiService(
      MockClient((_) async => throw const SocketException('no route')),
      _config,
    );
    await expectLater(
      svc.fetchCatalog(category: CloudinaryCategory.pop),
      throwsA(
        isA<TrackApiException>().having(
          (e) => e.cause,
          'cause',
          isA<SocketException>(),
        ),
      ),
    );
  });

  test(
    'malformed (non-list) JSON throws TrackApiException with cause',
    () async {
      final svc = TrackApiService(
        MockClient((_) async => http.Response('"not-a-list"', 200)),
        _config,
      );
      await expectLater(
        svc.fetchCatalog(category: CloudinaryCategory.pop),
        throwsA(
          isA<TrackApiException>().having((e) => e.cause, 'cause', isNotNull),
        ),
      );
    },
  );

  test(
    'fetchCatalog includes category/query/resourceType in query string',
    () async {
      late Uri seen;
      final svc = TrackApiService(
        MockClient((req) async {
          seen = req.url;
          return http.Response('[]', 200);
        }),
        _config,
      );
      await svc.fetchCatalog(category: CloudinaryCategory.edm, query: 'lofi');
      expect(seen.queryParameters['category'], 'edm');
      expect(seen.queryParameters['resourceType'], 'all');
      expect(seen.queryParameters['q'], 'lofi');
      expect(seen.queryParameters['v'], '2');
    },
  );
}
