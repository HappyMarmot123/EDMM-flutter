import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/l10n/app_localizations.dart';
import 'package:edmm/domain/audio/audio_controller.dart';
import 'package:edmm/domain/models/cloudinary_category.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/playback/playback_snapshot.dart';
import 'package:edmm/domain/repositories/track_repository.dart';
import 'package:edmm/domain/result.dart';
import 'package:edmm/ui/catalog_search/view_model/catalog_search_view_model.dart';
import 'package:edmm/ui/catalog_search/widgets/catalog_search_screen.dart';

Track _t(String id) => Track(
      id: id,
      source: 'cloudinary',
      title: 'Song $id',
      artistId: 'a',
      artistName: 'Artist',
      durationMs: 1,
      streamUrl: 'u',
      metadata: const {'resourceType': 'video'},
    );

class _Repo implements TrackRepository {
  _Repo(this.handler);
  Result<List<Track>> Function(CloudinaryCategory category, String query) handler;
  @override
  Future<Result<List<Track>>> getCatalog({
    required CloudinaryCategory category,
    String query = '',
    bool forceRefresh = false,
  }) async =>
      handler(category, query);
}

class _Audio implements AudioController {
  @override
  Stream<PlaybackSnapshot> get snapshot => Stream<PlaybackSnapshot>.empty();
  @override
  Stream<Duration> get position => Stream<Duration>.empty();
  @override
  Future<void> loadQueue(List<Track> tracks, {int initialIndex = 0}) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> next() async {}
  @override
  Future<void> previous() async {}
  @override
  Future<void> dispose() async {}
}

CatalogSearchViewModel _vm(
  Result<List<Track>> Function(CloudinaryCategory, String) handler,
) =>
    CatalogSearchViewModel(_Repo(handler), _Audio(), searchDebounce: Duration.zero);

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  testWidgets('renders rows and delegates onPlay on tap', (tester) async {
    final vm = _vm((c, q) => Ok([_t('1'), _t('2')]));
    List<Track>? queue;
    int? index;
    await tester.pumpWidget(_host(CatalogSearchScreen(
      viewModel: vm,
      onPlay: (q, i) {
        queue = q;
        index = i;
      },
    )));
    await tester.pumpAndSettle();

    expect(find.text('Song 1'), findsOneWidget);
    await tester.tap(find.text('Song 2'));
    expect(index, 1);
    expect(queue!.length, 2);
  });

  testWidgets('search with no results shows the clear-search action', (tester) async {
    final vm = _vm((c, q) => Ok(q == 'zzz' ? <Track>[] : [_t('1')]));
    await tester.pumpWidget(_host(CatalogSearchScreen(viewModel: vm, onPlay: (_, _) {})));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('No matching tracks'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Clear search'), findsOneWidget);
  });

  testWidgets('error after a success shows the stale list with a banner', (tester) async {
    var fail = false;
    final vm = _vm((c, q) => fail ? const Err<List<Track>>(NetworkFailure('x')) : Ok([_t('1')]));
    await tester.pumpWidget(_host(CatalogSearchScreen(viewModel: vm, onPlay: (_, _) {})));
    await tester.pumpAndSettle();

    fail = true;
    await vm.retry();
    await tester.pumpAndSettle();

    expect(find.text('Song 1'), findsOneWidget); // stale 유지
    expect(find.byType(MaterialBanner), findsOneWidget);
  });
}
