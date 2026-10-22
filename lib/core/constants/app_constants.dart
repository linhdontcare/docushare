/// Các hằng số cấu hình toàn cục cho DocuShare
class AppConstants {
  AppConstants._();

  // Breakpoints responsive (Android vs Web/Desktop)
  static const double mobileBreakpoint = 650.0;
  static const double tabletBreakpoint = 1024.0;

  // Spacing & Paddings
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;

  // Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 14.0;
  static const double radiusLarge = 20.0;
  static const double radiusCircular = 999.0;

  // Animation durations
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animNormal = Duration(milliseconds: 300);
}
