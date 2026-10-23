// ==============================================================================
// CORE LAYER: Responsive Layout Builder & Constrained Container
// Cung cấp Widget xây dựng giao diện theo LayoutBuilder và bao bọc chiều rộng tối đa
// ==============================================================================

import 'package:flutter/material.dart';
import 'app_breakpoints.dart';

typedef ResponsiveWidgetBuilder = Widget Function(
  BuildContext context,
  BoxConstraints constraints,
  ScreenType screenType,
);

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  final ResponsiveWidgetBuilder? builder;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  }) : builder = null;

  const ResponsiveLayout.builder({
    super.key,
    required this.builder,
  })  : mobile = const SizedBox.shrink(),
        tablet = null,
        desktop = null;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenType = screenWidth < AppBreakpoints.mobileMax
            ? ScreenType.mobile
            : (screenWidth < AppBreakpoints.tabletMax
                ? ScreenType.tablet
                : ScreenType.desktop);

        if (builder != null) {
          return builder!(context, constraints, screenType);
        }

        switch (screenType) {
          case ScreenType.desktop:
            return desktop ?? tablet ?? mobile;
          case ScreenType.tablet:
            return tablet ?? mobile;
          case ScreenType.mobile:
            return mobile;
        }
      },
    );
  }
}

/// Widget căn giữa nội dung với maxWidth hợp lý trên màn hình lớn
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.desktopContentMaxWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  const ResponsiveContainer.form({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.formContentMaxWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}
