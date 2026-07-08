abstract final class Routes {
  static const String trackList = '/';
  static const String trackDetail = '/track/:id';
  static const String player = '/player';
}

/// `/track/:id` 딥링크를 검색 쉘의 selection seed(`/?track=<id>`)로 변환한다(웹 parity).
String trackDetailLocation(String id) => '/?track=${Uri.encodeComponent(id)}';
