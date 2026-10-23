// ==============================================================================
// DATA REPOSITORY IMPLEMENTATION: user_repository_impl.dart
// Triển khai giao tiếp với Supabase PostgREST Client cho thực thể người dùng
// Tuân thủ Clean Architecture và cơ chế bảo mật Supabase RLS
// ==============================================================================

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_service.dart';
import '../../domain/models/user_profile_model.dart';
import '../../domain/repositories/user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl({SupabaseService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseService.instance;

  final SupabaseService _supabaseService;

  @override
  Future<UserProfileModel?> getCurrentUserProfile({
    required String firebaseUid,
  }) async {
    final client = _supabaseService.client;
    if (client == null) {
      debugPrint('[UserRepositoryImpl] Không thể đọc hồ sơ: Supabase client chưa sẵn sàng.');
      return null;
    }

    try {
      debugPrint('[UserRepositoryImpl] Đang truy vấn SELECT hồ sơ người dùng (firebase_uid=$firebaseUid)...');
      final response = await client
          .from('users')
          .select()
          .eq('firebase_uid', firebaseUid)
          .maybeSingle();

      if (response == null) {
        debugPrint('[UserRepositoryImpl] Chưa tìm thấy hồ sơ người dùng trên Supabase cho UID: $firebaseUid');
        return null;
      }

      final profile = UserProfileModel.fromJson(response);
      debugPrint('[UserRepositoryImpl] Tải hồ sơ Supabase thành công: ${profile.email} (ID: ${profile.id})');
      return profile;
    } on PostgrestException catch (pgError) {
      debugPrint(
        '[UserRepositoryImpl] LỖI POSTGREST KHI ĐỌC HỒ SƠ: '
        'code=${pgError.code}, message=${pgError.message}, hint=${pgError.hint}',
      );
      rethrow;
    } catch (e) {
      debugPrint('[UserRepositoryImpl] Lỗi khi đọc hồ sơ từ Supabase: $e');
      rethrow;
    }
  }

  @override
  Future<UserProfileModel> syncUser({
    required String firebaseUid,
    required String email,
    String? displayName,
    String? photoUrl,
  }) async {
    // Chuyển tiếp tới SupabaseService với đầy đủ log kiểm chứng
    return await _supabaseService.syncUser(
      firebaseUid: firebaseUid,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
    );
  }

  @override
  Future<bool> verifyRlsAccess({required String firebaseUid}) async {
    final client = _supabaseService.client;
    if (client == null) {
      debugPrint('[UserRepositoryImpl] Kiểm tra RLS: Thất bại vì Supabase client là null.');
      return false;
    }

    try {
      final response = await client
          .from('users')
          .select('id, firebase_uid, email')
          .eq('firebase_uid', firebaseUid)
          .maybeSingle();

      final isSuccess = response != null && response['firebase_uid'] == firebaseUid;
      debugPrint(
        '[UserRepositoryImpl] Kiểm tra RLS & Third-Party Auth: '
        '${isSuccess ? 'THÀNH CÔNG (Đọc được bản ghi với JWT hiện tại)' : 'THẤT BẠI (Bản ghi rỗng)'}',
      );
      return isSuccess;
    } on PostgrestException catch (pgError) {
      debugPrint(
        '[UserRepositoryImpl] LỖI POSTGREST KHI KIỂM TRA RLS: '
        'code=${pgError.code}, message=${pgError.message}',
      );
      return false;
    } catch (e) {
      debugPrint('[UserRepositoryImpl] Kiểm tra RLS thất bại với lỗi: $e');
      return false;
    }
  }
}
