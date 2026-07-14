import '../models/track.dart';

class ArtworkMerger {
  static final _ext = RegExp(r'\.[a-z0-9]+$');
  static final _spaces = RegExp(r'\s+');
  static final _nonAlnum = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);

  static String normalizeForMatching(String value) {
    var v = value.trim().toLowerCase();
    v = v.replaceAll(_ext, '');
    v = v.replaceAll(_spaces, ' ');
    v = v.replaceAll(_nonAlnum, '');
    return v.trim();
  }

  static String? _publicIdStem(Track t) {
    final pid = t.metadata['publicId'] ?? t.metadata['public_id'];
    if (pid is! String || pid.trim().isEmpty) return null;
    final segs = pid.split('/').where((s) => s.isNotEmpty).toList();
    final base = segs.isNotEmpty ? segs.last : pid;
    return normalizeForMatching(base);
  }

  static Set<String> buildMatchKeys(Track t) {
    final keys = <String>{};
    final stem = _publicIdStem(t);
    final title = normalizeForMatching(t.title);
    final artist = normalizeForMatching(t.artistName);
    final album = t.albumName == null ? '' : normalizeForMatching(t.albumName!);
    if (stem != null && stem.isNotEmpty) keys.add(stem);
    if (title.isNotEmpty) {
      keys.add(title);
      if (album.isNotEmpty) keys.add('$title $album'.trim());
      if (artist.isNotEmpty) {
        keys.add('$artist $title'.trim());
        keys.add('$title $artist'.trim());
      }
    }
    if (artist.isNotEmpty) keys.add(artist);
    if (album.isNotEmpty) keys.add(album);
    return keys;
  }

  static List<Track> merge(List<Track> audio, List<Track> images) {
    final imageByKey = <String, Track>{};
    for (final img in images) {
      for (final k in buildMatchKeys(img)) {
        imageByKey.putIfAbsent(k, () => img);
      }
    }
    final seen = <String>{};
    final deduped = audio.where((a) => seen.add(a.id)).toList();
    return deduped.map((a) {
      if (a.artworkUrl.isNotEmpty) return a;
      for (final k in buildMatchKeys(a)) {
        final img = imageByKey[k];
        if (img != null) {
          final art = img.artworkUrl.isNotEmpty
              ? img.artworkUrl
              : (img.streamUrl ?? '');
          return a.copyWith(artworkUrl: art);
        }
      }
      return a;
    }).toList();
  }
}
