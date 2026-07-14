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
  String get catalogLoading => 'Loading tracks';

  @override
  String get tracksLoadError => 'Couldn\'t load tracks';

  @override
  String get tracksEmpty => 'No tracks';

  @override
  String get retry => 'Retry';

  @override
  String get nowPlaying => 'Now Playing';

  @override
  String get trackStatePlaying => 'Currently playing';

  @override
  String get trackStatePaused => 'Current track, paused';

  @override
  String get trackStateUnavailable => 'Unavailable';

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

  @override
  String get playerNoTrackLoaded => 'No track loaded';

  @override
  String get playerDismiss => 'Dismiss';

  @override
  String get playerShuffle => 'Shuffle';

  @override
  String get playerPrevious => 'Previous track';

  @override
  String get playerPlay => 'Play';

  @override
  String get playerPause => 'Pause';

  @override
  String get playerNext => 'Next track';

  @override
  String get playerVisualizerEnable => 'Show audio spectrum';

  @override
  String get playerVisualizerDisable => 'Hide audio spectrum';

  @override
  String get playerVisualizerUnavailable =>
      'Audio spectrum is unavailable for this output';

  @override
  String get playerProgress => 'Playback progress';

  @override
  String playerProgressValue(String position, String duration) {
    return '$position of $duration';
  }

  @override
  String get playerVolume => 'Volume';

  @override
  String get playerVisualizer => 'Audio spectrum';

  @override
  String get playerMute => 'Mute';

  @override
  String get playerUnmute => 'Unmute';

  @override
  String get playerOpen => 'Open full player';

  @override
  String get playerEqualizer => 'Equalizer';

  @override
  String get playerEqualizerPresetFlat => 'Flat';

  @override
  String get playerEqualizerPresetFlatHelp =>
      'Keeps the original balance with no EQ coloring';

  @override
  String get playerEqualizerPresetBass => 'Bass Boost';

  @override
  String get playerEqualizerPresetBassHelp =>
      'Adds low-end punch with a clean midrange scoop';

  @override
  String get playerEqualizerUnsupportedPlatform =>
      'Equalizer is available on supported Android, iOS, and macOS devices';

  @override
  String get playerEqualizerUnavailable =>
      'Equalizer is unavailable on this device';

  @override
  String get playbackStatusIdle => 'Idle';

  @override
  String get playbackStatusLoading => 'Loading';

  @override
  String get playbackStatusReady => 'Ready';

  @override
  String get playbackStatusPlaying => 'Playing';

  @override
  String get playbackStatusPaused => 'Paused';

  @override
  String get playbackStatusCompleted => 'Completed';

  @override
  String get playbackStatusError => 'Error';

  @override
  String get playbackErrorNetwork => 'Network issue while loading audio';

  @override
  String playbackErrorServer(int statusCode) {
    return 'Server error ($statusCode)';
  }

  @override
  String get playbackErrorInvalidData => 'Playback data is invalid';

  @override
  String get localStorageError => 'Couldn\'t save track data locally';

  @override
  String get trackDetailsTitle => 'Track details';

  @override
  String get trackNotFound => 'Track not found';

  @override
  String get trackDetailLoadError => 'Couldn\'t load track details';

  @override
  String get trackPlay => 'Play';

  @override
  String get albumLabel => 'Album';

  @override
  String get sourceLabel => 'Source';

  @override
  String get durationLabel => 'Duration';

  @override
  String get metadataTitle => 'Metadata';

  @override
  String get unknownAlbum => 'Unknown album';

  @override
  String get openTrackDetails => 'Open track details';
}
