// lib/data/services/track_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../domain/models/track.dart';
import '../../domain/models/cloudinary_category.dart';

class TrackApiException implements Exception {
  TrackApiException({this.statusCode, this.cause});
  final int? statusCode;
  final Object? cause;
  @override
  String toString() =>
      'TrackApiException(statusCode: $statusCode, cause: $cause)';
}

class TrackApiService {
  TrackApiService(this._client, this._config);
  final http.Client _client;
  final AppConfig _config;

  Future<List<Track>> fetchCatalog({
    required CloudinaryCategory category,
    String query = '',
  }) => _get('/api/cloudinary/tracks', {
    'q': query,
    'resourceType': 'all',
    'category': category.wire,
  });

  Future<List<Track>> _get(
    String path,
    Map<String, String> queryParameters,
  ) async {
    final base = Uri.parse(_config.normalizedBffBaseUrl);
    final uri = Uri(
      scheme: base.scheme.isNotEmpty ? base.scheme : 'https',
      host: base.host,
      path: path,
      queryParameters: queryParameters,
    );
    final http.Response res;
    try {
      res = await _client.get(uri).timeout(_config.timeout);
    } catch (e) {
      throw TrackApiException(cause: e);
    }
    if (res.statusCode != 200) {
      throw TrackApiException(statusCode: res.statusCode);
    }
    try {
      final list = jsonDecode(res.body) as List<dynamic>;
      return list
          .map((e) => Track.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (e) {
      throw TrackApiException(cause: e);
    }
  }
}
