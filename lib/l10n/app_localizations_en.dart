// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'EDMM';

  @override
  String get homeSetupDone => 'Flutter project setup complete';

  @override
  String get increment => 'Increment';

  @override
  String get trackListTitle => 'Tracks';

  @override
  String get tracksLoadError => 'Couldn\'t load tracks';

  @override
  String get tracksEmpty => 'No tracks';

  @override
  String get retry => 'Retry';

  @override
  String get nowPlaying => 'Now Playing';

  @override
  String get unknownArtist => 'Unknown artist';

  @override
  String get searchHint => 'Search tracks';

  @override
  String get tabPop => 'Pop';

  @override
  String get tabEdm => 'EDM';

  @override
  String get tabRecent => 'Recent';

  @override
  String get searchNoResults => 'No matching tracks';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get catalogStaleWarning => 'Showing saved results — couldn\'t refresh';
}
