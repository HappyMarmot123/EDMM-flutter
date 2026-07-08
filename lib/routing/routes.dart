abstract final class Routes {
  static const String trackList = '/';
  static const String trackDetail = '/track/:id';
  static const String player = '/player';
}

/// `/track/:id` 딥링크 URL을 생성한다.
String trackDetailLocation(String id) => '/track/${Uri.encodeComponent(id)}';
