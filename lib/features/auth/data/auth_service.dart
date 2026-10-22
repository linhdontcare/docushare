import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../../shared/services/firebase_notification_service.dart';
import '../domain/models/activity_log.dart';
import '../domain/models/user_model.dart';
import '../domain/models/user_role.dart';
import 'firebase_auth_service.dart';

/// Dịch vụ quản lý xác thực và phân quyền tài khoản kết nối Firebase thực tế
class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._internal();

  AuthService._internal() {
    if (!_isFirebaseActive) {
      _currentUser = _createFallbackUser('admin@docushare.edu.vn', UserRole.admin);
    }
    _initFirebaseAuthListener();
  }

  final FirebaseAuthService _firebaseAuth = FirebaseAuthService.instance;

  UserModel? _currentUser;
  bool _isLoading = false;
  final List<UserActivity> _activityLogs = [];
  StreamSubscription? _activitySubscription;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  UserRole? get currentRole => _currentUser?.role;
  bool get isLoading => _isLoading;
  List<UserActivity> get activityLogs => List.unmodifiable(_activityLogs);

  bool get _isFirebaseActive => Firebase.apps.isNotEmpty;

  /// Lắng nghe thay đổi trạng thái xác thực thời gian thực từ Firebase Auth
  void _initFirebaseAuthListener() {
    if (!_isFirebaseActive) return;

    try {
      _firebaseAuth.authStateChanges.listen((fbUser) async {
        if (fbUser == null) {
          _currentUser = null;
          _activitySubscription?.cancel();
          _activityLogs.clear();
          notifyListeners();
        } else {
          // Tải hồ sơ và phân quyền tương ứng từ Cloud Firestore
          final profile = await _firebaseAuth.fetchUserProfile(fbUser.uid);
          _currentUser = profile;

          if (profile != null) {
            // Đồng bộ topic nhận thông báo FCM theo vai trò
            await FirebaseNotificationService.instance.syncRoleTopics(
              newRole: profile.role,
            );

            // Lắng nghe nhật ký hoạt động thời gian thực từ Firestore
            _activitySubscription?.cancel();
            _activitySubscription = _firebaseAuth
                .getActivitiesStream(profile.id)
                .listen((activities) {
              _activityLogs.clear();
              _activityLogs.addAll(activities);
              notifyListeners();
            });
          }
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('ℹ️ [AuthService] Firebase Auth chưa sẵn sàng: $e');
    }
  }

  /// Đăng nhập tài khoản bằng Email & Mật khẩu với Firebase Authentication
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_isFirebaseActive) {
        final user = await _firebaseAuth.signInWithEmailPassword(
          email: email,
          password: password,
        );
        _currentUser = user;
      } else {
        // Fallback môi trường Unit Test
        _currentUser = _createFallbackUser(email, UserRole.admin);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Đăng nhập bằng tài khoản Google (Google Sign-In)
  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_isFirebaseActive) {
        final user = await _firebaseAuth.signInWithGoogle();
        _currentUser = user;
      } else {
        _currentUser = _createFallbackUser('google.user@docushare.edu.vn', UserRole.student);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Đăng ký tài khoản mới lên Firebase Authentication và Cloud Firestore
  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    required String code,
    required String faculty,
    String? major,
    String? phone,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_isFirebaseActive) {
        final user = await _firebaseAuth.signUpWithEmailPassword(
          fullName: fullName,
          email: email,
          password: password,
          role: role,
          code: code,
          faculty: faculty,
          major: major,
          phone: phone,
        );
        _currentUser = user;
      } else {
        // Fallback môi trường Unit Test
        _currentUser = UserModel(
          id: 'test_usr_${DateTime.now().millisecondsSinceEpoch}',
          email: email,
          fullName: fullName,
          role: role,
          code: code,
          faculty: faculty,
          major: major,
          phone: phone,
          joinedDate: DateTime.now(),
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Đăng xuất khỏi Firebase Authentication
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_isFirebaseActive) {
        await _firebaseAuth.signOut();
      }
      _currentUser = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Cập nhật thông tin hồ sơ cá nhân lên Cloud Firestore
  Future<bool> updateProfile({
    String? fullName,
    String? phone,
    String? faculty,
    String? major,
    String? cohort,
    String? bio,
    String? avatarUrl,
  }) async {
    if (_currentUser == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final updatedUser = _currentUser!.copyWith(
        fullName: fullName,
        phone: phone,
        faculty: faculty,
        major: major,
        cohort: cohort,
        bio: bio,
        avatarUrl: avatarUrl,
      );

      if (_isFirebaseActive) {
        await _firebaseAuth.saveUserProfile(updatedUser);
      }
      _currentUser = updatedUser;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Đổi mật khẩu tài khoản hiện tại trên Firebase Authentication
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_isFirebaseActive) {
        await _firebaseAuth.updatePassword(newPassword);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Gửi email khôi phục mật khẩu qua Firebase Authentication
  Future<bool> resetPassword(String email) async {
    try {
      if (_isFirebaseActive) {
        await _firebaseAuth.sendPasswordResetEmail(email);
      }
      return true;
    } catch (e) {
      rethrow;
    }
  }

  /// Đổi trạng thái 2FA và lưu lên Firestore
  Future<void> toggle2FA() async {
    if (_currentUser == null) return;

    final newState = !_currentUser!.isTwoFactorEnabled;
    final updated = _currentUser!.copyWith(isTwoFactorEnabled: newState);

    if (_isFirebaseActive) {
      await _firebaseAuth.saveUserProfile(updated);
    }
    _currentUser = updated;
    notifyListeners();
  }

  /// Stream danh sách người dùng cho Quản trị viên
  Stream<List<UserModel>> getAllUsersStream() {
    if (_isFirebaseActive) {
      return _firebaseAuth.getAllUsersStream();
    }
    // Fallback dữ liệu mẫu khi offline/test
    return Stream.value([
      _createFallbackUser('admin@docushare.edu.vn', UserRole.admin),
      _createFallbackUser('librarian@docushare.edu.vn', UserRole.librarian),
      _createFallbackUser('lecturer@docushare.edu.vn', UserRole.lecturer),
      _createFallbackUser('student@docushare.edu.vn', UserRole.student),
    ]);
  }

  /// Cập nhật vai trò (Role) của người dùng bởi Quản trị viên
  Future<bool> changeUserRoleByAdmin({
    required String targetUserId,
    required UserRole newRole,
  }) async {
    if (_currentUser?.role != UserRole.admin) {
      throw Exception('Bạn không có quyền quản trị viên để thực hiện thao tác này.');
    }

    _isLoading = true;
    notifyListeners();

    try {
      if (_isFirebaseActive) {
        await _firebaseAuth.updateUserRole(
          targetUserId: targetUserId,
          newRole: newRole,
          adminId: _currentUser!.id,
          adminName: _currentUser!.fullName,
        );
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Khóa hoặc mở khóa tài khoản người dùng bởi Quản trị viên
  Future<bool> toggleUserStatusByAdmin({
    required String targetUserId,
    required bool isActive,
  }) async {
    if (_currentUser?.role != UserRole.admin) {
      throw Exception('Bạn không có quyền quản trị viên để thực hiện thao tác này.');
    }

    _isLoading = true;
    notifyListeners();

    try {
      if (_isFirebaseActive) {
        await _firebaseAuth.toggleUserActiveStatus(
          targetUserId: targetUserId,
          isActive: isActive,
          adminId: _currentUser!.id,
        );
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Đăng nhập nhanh vai trò Demo trực tiếp với Firebase
  Future<void> quickLoginAs(UserRole role) async {
    final demoEmail = '${role.code.toLowerCase()}@docushare.edu.vn';
    const demoPassword = 'Password123!';

    if (_isFirebaseActive) {
      try {
        await login(email: demoEmail, password: demoPassword);
      } catch (_) {
        // Nếu tài khoản demo chưa tồn tại trên Firebase, tự động tạo mới tài khoản thật trên Firebase
        final roleNames = {
          UserRole.admin: 'Dương Quốc Vượng (Admin)',
          UserRole.librarian: 'Trần Thị Mai (Thủ thư)',
          UserRole.lecturer: 'TS. Nguyễn Văn Hùng (Giảng viên)',
          UserRole.student: 'Mã Khánh Linh (Sinh viên)',
        };

        await register(
          fullName: roleNames[role] ?? 'Người dùng Demo',
          email: demoEmail,
          password: demoPassword,
          role: role,
          code: '${role.code}-001',
          faculty: 'Khoa Công nghệ Thông tin',
        );
      }
    } else {
      _currentUser = _createFallbackUser(demoEmail, role);
      notifyListeners();
    }
  }

  UserModel _createFallbackUser(String email, UserRole role) {
    final roleNames = {
      UserRole.admin: 'Dương Quốc Vượng',
      UserRole.librarian: 'Trần Thị Mai',
      UserRole.lecturer: 'TS. Nguyễn Văn Hùng',
      UserRole.student: 'Mã Khánh Linh',
    };

    return UserModel(
      id: 'test_user_${role.code}',
      email: email,
      fullName: roleNames[role] ?? 'Người dùng DocuShare',
      role: role,
      code: '${role.code}-001',
      faculty: 'Khoa Công nghệ Thông tin',
      joinedDate: DateTime(2024, 1, 1),
    );
  }

  @override
  void dispose() {
    _activitySubscription?.cancel();
    super.dispose();
  }
}
