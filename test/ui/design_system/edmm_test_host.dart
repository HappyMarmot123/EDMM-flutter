import 'package:edmm/l10n/app_localizations.dart';
import 'package:edmm/ui/core/themes/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

abstract final class EdmmTestViewports {
  static const Size compactPhone = Size(320, 568);
  static const Size standardPhone = Size(390, 844);
  static const Size tabletPortrait = Size(800, 1280);
}

class EdmmTestHost extends StatelessWidget {
  const EdmmTestHost({
    super.key,
    required this.child,
    this.locale = const Locale('en'),
    this.viewport,
    this.devicePixelRatio = 1,
    this.textScale = 1,
    this.safeArea,
    this.viewInsets,
    this.disableAnimations = false,
    this.platform = TargetPlatform.android,
  });

  final Widget child;
  final Locale locale;
  final Size? viewport;
  final double devicePixelRatio;
  final double textScale;
  final EdgeInsets? safeArea;
  final EdgeInsets? viewInsets;
  final bool disableAnimations;
  final TargetPlatform platform;

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.dark.copyWith(platform: platform);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      themeAnimationDuration: Duration.zero,
      builder: (context, appChild) {
        final inherited = MediaQuery.of(context);
        return MediaQuery(
          data: inherited.copyWith(
            size: viewport ?? inherited.size,
            devicePixelRatio: devicePixelRatio,
            textScaler: TextScaler.linear(textScale),
            padding: safeArea ?? inherited.padding,
            viewPadding: safeArea ?? inherited.viewPadding,
            viewInsets: viewInsets ?? inherited.viewInsets,
            platformBrightness: Brightness.dark,
            accessibleNavigation: disableAnimations,
            disableAnimations: disableAnimations,
          ),
          child: appChild!,
        );
      },
      home: child,
    );
  }
}

Future<void> pumpEdmmTestHost(
  WidgetTester tester, {
  required Widget child,
  Size viewport = EdmmTestViewports.standardPhone,
  double devicePixelRatio = 1,
  Locale locale = const Locale('en'),
  double textScale = 1,
  EdgeInsets safeArea = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
  bool disableAnimations = false,
  TargetPlatform platform = TargetPlatform.android,
}) async {
  tester.view.physicalSize = Size(
    viewport.width * devicePixelRatio,
    viewport.height * devicePixelRatio,
  );
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    EdmmTestHost(
      locale: locale,
      viewport: viewport,
      devicePixelRatio: devicePixelRatio,
      textScale: textScale,
      safeArea: safeArea,
      viewInsets: viewInsets,
      disableAnimations: disableAnimations,
      platform: platform,
      child: child,
    ),
  );
}
