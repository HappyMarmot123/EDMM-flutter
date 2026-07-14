// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'track.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Track _$TrackFromJson(Map<String, dynamic> json) => _Track(
  id: json['id'] as String,
  source: json['source'] as String,
  title: json['title'] as String,
  artistId: json['artistId'] as String,
  artistName: json['artistName'] as String,
  albumName: json['albumName'] as String?,
  artworkUrl: json['artworkUrl'] as String? ?? '',
  durationMs: (json['durationMs'] as num).toInt(),
  streamUrl: json['streamUrl'] as String?,
  metadata:
      json['metadata'] as Map<String, dynamic>? ?? const <String, dynamic>{},
);

Map<String, dynamic> _$TrackToJson(_Track instance) => <String, dynamic>{
  'id': instance.id,
  'source': instance.source,
  'title': instance.title,
  'artistId': instance.artistId,
  'artistName': instance.artistName,
  'albumName': instance.albumName,
  'artworkUrl': instance.artworkUrl,
  'durationMs': instance.durationMs,
  'streamUrl': instance.streamUrl,
  'metadata': instance.metadata,
};
