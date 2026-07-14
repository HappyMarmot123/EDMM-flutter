enum EdmmWidthClass { compact, medium, expanded }

enum EdmmHeightClass { tight, compact, regular }

abstract final class EdmmBreakpoints {
  static const double mediumMinWidth = 600;
  static const double expandedMinWidth = 840;
  static const double compactMinHeight = 500;
  static const double regularMinHeight = 720;

  static const double compactGutter = 16;
  static const double mediumGutter = 24;
  static const double expandedGutter = 32;

  static const double readableContentMaxWidth = 720;
  static const double standardContentMaxWidth = readableContentMaxWidth;
  static const double wideContentMaxWidth = 1120;
  static const double playerOnePaneMaxWidth = 560;

  static EdmmWidthClass widthClassFor(double width) {
    if (width < mediumMinWidth) {
      return EdmmWidthClass.compact;
    }
    if (width < expandedMinWidth) {
      return EdmmWidthClass.medium;
    }
    return EdmmWidthClass.expanded;
  }

  static EdmmHeightClass heightClassFor(double height) {
    if (height < compactMinHeight) {
      return EdmmHeightClass.tight;
    }
    if (height < regularMinHeight) {
      return EdmmHeightClass.compact;
    }
    return EdmmHeightClass.regular;
  }

  static double gutterFor(double width) {
    return switch (widthClassFor(width)) {
      EdmmWidthClass.compact => compactGutter,
      EdmmWidthClass.medium => mediumGutter,
      EdmmWidthClass.expanded => expandedGutter,
    };
  }

  static bool usePlayerTwoPane({
    required double maxWidth,
    required double maxHeight,
  }) {
    return maxWidth >= expandedMinWidth ||
        (maxWidth >= mediumMinWidth &&
            maxHeight < 600 &&
            maxWidth / maxHeight >= 1.2);
  }
}
