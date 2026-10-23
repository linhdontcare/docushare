// ==============================================================================
// DOMAIN MODEL: user_profile_model.dart
// Đại diện cho thực thể người dùng trong cơ sở dữ liệu Supabase (public.users)
// ==============================================================================

class UserProfileModel {
  const UserProfileModel({
    required this.id,
    required this.firebaseUid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.createdAt,
    this.updatedAt,
  });

  /// Khóa chính UUID sinh bởi Supabase gen_random_uuid()
  final String id;

  /// Firebase Authentication UID tương ứng
  final String firebaseUid;

  /// Email đã xác thực từ Google/Firebase
  final String email;

  /// Tên hiển thị của người dùng
  final String? displayName;

  /// URL ảnh đại diện Google
  final String? photoUrl;

  /// Thời gian tạo bản ghi trong Supabase
  final DateTime? createdAt;

  /// Thời gian cập nhật gần nhất trong Supabase
  final DateTime? updatedAt;

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as String? ?? '',
      firebaseUid: json['firebase_uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['display_name'] as String?,
      photoUrl: json['photo_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firebase_uid': firebaseUid,
      'email': email,
      'display_name': displayName,
      'photo_url': photoUrl,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  UserProfileModel copyWith({
    String? id,
    String? firebaseUid,
    String? email,
    String? displayName,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          firebaseUid == other.firebaseUid &&
          email == other.email;

  @override
  int get hashCode => id.hashCode ^ firebaseUid.hashCode ^ email.hashCode;

  @override
  String toString() {
    return 'UserProfileModel(id: $id, firebaseUid: $firebaseUid, email: $email, displayName: $displayName)';
  }
}
