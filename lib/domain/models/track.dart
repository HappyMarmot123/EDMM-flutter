// lib/domain/models/track.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'track.freezed.dart';
part 'track.g.dart';

@freezed
abstract class Track with _$Track {
  const Track._();
  const factory Track({
    required String id,
    required String source,
    required String title,
    required String artistId,
    required String artistName,
    String? albumName,
    @Default('') String artworkUrl,
    required int durationMs,
    String? streamUrl,
    @Default(<String, dynamic>{}) Map<String, dynamic> metadata,
  }) = _Track;

  factory Track.fromJson(Map<String, dynamic> json) => _$TrackFromJson(json);

  Duration get duration => Duration(milliseconds: durationMs);

  Uri? get playableUri {
    if ((metadata['resourceType'] as String?)?.toLowerCase() == 'image') {
      return null;
    }
    final value = streamUrl?.trim();
    if (value == null || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.isAbsolute || uri.host.isEmpty) return null;
    if (uri.toString() != value) return null;
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https' ? uri : null;
  }

  bool get isPlayable => playableUri != null;
}
