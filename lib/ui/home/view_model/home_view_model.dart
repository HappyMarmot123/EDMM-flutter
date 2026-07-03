import 'package:flutter/foundation.dart';

/// 홈 화면의 UI 상태와 로직. View(HomeScreen)와 1:1로 대응한다.
class HomeViewModel extends ChangeNotifier {
  int _counter = 0;

  int get counter => _counter;

  void increment() {
    _counter++;
    notifyListeners();
  }
}
