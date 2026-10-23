import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cấu hình khởi tạo Supabase cho DocuShare (Database + Storage)
///
/// !!! VIỆC CẦN LÀM CỦA NHÓM !!!
/// 1. Tạo project trên supabase.com (region Singapore).
/// 2. Chạy file `supabase/schema.sql` trong SQL Editor.
/// 3. Lấy Project URL + anon key tại Project Settings -> API
///    rồi điền vào 2 hằng bên dưới.
///
/// LƯU Ý BẢO MẬT: anon key là khóa phía client (được phép công khai khi đã
/// bật RLS), KHÔNG dùng service_role key trong app.
class SupabaseConfig {
  SupabaseConfig._();

  // TODO(nhóm): điền thông tin project Supabase của nhóm vào đây.
  static const String supabaseUrl = 'https://bpsdjofwpvyyjhmgedey.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwc2Rqb2Z3cHZ5eWpobWdlZGV5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI3MTc5NzksImV4cCI6MjEwODI5Mzk3OX0.VJuU_Q1GJ67fUQPTj8UTPDtEfuykuaIvVB1W2atjADQ';

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static bool get isConfigured =>
      !supabaseUrl.contains('YOUR-PROJECT') &&
      !supabaseAnonKey.contains('YOUR-ANON-KEY');

  /// Khởi tạo Supabase (không chặn app nếu chưa cấu hình - chỉ log cảnh báo)
  static Future<void> initialize() async {
    try {
      if (!isConfigured) {
        debugPrint(
            '⚠️ [SupabaseConfig] Chưa điền URL/anon key - module Documents/Tagging sẽ báo lỗi kết nối.');
        return;
      }
      await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
      _isInitialized = true;
      debugPrint('✅ [SupabaseConfig] Supabase đã kết nối: $supabaseUrl');
    } catch (e) {
      debugPrint('❌ [SupabaseConfig] Lỗi khởi tạo Supabase: $e');
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}
