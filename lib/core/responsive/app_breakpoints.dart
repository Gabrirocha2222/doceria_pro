abstract final class AppBreakpoints {
  static const double medium = 760;
  static const double expanded = 1100;
  static const double extraLarge = 1400;

  static bool isCompactWidth(double width) => width < medium;

  static bool isExpandedWidth(double width) => width >= expanded;

  static bool shouldExtendRail(double width) => width >= extraLarge;

  static double contentMaxWidth(double width) {
    if (width >= extraLarge) {
      return 1240;
    }

    if (width >= expanded) {
      return 1100;
    }

    return width;
  }
}
