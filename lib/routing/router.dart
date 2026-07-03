import 'package:go_router/go_router.dart';

import '../ui/home/view_model/home_view_model.dart';
import '../ui/home/widgets/home_screen.dart';
import 'routes.dart';

/// 앱 전역 라우터. ViewModel은 라우트 진입 시 생성해 View에 주입한다.
/// Repository가 생기면 context.read()로 조회해 ViewModel 생성자에 넘긴다.
final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(
      path: Routes.home,
      builder: (context, state) => HomeScreen(viewModel: HomeViewModel()),
    ),
  ],
);
