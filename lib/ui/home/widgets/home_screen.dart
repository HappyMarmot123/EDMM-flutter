import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../../l10n/app_localizations.dart';
import '../view_model/home_view_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void dispose() {
    widget.viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l10n.homeSetupDone),
              Text(
                '${widget.viewModel.counter}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: widget.viewModel.increment,
        tooltip: l10n.increment,
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Widget Preview용 로컬라이제이션 설정. AppLocalizations.of(context)가
/// 프리뷰 환경에서도 동작하도록 델리게이트를 주입한다.
/// (annotation 인자로 넘기므로 반드시 public top-level 함수여야 한다.)
PreviewLocalizationsData homePreviewLocalizations() => PreviewLocalizationsData(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('ko'),
);

/// 홈 화면 프리뷰. 앱 전체를 띄우지 않고 HomeScreen만 격리 렌더링한다.
@Preview(name: 'Home 화면 (ko)', localizations: homePreviewLocalizations)
Widget homeScreenPreview() => HomeScreen(viewModel: HomeViewModel());
