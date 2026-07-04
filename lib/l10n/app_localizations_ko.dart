// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'EDMM';

  @override
  String get homeSetupDone => 'Flutter 프로젝트 세팅 완료';

  @override
  String get increment => '증가';

  @override
  String get trackListTitle => '트랙';

  @override
  String get tracksLoadError => '트랙을 불러오지 못했습니다';

  @override
  String get tracksEmpty => '트랙이 없습니다';

  @override
  String get retry => '다시 시도';

  @override
  String get nowPlaying => '재생 중';

  @override
  String get unknownArtist => '알 수 없는 아티스트';
}
