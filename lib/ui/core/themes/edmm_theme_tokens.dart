import 'package:flutter/material.dart';

abstract final class EdmmColors {
  static const Color canvasDeep = Color(0xFF030206);
  static const Color canvas = Color(0xFF050306);
  static const Color surface = Color(0xFF0B0609);
  static const Color surfaceRaised = Color(0xFF14121B);
  static const Color surfaceRose = Color(0xFF2B111C);

  static const Color brand = Color(0xFFFF98A2);
  static const Color brandSoft = Color(0xFFFFB8C0);
  static const Color playbackActive = Color(0xFFFD6D94);

  static const Color textPrimary = Color(0xFFFFF7FB);
  static const Color textMuted = Color(0xFFCDBDC7);
  static const Color disabledContent = Color(0x61CDBDC7);
  static const Color onBrand = Color(0xFF16070B);

  static const Color outline = Color(0x1FFFFFFF);
  static const Color outlineSubtle = Color(0x14FFFFFF);
  static const Color outlineBrand = Color(0xB3FF98A2);
  static const Color focusRing = brand;

  static const Color error = Color(0xFFFF6B7A);
  static const Color errorContainer = Color(0xFF4B1118);
  static const Color onErrorContainer = Color(0xFFFFD8DE);
}

abstract final class EdmmSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double display = 48;
}

abstract final class EdmmRadii {
  static const double small = 8;
  static const double medium = 12;
  static const double large = 20;
  static const double pill = 999;
}

abstract final class EdmmSizes {
  static const double minTouchTarget = 48;
  static const double prominentAction = 64;
}

abstract final class EdmmEffects {
  static const double backdropScrimOpacity = 0.72;
  static const double artworkBackdropBlurSigma = 28;
  static const int artworkDecodeLongestSide = 1024;
}

abstract final class EdmmTypography {
  static const TextStyle display = TextStyle(
    fontSize: 32,
    height: 38 / 32,
    fontWeight: FontWeight.w900,
  );
  static const TextStyle compactDisplay = TextStyle(
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w900,
  );
  static const TextStyle screenTitle = TextStyle(
    fontSize: 26,
    height: 32 / 26,
    fontWeight: FontWeight.w800,
  );
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w800,
  );
  static const TextStyle trackTitle = TextStyle(
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle bodyStrong = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle buttonLabel = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle utilityLabel = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.6,
  );
  static const TextStyle timeData = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );
  static const TextStyle tooltip = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
  );
}
