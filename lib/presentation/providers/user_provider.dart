// ==============================================================================
// PRESENTATION PROVIDER: user_provider.dart
// Quản lý trạng thái hồ sơ người dùng Supabase và kiểm chứng RLS
// Sử dụng Provider pattern chuẩn mực
// ==============================================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../core/firebase/firebase_service.dart';
import '../../core/supabase/supabase_service.dart';
import '../../domain/models/user_profile_model.dart';
import '../../domain/repositories/user_repository.dart';

class UserProvider extends ChangeNotifier {
  UserProvider({required UserRepository userRepo})
      : _userRepository = userRepo;

  final UserRepository _userRepository;

  UserProfileModel? _profile;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isRlsVerified = false;

  // Quản lý trạng thái Custom Claim role = 'authenticated'
  bool _isClaimVerified = false;
  bool _isAssigningClaim = false;
  String? _claimError;

  UserProfileModel? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isRlsVerified => _isRlsVerified;

  bool get isClaimVerified => _isClaimVerified;
  bool get isAssigningClaim => _isAssigningClaim;
  String? get claimError => _claimError;

  bool get isSupabaseConfigured => SupabaseService.instance.isAvailable;
  String? get supabaseInitError => SupabaseService.instance.initializationError;

  /// Gọi khi phát hiện người dùng đã đăng nhập Google qua Firebase
  /// Thực hiện:
  /// 1. Tự động kiểm tra và gán Firebase Custom Claim role = 'authenticated' qua Cloud Function
  /// 2. Đồng bộ (upsert) người dùng vào `public.users` trên Supabase (chỉ khi có claim)
  /// 3. Đọc lại bản ghi bằng SELECT query để kiểm chứng JWT và RLS
  Future<void> onUserAuthenticated(User firebaseUser, {bool force = false}) async {
    // Tránh gọi lặp lại nếu đang trong quá trình đồng bộ
    if (_isLoading || _isAssigningClaim) {
      debugPrint('[UserProvider] Đang trong quá trình xử lý, bỏ qua yêu cầu trùng.');
      return;
    }

    // Nếu đã đồng bộ và xác thực thành công cho user này, không cần gọi lại trừ khi force = true
    if (!force && _profile != null && _isRlsVerified && _isClaimVerified && _profile!.firebaseUid == firebaseUser.uid) {
      debugPrint('[UserProvider] Hồ sơ người dùng đã được đồng bộ và xác thực RLS trước đó: ${_profile!.email}');
      return;
    }

    if (!SupabaseService.instance.isAvailable) {
      _errorMessage = SupabaseService.instance.initializationError ?? 'Supabase chưa sẵn sàng.';
      debugPrint('[UserProvider] $errorMessage');
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (force) {
        debugPrint('[UserProvider] Force sync: Làm mới phiên đăng nhập và ép buộc lấy Firebase ID Token mới nhất...');
        try {
          await firebaseUser.reload();
          await firebaseUser.getIdToken(true);
        } catch (reloadErr) {
          debugPrint('[UserProvider] Lưu ý: Không thể reload user từ Firebase: $reloadErr');
        }
      }

      // ========================================================================
      // BƯỚC 1: XÁC MINH VÀ GÁN CUSTOM CLAIM ROLE = 'AUTHENTICATED' QUA CLOUD FUNCTION
      // ========================================================================
      try {
        // Luôn gọi getIdTokenResult(true) trước để lấy token mới nhất từ Firebase server
        final tokenResult = await firebaseUser.getIdTokenResult(true);
        final currentRole = tokenResult.claims?['role'];

        if (currentRole == 'authenticated') {
          debugPrint('[UserProvider] Xác nhận tài khoản ${firebaseUser.email} ĐÃ CÓ claim role = authenticated qua getIdTokenResult(true). Bỏ qua Cloud Function và tiếp tục đồng bộ Supabase.');
          _isClaimVerified = true;
          _claimError = null;
          _isAssigningClaim = false;
        } else {
          // Chưa có claim: Bắt đầu gọi Cloud Function assignUserRole
          debugPrint('[UserProvider] Tài khoản chưa có role = authenticated (hiện tại: $currentRole). Đang gọi Cloud Function...');
          _isAssigningClaim = true;
          _claimError = null;
          notifyListeners();

          final success = await FirebaseService.instance.assignUserClaimViaFunction(firebaseUser);
          if (!success) {
            throw StateError('Cloud Function phản hồi không thành công.');
          }

          _isClaimVerified = true;
          _claimError = null;
          _isAssigningClaim = false;
        }
      } catch (claimErr) {
        debugPrint('[UserProvider] Lỗi khi kiểm tra hoặc gọi Cloud Function: $claimErr');
        _claimError = 'Tài khoản chưa được gán role = authenticated trên Firebase. '
            'Cloud Function assignUserRole hiện chưa sẵn sàng hoặc chưa được deploy. '
            'Chi tiết: $claimErr';
        _isClaimVerified = false;
        _isAssigningClaim = false;
        _isLoading = false;
        _errorMessage = _claimError;
        notifyListeners();
        // Giữ nguyên phiên Google Sign-In (không đăng xuất)
        // Dừng lại tại đây, không tiếp tục truy vấn Supabase bằng token chưa hợp lệ
        return;
      }

      // ========================================================================
      // BƯỚC 2: ĐỒNG BỘ PUBLIC.USERS VÀ KIỂM CHỨNG RLS TRÊN SUPABASE DATABASE
      // (Chỉ thực thi sau khi bước 1 đã xác nhận role = 'authenticated')
      // ========================================================================
      debugPrint('[UserProvider] Bắt đầu gọi UserRepository.syncUser...');
      final syncedProfile = await _userRepository.syncUser(
        firebaseUid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName,
        photoUrl: firebaseUser.photoURL,
      );

      debugPrint('[UserProvider] Đang kiểm chứng quyền đọc RLS...');
      final verified = await _userRepository.verifyRlsAccess(
        firebaseUid: firebaseUser.uid,
      );

      _profile = syncedProfile;
      _isRlsVerified = verified;
      _errorMessage = null;
      debugPrint('[UserProvider] Hoàn thành đồng bộ: User ID = ${syncedProfile.id}, RLS Verified = $verified');
    } on PostgrestException catch (pgError) {
      _errorMessage = 'Supabase Lỗi [${pgError.code}]: ${pgError.message}${pgError.hint != null ? ' (Gợi ý: ${pgError.hint})' : ''}';
      debugPrint('[UserProvider] $_errorMessage');
    } catch (e) {
      _errorMessage = 'Không thể đồng bộ hồ sơ sang Supabase: $e';
      debugPrint('[UserProvider] Lỗi: $_errorMessage');
    } finally {
      _isLoading = false;
      _isAssigningClaim = false;
      notifyListeners();
    }
  }

  /// Làm mới hồ sơ người dùng từ Supabase
  Future<void> refreshProfile(String firebaseUid) async {
    if (!SupabaseService.instance.isAvailable) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Thực hiện sync lại để đảm bảo token và dữ liệu mới nhất
        await onUserAuthenticated(user, force: true);
        return;
      }

      _profile = await _userRepository.getCurrentUserProfile(firebaseUid: firebaseUid);
      _isRlsVerified = _profile != null;
      _errorMessage = null;
    } on PostgrestException catch (pgError) {
      _errorMessage = 'Supabase [${pgError.code}]: ${pgError.message}';
    } catch (e) {
      _errorMessage = 'Lỗi làm mới hồ sơ: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Dọn dẹp trạng thái khi người dùng đăng xuất
  void onUserSignedOut() {
    _profile = null;
    _isRlsVerified = false;
    _isClaimVerified = false;
    _isAssigningClaim = false;
    _claimError = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}
