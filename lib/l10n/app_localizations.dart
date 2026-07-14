import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'EDMM'**
  String get appTitle;

  /// No description provided for @homeSetupDone.
  ///
  /// In en, this message translates to:
  /// **'Flutter project setup complete'**
  String get homeSetupDone;

  /// No description provided for @increment.
  ///
  /// In en, this message translates to:
  /// **'Increment'**
  String get increment;

  /// No description provided for @trackListTitle.
  ///
  /// In en, this message translates to:
  /// **'Tracks'**
  String get trackListTitle;

  /// No description provided for @catalogLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading tracks'**
  String get catalogLoading;

  /// No description provided for @tracksLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load tracks'**
  String get tracksLoadError;

  /// No description provided for @tracksEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tracks'**
  String get tracksEmpty;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @nowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now Playing'**
  String get nowPlaying;

  /// No description provided for @trackStatePlaying.
  ///
  /// In en, this message translates to:
  /// **'Currently playing'**
  String get trackStatePlaying;

  /// No description provided for @trackStatePaused.
  ///
  /// In en, this message translates to:
  /// **'Current track, paused'**
  String get trackStatePaused;

  /// No description provided for @trackStateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get trackStateUnavailable;

  /// No description provided for @unknownArtist.
  ///
  /// In en, this message translates to:
  /// **'Unknown artist'**
  String get unknownArtist;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search tracks'**
  String get searchHint;

  /// No description provided for @tabPop.
  ///
  /// In en, this message translates to:
  /// **'Pop'**
  String get tabPop;

  /// No description provided for @tabEdm.
  ///
  /// In en, this message translates to:
  /// **'EDM'**
  String get tabEdm;

  /// No description provided for @tabRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get tabRecent;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching tracks'**
  String get searchNoResults;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @catalogStaleWarning.
  ///
  /// In en, this message translates to:
  /// **'Showing saved results — couldn\'t refresh'**
  String get catalogStaleWarning;

  /// No description provided for @playerNoTrackLoaded.
  ///
  /// In en, this message translates to:
  /// **'No track loaded'**
  String get playerNoTrackLoaded;

  /// No description provided for @playerDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get playerDismiss;

  /// No description provided for @playerShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get playerShuffle;

  /// No description provided for @playerPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous track'**
  String get playerPrevious;

  /// No description provided for @playerPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playerPlay;

  /// No description provided for @playerPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get playerPause;

  /// No description provided for @playerNext.
  ///
  /// In en, this message translates to:
  /// **'Next track'**
  String get playerNext;

  /// No description provided for @playerVisualizerEnable.
  ///
  /// In en, this message translates to:
  /// **'Show audio spectrum'**
  String get playerVisualizerEnable;

  /// No description provided for @playerVisualizerDisable.
  ///
  /// In en, this message translates to:
  /// **'Hide audio spectrum'**
  String get playerVisualizerDisable;

  /// No description provided for @playerVisualizerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Audio spectrum is unavailable for this output'**
  String get playerVisualizerUnavailable;

  /// No description provided for @playerProgress.
  ///
  /// In en, this message translates to:
  /// **'Playback progress'**
  String get playerProgress;

  /// No description provided for @playerProgressValue.
  ///
  /// In en, this message translates to:
  /// **'{position} of {duration}'**
  String playerProgressValue(String position, String duration);

  /// No description provided for @playerVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get playerVolume;

  /// No description provided for @playerVisualizer.
  ///
  /// In en, this message translates to:
  /// **'Audio spectrum'**
  String get playerVisualizer;

  /// No description provided for @playerMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get playerMute;

  /// No description provided for @playerUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get playerUnmute;

  /// No description provided for @playerOpen.
  ///
  /// In en, this message translates to:
  /// **'Open full player'**
  String get playerOpen;

  /// No description provided for @playerEqualizer.
  ///
  /// In en, this message translates to:
  /// **'Equalizer'**
  String get playerEqualizer;

  /// No description provided for @playerEqualizerPresetFlat.
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get playerEqualizerPresetFlat;

  /// No description provided for @playerEqualizerPresetFlatHelp.
  ///
  /// In en, this message translates to:
  /// **'Keeps the original balance with no EQ coloring'**
  String get playerEqualizerPresetFlatHelp;

  /// No description provided for @playerEqualizerPresetBass.
  ///
  /// In en, this message translates to:
  /// **'Bass Boost'**
  String get playerEqualizerPresetBass;

  /// No description provided for @playerEqualizerPresetBassHelp.
  ///
  /// In en, this message translates to:
  /// **'Adds low-end punch with a clean midrange scoop'**
  String get playerEqualizerPresetBassHelp;

  /// No description provided for @playerEqualizerUnsupportedPlatform.
  ///
  /// In en, this message translates to:
  /// **'Equalizer is available on supported Android, iOS, and macOS devices'**
  String get playerEqualizerUnsupportedPlatform;

  /// No description provided for @playerEqualizerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Equalizer is unavailable on this device'**
  String get playerEqualizerUnavailable;

  /// No description provided for @playbackStatusIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get playbackStatusIdle;

  /// No description provided for @playbackStatusLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get playbackStatusLoading;

  /// No description provided for @playbackStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get playbackStatusReady;

  /// No description provided for @playbackStatusPlaying.
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get playbackStatusPlaying;

  /// No description provided for @playbackStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get playbackStatusPaused;

  /// No description provided for @playbackStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get playbackStatusCompleted;

  /// No description provided for @playbackStatusError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get playbackStatusError;

  /// No description provided for @playbackErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network issue while loading audio'**
  String get playbackErrorNetwork;

  /// No description provided for @playbackErrorServer.
  ///
  /// In en, this message translates to:
  /// **'Server error ({statusCode})'**
  String playbackErrorServer(int statusCode);

  /// No description provided for @playbackErrorInvalidData.
  ///
  /// In en, this message translates to:
  /// **'Playback data is invalid'**
  String get playbackErrorInvalidData;

  /// No description provided for @localStorageError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save track data locally'**
  String get localStorageError;

  /// No description provided for @trackDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Track details'**
  String get trackDetailsTitle;

  /// No description provided for @trackNotFound.
  ///
  /// In en, this message translates to:
  /// **'Track not found'**
  String get trackNotFound;

  /// No description provided for @trackDetailLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load track details'**
  String get trackDetailLoadError;

  /// No description provided for @trackPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get trackPlay;

  /// No description provided for @albumLabel.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get albumLabel;

  /// No description provided for @sourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get sourceLabel;

  /// No description provided for @durationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get durationLabel;

  /// No description provided for @metadataTitle.
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get metadataTitle;

  /// No description provided for @unknownAlbum.
  ///
  /// In en, this message translates to:
  /// **'Unknown album'**
  String get unknownAlbum;

  /// No description provided for @openTrackDetails.
  ///
  /// In en, this message translates to:
  /// **'Open track details'**
  String get openTrackDetails;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
