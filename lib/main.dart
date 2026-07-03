import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'routing/router.dart';
import 'ui/core/themes/theme.dart';

void main() {
  runApp(const EdmmApp());
}

class EdmmApp extends StatelessWidget {
  const EdmmApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Repository/Service가 생기면 이 지점을 MultiProvider로 감싸 전역 DI를 조립한다.
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: appRouter,
    );
  }
}
