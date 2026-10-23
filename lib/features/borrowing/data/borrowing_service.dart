import 'package:supabase_flutter/supabase_flutter.dart';

/// Service quản lý dữ liệu mượn - trả tài liệu.
class BorrowingService {
  BorrowingService._();

  static final BorrowingService instance = BorrowingService._();

  SupabaseClient get _db => Supabase.instance.client;

  /// Lấy danh sách tài liệu để người dùng chọn khi mượn.
  Future<List<Map<String, dynamic>>> fetchDocuments() async {
    final rows = await _db
        .from('Documents')
        .select('id, title, author')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows);
  }
}
