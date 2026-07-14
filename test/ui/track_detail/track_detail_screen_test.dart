import 'package:edmm/data/repositories/in_memory_local_library_repository.dart';
import 'package:edmm/domain/logic/track_resolver.dart';
import 'package:edmm/domain/models/cloudinary_category.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/repositories/track_repository.dart';
import 'package:edmm/domain/result.dart';
import 'package:edmm/ui/core/layout/edmm_breakpoints.dart';
import 'package:edmm/ui/track_detail/view_model/track_detail_view_model.dart';
import 'package:edmm/ui/track_detail/widgets/track_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../design_system/edmm_test_host.dart';

class _EmptyTracks implements TrackRepository {
  @override
  Future<Result<List<Track>>> getCatalog({
    required CloudinaryCategory category,
    String query = '',
    bool forceRefresh = false,
  }) async => const Ok([]);
}

class _RetryTracks implements TrackRepository {
  _RetryTracks(this.track);

  final Track track;
  bool fail = true;

  @override
  Future<Result<List<Track>>> getCatalog({
    required CloudinaryCategory category,
    String query = '',
    bool forceRefresh = false,
  }) async => fail
      ? const Err<List<Track>>(NetworkFailure('offline'))
      : Ok(<Track>[track]);
}

class _ThrowingCacheLibrary extends InMemoryLocalLibraryRepository {
  @override
  Future<void> cacheTrack(Track track) =>
      Future<void>.error(StateError('storage unavailable'));
}

const _track = Track(
  id: 'track-1',
  source: 'cloudinary',
  title: 'Bloom',
  artistId: 'artist',
  artistName: 'Feint',
  albumName: 'Monstercat',
  durationMs: 90_000,
  streamUrl: 'https://example.com/track-1.mp3',
  metadata: <String, dynamic>{'genre': 'Drum & Bass'},
);

const _longKoreanTrack = Track(
  id: 'track-ko',
  source: '클라우드 음악 보관함의 매우 긴 소스 이름',
  title: '작은 화면에서도 두 줄 이상 자연스럽게 이어지는 아주 긴 한국어 트랙 제목',
  artistId: 'artist-ko',
  artistName: '여러 아티스트가 함께 참여한 매우 긴 한국어 아티스트 이름',
  albumName: '앨범 이름 역시 화면 너비에 맞춰 자연스럽게 줄바꿈되어야 합니다',
  durationMs: 3_723_000,
  streamUrl: 'https://example.com/track-ko.mp3',
  metadata: <String, dynamic>{
    '긴 메타데이터 항목 이름':
        '고정된 라벨 열 없이 사용 가능한 공간에서 자연스럽게 여러 줄로 표시되는 긴 한국어 메타데이터 값입니다',
    '참여자': <String>['첫 번째 참여자', '두 번째 참여자'],
  },
);

TrackDetailViewModel _seededViewModel(
  Track track, {
  InMemoryLocalLibraryRepository? localLibrary,
}) {
  final local = localLibrary ?? InMemoryLocalLibraryRepository();
  return TrackDetailViewModel(
    trackId: track.id,
    initialTrack: track,
    resolver: TrackResolver(_EmptyTracks(), local),
    localLibrary: local,
  );
}

void main() {
  testWidgets(
    'compact layout keeps artwork, identity, play, and metadata order at text scale two',
    (tester) async {
      final vm = _seededViewModel(_longKoreanTrack);

      await pumpEdmmTestHost(
        tester,
        viewport: const Size(320, 568),
        locale: const Locale('ko'),
        textScale: 2,
        child: TrackDetailScreen(viewModel: vm, onPlay: (_) {}),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('track-detail-one-pane')), findsOneWidget);
      expect(find.byKey(const Key('track-detail-two-pane')), findsNothing);
      expect(find.byType(FittedBox), findsNothing);

      final artworkTop = tester
          .getTopLeft(find.byKey(const Key('track-detail-artwork')))
          .dy;
      final headingTop = tester
          .getTopLeft(find.byKey(const Key('track-detail-heading')))
          .dy;
      final playTop = tester
          .getTopLeft(find.byKey(const Key('track-detail-play')))
          .dy;
      final metadataTop = tester
          .getTopLeft(find.byKey(const Key('track-detail-core-metadata')))
          .dy;
      expect(artworkTop, lessThan(headingTop));
      expect(headingTop, lessThan(playTop));
      expect(playTop, lessThan(metadataTop));
      expect(
        tester.getSize(find.byKey(const Key('track-detail-play'))).height,
        greaterThanOrEqualTo(48),
      );

      await tester.ensureVisible(find.text('긴 메타데이터 항목 이름'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('고정된 라벨 열 없이'), findsOneWidget);
      expect(find.byKey(const Key('track-detail-favorite')), findsNothing);
      expect(find.byKey(const Key('track-detail-add-playlist')), findsNothing);
    },
  );

  for (final viewport in const <Size>[Size(600, 960), Size(800, 1280)]) {
    testWidgets(
      'uses the same two-pane composition at ${viewport.width.toInt()}dp',
      (tester) async {
        final vm = _seededViewModel(_longKoreanTrack);

        await pumpEdmmTestHost(
          tester,
          viewport: viewport,
          locale: const Locale('ko'),
          textScale: 2,
          child: TrackDetailScreen(viewModel: vm, onPlay: (_) {}),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('track-detail-two-pane')), findsOneWidget);
        expect(find.byKey(const Key('track-detail-one-pane')), findsNothing);
        final artwork = tester.getRect(
          find.byKey(const Key('track-detail-artwork')),
        );
        final heading = tester.getRect(
          find.byKey(const Key('track-detail-heading')),
        );
        expect(artwork.right, lessThan(heading.left));
        expect(
          tester.getSize(find.byKey(const Key('track-detail-play'))).height,
          greaterThanOrEqualTo(48),
        );
        expect(find.byType(FittedBox), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('wide content stays centered inside the shared max width', (
    tester,
  ) async {
    final vm = _seededViewModel(_track);

    await pumpEdmmTestHost(
      tester,
      viewport: const Size(1400, 900),
      child: TrackDetailScreen(viewModel: vm, onPlay: (_) {}),
    );
    await tester.pumpAndSettle();

    final frame = tester.getRect(find.byKey(const Key('edmm-content-frame')));
    expect(frame.width, EdmmBreakpoints.wideContentMaxWidth);
    expect(frame.center.dx, 700);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders sorted selectable metadata and only plays explicitly', (
    tester,
  ) async {
    final track = _track.copyWith(
      metadata: <String, dynamic>{
        'zeta': <String>['first', 'second'],
        'alpha': null,
      },
    );
    final vm = _seededViewModel(track);
    var playCount = 0;

    await pumpEdmmTestHost(
      tester,
      child: TrackDetailScreen(viewModel: vm, onPlay: (_) => playCount++),
    );
    await tester.pumpAndSettle();

    expect(playCount, 0);
    expect(find.text('Bloom'), findsOneWidget);
    expect(find.text('Feint'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SelectableText && widget.data == 'Monstercat',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SelectableText && widget.data == '1:30',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SelectableText && widget.data == '—',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SelectableText && widget.data == 'first, second',
      ),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text('alpha')).dy,
      lessThan(tester.getTopLeft(find.text('zeta')).dy),
    );

    await tester.tap(find.byKey(const Key('track-detail-play')));
    await tester.pump();
    expect(playCount, 1);
  });

  testWidgets('an unplayable track exposes a disabled 48dp play action', (
    tester,
  ) async {
    final vm = _seededViewModel(_track.copyWith(streamUrl: '/relative.mp3'));

    await pumpEdmmTestHost(
      tester,
      viewport: const Size(320, 568),
      child: TrackDetailScreen(viewModel: vm, onPlay: (_) {}),
    );
    await tester.pumpAndSettle();

    final play = tester.widget<FilledButton>(
      find.byKey(const Key('track-detail-play')),
    );
    expect(play.onPressed, isNull);
    expect(
      tester.getSize(find.byKey(const Key('track-detail-play'))).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('keeps not-found, retry, and storage-error states', (
    tester,
  ) async {
    final notFoundLocal = InMemoryLocalLibraryRepository();
    final notFoundVm = TrackDetailViewModel(
      trackId: 'missing',
      resolver: TrackResolver(_EmptyTracks(), notFoundLocal),
      localLibrary: notFoundLocal,
    );

    await pumpEdmmTestHost(
      tester,
      child: TrackDetailScreen(viewModel: notFoundVm, onPlay: (_) {}),
    );
    await tester.pumpAndSettle();
    expect(find.text('Track not found'), findsOneWidget);

    final retryLocal = InMemoryLocalLibraryRepository();
    final retryRepository = _RetryTracks(_track);
    final retryVm = TrackDetailViewModel(
      trackId: _track.id,
      resolver: TrackResolver(retryRepository, retryLocal),
      localLibrary: retryLocal,
    );
    await pumpEdmmTestHost(
      tester,
      child: TrackDetailScreen(viewModel: retryVm, onPlay: (_) {}),
    );
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load track details"), findsOneWidget);

    retryRepository.fail = false;
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Bloom'), findsOneWidget);

    final storageLocal = _ThrowingCacheLibrary();
    final storageVm = _seededViewModel(_track, localLibrary: storageLocal);
    await pumpEdmmTestHost(
      tester,
      child: TrackDetailScreen(viewModel: storageVm, onPlay: (_) {}),
    );
    await tester.pumpAndSettle();
    expect(find.text("Couldn't save track data locally"), findsOneWidget);
  });

  testWidgets('reinitializes a replacement view model', (tester) async {
    final firstVm = _seededViewModel(_track);
    final secondTrack = _track.copyWith(id: 'track-2', title: 'Second track');
    final secondVm = _seededViewModel(secondTrack);

    await pumpEdmmTestHost(
      tester,
      child: TrackDetailScreen(viewModel: firstVm, onPlay: (_) {}),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bloom'), findsOneWidget);

    await pumpEdmmTestHost(
      tester,
      child: TrackDetailScreen(viewModel: secondVm, onPlay: (_) {}),
    );
    await tester.pumpAndSettle();

    expect(find.text('Second track'), findsOneWidget);
    expect(find.text('Bloom'), findsNothing);
  });
}
