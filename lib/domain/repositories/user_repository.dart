// ==============================================================================
// DOMAIN REPOSITORY INTERFACE: user_repository.dart
// Định nghĩa các hợp đồng truy xuất và đồng bộ dữ liệu người dùng với Supabase
// theo chuẩn Clean Architecture
// ==============================================================================

import '../models/user_profile_model.dart';

abstract class UserRepository {
  /// Đọc hồ sơ của người dùng hiện tại từ bảng `public.users` trong Supabase
  /// dựa trên Firebase UID và JWT Token. Trả về null nếu chưa tồn tại.
  Future<UserProfileModel?> getCurrentUserProfile({required String firebaseUid});

  /// Đồng bộ (upsert) thông tin người dùng từ Firebase Authentication vào `public.users`.
  /// Sau khi upsert thành công, trả về bản ghi UserProfileModel đầy đủ (bao gồm id UUID).
  Future<UserProfileModel> syncUser({
    required String firebaseUid,
    required String email,
    String? displayName,
    String? photoUrl,
  });

  /// Kiểm tra xác thực Supabase JWT và phân quyền RLS.
  /// Gửi truy vấn SELECT tới `public.users` để xác nhận RLS đang hoạt động chuẩn xác.
  Future<bool> verifyRlsAccess({required String firebaseUid});
}
