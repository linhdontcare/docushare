// ==============================================================================
// CORE LAYER: Responsive Breakpoints & Device Adaptive Helpers
// Định nghĩa các ngưỡng breakpoint chuẩn cho Mobile, Tablet và Desktop Web:
// - Mobile: < 600 px
// - Tablet: 600 px đến < 1024 px
// - Desktop Web: >= 1024 px
// ==============================================================================

import 'package:flutter/material.dart';

enum ScreenType {
  mobile,
  tablet,
  desktop,
}

class AppBreakpoints {
  AppBreakpoints._();

  static const double mobileMax = 600.0;
  static const double tabletMax = 1024.0;
  static const double desktopContentMaxWidth = 1360.0;
  static const double formContentMaxWidth = 720.0;
  static const double dialogMaxWidth = 540.0;

  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < mobileMax) {
      return ScreenType.mobile;
    } else if (width < tabletMax) {
      return ScreenType.tablet;
    } else {
      return ScreenType.desktop;
    }
  }

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileMax;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobileMax && width < tabletMax;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletMax;

  /// Giá trị thích nghi theo breakpoint
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= tabletMax && desktop != null) {
      return desktop;
    }
    if (width >= mobileMax && tablet != null) {
      return tablet;
    }
    return mobile;
  }
}

/// Tiện ích mở rộng trực tiếp trên BuildContext
extension ResponsiveContextExtension on BuildContext {
  ScreenType get screenType => AppBreakpoints.getScreenType(this);
  bool get isMobile => AppBreakpoints.isMobile(this);
  bool get isTablet => AppBreakpoints.isTablet(this);
  bool get isDesktop => AppBreakpoints.isDesktop(this);
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  T responsive<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    return AppBreakpoints.value(
      this,
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
    );
  }
}
