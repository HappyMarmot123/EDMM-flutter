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

  bool get isPlayable =>
      (streamUrl?.trim().isNotEmpty ?? false) &&
      (metadata['resourceType'] as String?)?.toLowerCase() != 'image';
}
