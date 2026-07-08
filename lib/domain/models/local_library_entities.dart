class FavoriteRow {
  const FavoriteRow({this.id, required this.trackId, required this.addedAt});

  final int? id;
  final String trackId;
  final int addedAt;

  factory FavoriteRow.fromMap(Map<String, dynamic> map) => FavoriteRow(
    id: map['id'] as int?,
    trackId: map['track_id'] as String,
    addedAt: map['added_at'] as int,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'track_id': trackId,
    'added_at': addedAt,
  };
}

class PlaylistRow {
  const PlaylistRow({this.id, required this.name, required this.createdAt});

  final int? id;
  final String name;
  final int createdAt;

  factory PlaylistRow.fromMap(Map<String, dynamic> map) => PlaylistRow(
    id: map['id'] as int?,
    name: map['name'] as String,
    createdAt: map['created_at'] as int,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'created_at': createdAt,
  };
}

class RecentPlayRow {
  const RecentPlayRow({this.id, required this.trackId, required this.playedAt});

  final int? id;
  final String trackId;
  final int playedAt;

  factory RecentPlayRow.fromMap(Map<String, dynamic> map) => RecentPlayRow(
    id: map['id'] as int?,
    trackId: map['track_id'] as String,
    playedAt: map['played_at'] as int,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'track_id': trackId,
    'played_at': playedAt,
  };
}
