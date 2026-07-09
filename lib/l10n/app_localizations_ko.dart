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

  @override
  String get searchHint => '트랙 검색';

  @override
  String get tabPop => 'Pop';

  @override
  String get tabEdm => 'EDM';

  @override
  String get tabRecent => '최근';

  @override
  String get searchNoResults => '일치하는 트랙이 없습니다';

  @override
  String get clearSearch => '검색 지우기';

  @override
  String get catalogStaleWarning => '저장된 결과 표시 중 — 새로고침 실패';

  @override
  String get playerNoTrackLoaded => '로드된 트랙이 없습니다';

  @override
  String get playerDismiss => '닫기';

  @override
  String get playerEqualizer => '이퀄라이저';

  @override
  String get playerEqualizerUnsupportedPlatform =>
      '이퀄라이저는 지원되는 Android, iOS, macOS 기기에서 사용할 수 있습니다';

  @override
  String get playerEqualizerUnavailable => '이 기기에서는 이퀄라이저를 사용할 수 없습니다';

  @override
  String get playbackStatusIdle => '대기';

  @override
  String get playbackStatusLoading => '로딩 중';

  @override
  String get playbackStatusReady => '준비됨';

  @override
  String get playbackStatusPlaying => '재생 중';

  @override
  String get playbackStatusPaused => '일시정지';

  @override
  String get playbackStatusCompleted => '완료';

  @override
  String get playbackStatusError => '오류';

  @override
  String get playbackErrorNetwork => '오디오를 불러오는 중 네트워크 문제가 발생했습니다';

  @override
  String playbackErrorServer(int statusCode) {
    return '서버 오류 ($statusCode)';
  }

  @override
  String get playbackErrorInvalidData => '재생 데이터가 올바르지 않습니다';
}
