import 'user_permission.dart';
import 'user_role.dart';

/// Mô hình thông tin người dùng hoàn chỉnh trong hệ thống DocuShare
class UserModel {
  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final String code; // Mã SV / Mã GV / Mã Cán bộ
  final String faculty; // Khoa / Bộ môn / Viện
  final String? major; // Chuyên ngành
  final String? cohort; // Lớp / Khóa học
  final String? phone;
  final String? avatarUrl;
  final String? bio;
  final DateTime joinedDate;
  final bool isActive;
  final bool isEmailVerified;
  final bool isTwoFactorEnabled;

  // Thống kê cá nhân
  final int uploadedCount;
  final int borrowingCount;
  final int savedCount;
  final int reputationScore; // Điểm tín nhiệm mượn trả (0 - 100)

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.code,
    required this.faculty,
    this.major,
    this.cohort,
    this.phone,
    this.avatarUrl,
    this.bio,
    required this.joinedDate,
    this.isActive = true,
    this.isEmailVerified = true,
    this.isTwoFactorEnabled = false,
    this.uploadedCount = 0,
    this.borrowingCount = 0,
    this.savedCount = 0,
    this.reputationScore = 100,
  });

  /// Kiểm tra xem người dùng có quyền cụ thể không
  bool hasPermission(UserPermission permission) {
    if (!isActive) return false;
    return role.hasPermission(permission);
  }

  /// Lấy 2 chữ cái viết tắt của họ tên làm avatar mặc định
  String get initials {
    final words = fullName.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return 'U';
    if (words.length == 1) {
      return words.first.substring(0, words.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    UserRole? role,
    String? code,
    String? faculty,
    String? major,
    String? cohort,
    String? phone,
    String? avatarUrl,
    String? bio,
    DateTime? joinedDate,
    bool? isActive,
    bool? isEmailVerified,
    bool? isTwoFactorEnabled,
    int? uploadedCount,
    int? borrowingCount,
    int? savedCount,
    int? reputationScore,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      code: code ?? this.code,
      faculty: faculty ?? this.faculty,
      major: major ?? this.major,
      cohort: cohort ?? this.cohort,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      joinedDate: joinedDate ?? this.joinedDate,
      isActive: isActive ?? this.isActive,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isTwoFactorEnabled: isTwoFactorEnabled ?? this.isTwoFactorEnabled,
      uploadedCount: uploadedCount ?? this.uploadedCount,
      borrowingCount: borrowingCount ?? this.borrowingCount,
      savedCount: savedCount ?? this.savedCount,
      reputationScore: reputationScore ?? this.reputationScore,
    );
  }
}
