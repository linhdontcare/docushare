import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../domain/models/activity_log.dart';
import '../domain/models/user_model.dart';
import '../domain/models/user_role.dart';

/// Dịch vụ Xác thực Firebase Authentication & Phân quyền RBAC qua Cloud Firestore
class FirebaseAuthService {
  static final FirebaseAuthService instance = FirebaseAuthService._internal();

  FirebaseAuthService._internal();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference get _usersCol => _firestore.collection('users');

  User? get currentFirebaseUser => Firebase.apps.isNotEmpty ? _auth.currentUser : null;

  /// Stream theo dõi phiên đăng nhập của người dùng qua Firebase Auth
  Stream<User?> get authStateChanges =>
      Firebase.apps.isNotEmpty ? _auth.authStateChanges() : const Stream.empty();

  /// Lấy thông tin hồ sơ và vai trò RBAC từ Cloud Firestore
  Future<UserModel?> fetchUserProfile(String uid) async {
    try {
      final doc = await _usersCol.doc(uid).get();
      if (!doc.exists) {
        // Nếu user đã xác thực qua Firebase Auth nhưng chưa có record trong Firestore
        final fbUser = _auth.currentUser;
        if (fbUser != null && fbUser.uid == uid) {
          final defaultUser = UserModel(
            id: uid,
            email: fbUser.email ?? 'user@docushare.edu.vn',
            fullName: fbUser.displayName ?? 'Sinh viên DocuShare',
            role: UserRole.student,
            code: 'SV-${uid.substring(0, 6).toUpperCase()}',
            faculty: 'Khoa Công nghệ Thông tin',
            joinedDate: DateTime.now(),
          );
          await saveUserProfile(defaultUser);
          return defaultUser;
        }
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;
      return _mapFirestoreToUserModel(uid, data);
    } catch (e) {
      debugPrint('❌ [FirebaseAuthService] Lỗi fetchUserProfile: $e');
      return null;
    }
  }

  /// Lắng nghe thay đổi hồ sơ và vai trò (Role) theo thời gian thực từ Cloud Firestore
  Stream<UserModel?> getUserStream(String uid) {
    if (Firebase.apps.isEmpty) return const Stream.empty();
    return _usersCol.doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return _mapFirestoreToUserModel(uid, doc.data() as Map<String, dynamic>);
    });
  }

  /// Lắng nghe danh sách toàn bộ người dùng trong hệ thống (Dành riêng cho Quản trị viên)
  Stream<List<UserModel>> getAllUsersStream() {
    if (Firebase.apps.isEmpty) return const Stream.empty();
    return _usersCol.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return _mapFirestoreToUserModel(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  /// Cập nhật vai trò (Role) của người dùng bởi Quản trị viên
  Future<void> updateUserRole({
    required String targetUserId,
    required UserRole newRole,
    required String adminId,
    required String adminName,
  }) async {
    try {
      await _usersCol.doc(targetUserId).update({
        'role': newRole.code,
      });

      // Ghi nhật ký kiểm toán cho cả người dùng và quản trị viên
      await recordActivity(
        uid: targetUserId,
        title: 'Cập nhật phân quyền',
        description: 'Quản trị viên $adminName đã gán vai trò của bạn thành ${newRole.name}',
        icon: Icons.admin_panel_settings,
      );

      await recordActivity(
        uid: adminId,
        title: 'Phân quyền người dùng',
        description: 'Đã phân quyền ${newRole.name} cho tài khoản ID: $targetUserId',
        icon: Icons.manage_accounts,
      );
    } catch (e) {
      debugPrint('❌ [FirebaseAuthService] Lỗi updateUserRole: $e');
      rethrow;
    }
  }

  /// Khóa hoặc mở khóa tài khoản người dùng bởi Quản trị viên
  Future<void> toggleUserActiveStatus({
    required String targetUserId,
    required bool isActive,
    required String adminId,
  }) async {
    try {
      await _usersCol.doc(targetUserId).update({
        'isActive': isActive,
      });

      await recordActivity(
        uid: adminId,
        title: isActive ? 'Mở khóa tài khoản' : 'Khóa tài khoản',
        description: 'Đã ${isActive ? "mở khóa" : "khóa"} tài khoản ID: $targetUserId',
        icon: isActive ? Icons.lock_open : Icons.lock,
      );
    } catch (e) {
      debugPrint('❌ [FirebaseAuthService] Lỗi toggleUserActiveStatus: $e');
      rethrow;
    }
  }

  /// Đăng nhập bằng Email & Mật khẩu với Firebase Authentication
  Future<UserModel> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Không tìm thấy người dùng.',
        );
      }

      final profile = await fetchUserProfile(user.uid);
      if (profile == null) {
        throw Exception('Không thể tải dữ liệu hồ sơ phân quyền từ Firestore.');
      }

      // Ghi nhật ký bảo mật vào Cloud Firestore
      await recordActivity(
        uid: user.uid,
        title: 'Đăng nhập Firebase thành công',
        description: 'Đăng nhập vào DocuShare bằng Firebase Authentication',
        icon: Icons.login,
      );

      return profile;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [FirebaseAuthService] Lỗi đăng nhập: ${e.code} - ${e.message}');
      throw _getFriendlyAuthErrorMessage(e);
    }
  }

  /// Đăng nhập bằng Google Sign-In (Hỗ trợ cả Web qua Popup và Android qua GoogleSignIn SDK)
  Future<UserModel> signInWithGoogle() async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        // Nền tảng Web: Mở popup xác thực Google của Firebase SDK
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        // Nền tảng Android/iOS: Dùng google_sign_in 7.x singleton API
        await GoogleSignIn.instance.initialize();
        final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate();

        final GoogleSignInAuthentication googleAuth = googleUser.authentication;
        if (googleAuth.idToken == null) {
          throw Exception('Không tìm thấy Google ID Token để xác thực với Firebase.');
        }

        final OAuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        userCredential = await _auth.signInWithCredential(credential);
      }

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Đăng nhập Google không thành công.');
      }

      // Lấy hoặc khởi tạo hồ sơ phân quyền trên Cloud Firestore
      UserModel? profile = await fetchUserProfile(user.uid);
      if (profile == null) {
        // Tự động phân quyền: Nếu email chứa từ 'admin' hoặc 'gv' thì gán vai trò tương ứng, mặc định là Sinh viên
        final emailLower = (user.email ?? '').toLowerCase();
        final assignedRole = emailLower.contains('admin')
            ? UserRole.admin
            : (emailLower.contains('gv') || emailLower.contains('lecturer')
                ? UserRole.lecturer
                : UserRole.student);

        profile = UserModel(
          id: user.uid,
          email: user.email ?? 'google_user@docushare.edu.vn',
          fullName: user.displayName ?? 'Sinh viên Google',
          role: assignedRole,
          code: 'GG-${user.uid.substring(0, 6).toUpperCase()}',
          faculty: 'Khoa Công nghệ Thông tin',
          avatarUrl: user.photoURL,
          joinedDate: DateTime.now(),
          isActive: true,
          isEmailVerified: true,
        );

        await saveUserProfile(profile);
      }

      // Ghi nhật ký hoạt động
      await recordActivity(
        uid: user.uid,
        title: 'Đăng nhập Google thành công',
        description: 'Đăng nhập vào hệ thống qua tài khoản Google: ${user.email}',
        icon: Icons.account_circle,
      );

      return profile;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [FirebaseAuthService] Lỗi Google Sign-In: ${e.code} - ${e.message}');
      throw _getFriendlyAuthErrorMessage(e);
    } catch (e) {
      debugPrint('❌ [FirebaseAuthService] Lỗi Google Sign-In ngoại lệ: $e');
      rethrow;
    }
  }

  /// Đăng ký tài khoản mới lên Firebase Authentication và lưu vai trò vào Firestore
  Future<UserModel> signUpWithEmailPassword({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    required String code,
    required String faculty,
    String? major,
    String? phone,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Đăng ký tài khoản Firebase thất bại.');
      }

      // Cập nhật tên hiển thị lên Firebase Auth
      await user.updateDisplayName(fullName.trim());

      final newUserModel = UserModel(
        id: user.uid,
        email: email.trim(),
        fullName: fullName.trim(),
        role: role,
        code: code.trim(),
        faculty: faculty.trim(),
        major: major?.trim(),
        phone: phone?.trim(),
        joinedDate: DateTime.now(),
        isActive: true,
        isEmailVerified: user.emailVerified,
      );

      // Lưu hồ sơ và phân quyền vào Cloud Firestore
      await saveUserProfile(newUserModel);

      // Ghi nhật ký hoạt động
      await recordActivity(
        uid: user.uid,
        title: 'Đăng ký tài khoản thành công',
        description: 'Tạo tài khoản mới trên Firebase Auth với vai trò: ${role.name}',
        icon: Icons.person_add_alt_1,
      );

      return newUserModel;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [FirebaseAuthService] Lỗi đăng ký: ${e.code} - ${e.message}');
      throw _getFriendlyAuthErrorMessage(e);
    }
  }

  /// Đăng xuất khỏi Firebase Auth
  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await recordActivity(
        uid: uid,
        title: 'Đăng xuất tài khoản',
        description: 'Kết thúc phiên làm việc trên Firebase Authentication',
        icon: Icons.logout,
      );
    }
    await _auth.signOut();
  }

  /// Gửi email khôi phục mật khẩu qua Firebase Auth
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _getFriendlyAuthErrorMessage(e);
    }
  }

  /// Đổi mật khẩu tài khoản hiện tại trên Firebase Auth
  Future<void> updatePassword(String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Người dùng chưa đăng nhập.');
      await user.updatePassword(newPassword);

      await recordActivity(
        uid: user.uid,
        title: 'Đổi mật khẩu',
        description: 'Mật khẩu đã được thay đổi trên Firebase Authentication',
        icon: Icons.password,
      );
    } on FirebaseAuthException catch (e) {
      throw _getFriendlyAuthErrorMessage(e);
    }
  }

  /// Lưu hoặc cập nhật thông tin hồ sơ người dùng lên Cloud Firestore
  Future<void> saveUserProfile(UserModel user) async {
    await _usersCol.doc(user.id).set({
      'email': user.email,
      'fullName': user.fullName,
      'role': user.role.code, // ADMIN, LIBRARIAN, LECTURER, STUDENT
      'code': user.code,
      'faculty': user.faculty,
      'major': user.major,
      'cohort': user.cohort,
      'phone': user.phone,
      'bio': user.bio,
      'avatarUrl': user.avatarUrl,
      'joinedDate': Timestamp.fromDate(user.joinedDate),
      'isActive': user.isActive,
      'isEmailVerified': user.isEmailVerified,
      'isTwoFactorEnabled': user.isTwoFactorEnabled,
      'uploadedCount': user.uploadedCount,
      'borrowingCount': user.borrowingCount,
      'savedCount': user.savedCount,
      'reputationScore': user.reputationScore,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Ghi nhật ký kiểm toán hoạt động vào Firestore
  Future<void> recordActivity({
    required String uid,
    required String title,
    required String description,
    required IconData icon,
  }) async {
    try {
      await _usersCol.doc(uid).collection('activities').add({
        'title': title,
        'description': description,
        'iconCodePoint': icon.codePoint,
        'iconFontFamily': icon.fontFamily,
        'timestamp': FieldValue.serverTimestamp(),
        'device': 'DocuShare App Client',
      });
    } catch (e) {
      debugPrint('⚠️ [FirebaseAuthService] Không thể ghi nhật ký Firestore: $e');
    }
  }

  /// Stream lấy danh sách nhật ký hoạt động thời gian thực từ Firestore
  Stream<List<UserActivity>> getActivitiesStream(String uid) {
    return _usersCol
        .doc(uid)
        .collection('activities')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final ts = data['timestamp'] as Timestamp?;
        final codePoint = data['iconCodePoint'] as int?;

        return UserActivity(
          id: doc.id,
          title: data['title'] ?? 'Hoạt động',
          description: data['description'] ?? '',
          timestamp: ts?.toDate() ?? DateTime.now(),
          icon: _getIcon(codePoint),
          device: data['device'],
        );
      }).toList();
    });
  }

  UserModel _mapFirestoreToUserModel(String uid, Map<String, dynamic> data) {
    final roleCode = data['role'] as String? ?? 'STUDENT';
    final role = UserRole.values.firstWhere(
      (r) => r.code == roleCode,
      orElse: () => UserRole.student,
    );

    final ts = data['joinedDate'] as Timestamp?;

    return UserModel(
      id: uid,
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      role: role,
      code: data['code'] ?? '',
      faculty: data['faculty'] ?? '',
      major: data['major'],
      cohort: data['cohort'],
      phone: data['phone'],
      bio: data['bio'],
      avatarUrl: data['avatarUrl'],
      joinedDate: ts?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
      isEmailVerified: data['isEmailVerified'] ?? false,
      isTwoFactorEnabled: data['isTwoFactorEnabled'] ?? false,
      uploadedCount: data['uploadedCount'] ?? 0,
      borrowingCount: data['borrowingCount'] ?? 0,
      savedCount: data['savedCount'] ?? 0,
      reputationScore: data['reputationScore'] ?? 100,
    );
  }

  String _getFriendlyAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Không tìm thấy tài khoản với email này.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Mật khẩu hoặc thông tin đăng nhập không chính xác.';
      case 'email-already-in-use':
        return 'Email này đã được đăng ký bởi tài khoản khác.';
      case 'invalid-email':
        return 'Địa chỉ email không đúng định dạng.';
      case 'weak-password':
        return 'Mật khẩu quá yếu. Vui lòng chọn mật khẩu từ 6 ký tự trở lên.';
      case 'network-request-failed':
        return 'Lỗi kết nối mạng đến máy chủ Firebase. Vui lòng kiểm tra lại Internet.';
      case 'too-many-requests':
        return 'Tài khoản tạm thời bị chặn do thử đăng nhập sai nhiều lần. Vui lòng thử lại sau.';
      case 'operation-not-allowed':
        return 'Phương thức đăng nhập này chưa được kích hoạt trong Firebase Console (Authentication > Sign-in method).';
      case 'popup-closed-by-user':
        return 'Bạn đã đóng cửa sổ đăng nhập Google trước khi hoàn tất.';
      case 'cancelled-popup-request':
        return 'Yêu cầu mở cửa sổ đăng nhập đã bị hủy.';
      case 'account-exists-with-different-credential':
        return 'Email này đã tồn tại với phương thức đăng nhập khác.';
      default:
        return e.message ?? 'Đã xảy ra lỗi xác thực Firebase.';
    }
  }

  IconData _getIcon(int? codePoint) {
    if (codePoint == Icons.login.codePoint) return Icons.login;
    if (codePoint == Icons.logout.codePoint) return Icons.logout;
    if (codePoint == Icons.password.codePoint) return Icons.password;
    if (codePoint == Icons.person_add_alt_1.codePoint) return Icons.person_add_alt_1;
    if (codePoint == Icons.admin_panel_settings.codePoint) return Icons.admin_panel_settings;
    if (codePoint == Icons.badge_outlined.codePoint) return Icons.badge_outlined;
    if (codePoint == Icons.security.codePoint) return Icons.security;
    return Icons.notifications_active_outlined;
  }
}
