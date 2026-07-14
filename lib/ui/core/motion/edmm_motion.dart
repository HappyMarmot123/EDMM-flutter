import 'package:flutter/material.dart';

abstract final class EdmmMotion {
  static const Duration quick = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 180);
  static const Duration emphasis = Duration(milliseconds: 280);
  static const Duration ambient = Duration(milliseconds: 450);

  static const Curve enterCurve = Curves.easeOut;
  static const Curve exitCurve = Curves.easeIn;

  static bool reducedMotionOf(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    return (mediaQuery?.disableAnimations ?? false) ||
        (mediaQuery?.accessibleNavigation ?? false);
  }

  static Duration resolve(Duration duration, {required bool reduceMotion}) {
    return reduceMotion ? Duration.zero : duration;
  }

  static Duration resolveForContext(BuildContext context, Duration duration) {
    return resolve(duration, reduceMotion: reducedMotionOf(context));
  }
}
