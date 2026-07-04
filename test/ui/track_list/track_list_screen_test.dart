// test/ui/track_list/track_list_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/l10n/app_localizations.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/repositories/track_repository.dart';
import 'package:edmm/domain/result.dart';
import 'package:edmm/ui/track_list/view_model/track_list_view_model.dart';
import 'package:edmm/ui/track_list/widgets/track_list_screen.dart';

class _Repo implements TrackRepository {
  _Repo(this.result);
  final Result<List<Track>> result;
  @override
  Future<Result<List<Track>>> getTracks({bool forceRefresh = false}) async => result;
}

Track _t(String id) => Track(id: id, source: 'cloudinary', title: 'Song $id',
    artistId: 'a', artistName: 'Artist', durationMs: 1, streamUrl: 'u', metadata: const {});

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  testWidgets('renders rows and fires onPlay on tap', (tester) async {
    final vm = TrackListViewModel(_Repo(Ok([_t('1'), _t('2')])));
    await vm.load();
    List<Track>? playedQueue;
    int? playedIndex;
    await tester.pumpWidget(_host(TrackListScreen(
      viewModel: vm,
      onPlay: (q, i) { playedQueue = q; playedIndex = i; },
    )));
    await tester.pump();
    expect(find.text('Song 1'), findsOneWidget);
    await tester.tap(find.text('Song 2'));
    expect(playedIndex, 1);
    expect(playedQueue!.length, 2);
  });
}
