// ==============================================================================
// CORE CONFIGURATION: lib/core/config/supabase_config.dart
// Lưu trữ Project URL và Publishable Key của dự án Supabase EduVault
// Tự động sử dụng giá trị cấu hình trực tiếp khi chạy `flutter run` thông thường
// ==============================================================================

class SupabaseConfig {
  SupabaseConfig._();

  /// Supabase Project URL của dự án DocuShare
  static const String projectUrl = 'https://hujyhsdgpateydlrkhjy.supabase.co';

  /// Supabase Publishable Key (công khai / anon)
  /// Tuyệt đối KHÔNG sử dụng secret key (service_role) tại đây
  static const String publishableKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1anloc2RncGF0ZXlkbHJraGp5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI3NDYyNTUsImV4cCI6MjEwODMyMjI1NX0.GsGtnWdsQmkF_2WOwe2NCXb1LGUMb2gmpYoyBT-HkJY';

  /// URL sử dụng thực tế (ưu tiên --dart-define nếu có, fallback về projectUrl)
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: projectUrl,
  );

  /// Key sử dụng thực tế (ưu tiên --dart-define nếu có, fallback về publishableKey)
  static const String effectivePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: publishableKey,
  );

  /// Alias tương thích ngược
  static String get anonKey => effectivePublishableKey;

  /// Kiểm tra tính hợp lệ của cấu hình
  static bool get isConfigured =>
      url.trim().isNotEmpty &&
      url.startsWith('https://') &&
      effectivePublishableKey.trim().isNotEmpty;
}
