import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edmm/l10n/app_localizations.dart';
import 'package:edmm/domain/models/track.dart';
import 'package:edmm/domain/repositories/track_repository.dart';
import 'package:edmm/domain/result.dart';
import 'package:edmm/ui/track_list/view_model/track_list_view_model.dart';
import 'package:edmm/ui/track_list/widgets/track_list_screen.dart';

class _Repo implements TrackRepository {
  @override
  Future<Result<List<Track>>> getTracks({bool forceRefresh = false}) async =>
      const Ok<List<Track>>([]);
}

void main() {
  testWidgets('track list renders empty state without home placeholder', (tester) async {
    final vm = TrackListViewModel(_Repo());
    await vm.load();
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TrackListScreen(viewModel: vm, onPlay: (_, _) {}),
    ));
    await tester.pump();
    expect(find.text('No tracks'), findsOneWidget);
  });
}
