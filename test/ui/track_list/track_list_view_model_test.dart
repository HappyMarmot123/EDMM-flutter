import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/repositories/track_repository.dart';
import 'package:edmm/domain/result.dart';
import 'package:edmm/ui/track_list/view_model/track_list_view_model.dart';

class _Repo implements TrackRepository {
  _Repo(this.result);
  Result<List<Track>> result;
  bool lastForceRefresh = false;
  @override
  Future<Result<List<Track>>> getTracks({bool forceRefresh = false}) async {
    lastForceRefresh = forceRefresh;
    return result;
  }
}

Track _t(String id) => Track(id: id, source: 'cloudinary', title: id, artistId: 'a',
    artistName: 'A', durationMs: 1, streamUrl: 'u', metadata: const {});

void main() {
  test('load -> data when non-empty', () async {
    final vm = TrackListViewModel(_Repo(Ok([_t('1')])));
    await vm.load();
    expect(vm.status, TrackListStatus.data);
    expect(vm.tracks.length, 1);
  });

  test('load -> empty when empty', () async {
    final vm = TrackListViewModel(_Repo(const Ok<List<Track>>([])));
    await vm.load();
    expect(vm.status, TrackListStatus.empty);
  });

  test('load -> error on Err', () async {
    final vm = TrackListViewModel(_Repo(const Err<List<Track>>(ServerFailure(502))));
    await vm.load();
    expect(vm.status, TrackListStatus.error);
    expect(vm.error, isA<ServerFailure>());
  });

  test('load notifies listeners (loading + final)', () async {
    final vm = TrackListViewModel(_Repo(Ok([_t('1')])));
    var calls = 0;
    vm.addListener(() => calls++);
    await vm.load();
    expect(calls, greaterThanOrEqualTo(2));
  });

  test('load forwards forceRefresh to repository', () async {
    final repo = _Repo(Ok(<Track>[]));
    final vm = TrackListViewModel(repo);
    await vm.load(forceRefresh: true);
    expect(repo.lastForceRefresh, isTrue);
  });
}
