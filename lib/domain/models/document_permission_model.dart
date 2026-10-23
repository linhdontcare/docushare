// ==============================================================================
// DOMAIN MODEL: document_permission_model.dart
// Đại diện cho thực thể phân quyền tài liệu trong bảng public.permissions của Supabase
// Hỗ trợ hai loại quyền: 'viewer' (chỉ xem) và 'editor' (chỉnh sửa metadata)
// ==============================================================================

class DocumentPermissionModel {
  final String id;
  final String documentId;
  final String userId;
  final String permissionType; // 'viewer' | 'editor'
  final String? grantedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Thông tin mở rộng của người nhận (kết nối từ public.users)
  final String? userEmail;
  final String? userDisplayName;
  final String? userPhotoUrl;

  const DocumentPermissionModel({
    required this.id,
    required this.documentId,
    required this.userId,
    required this.permissionType,
    this.grantedBy,
    this.createdAt,
    this.updatedAt,
    this.userEmail,
    this.userDisplayName,
    this.userPhotoUrl,
  });

  /// Kiểm tra có phải quyền chỉ xem hay không
  bool get isViewer => permissionType.toLowerCase() == 'viewer';

  /// Kiểm tra có phải quyền chỉnh sửa hay không
  bool get isEditor => permissionType.toLowerCase() == 'editor';

  /// Nhãn hiển thị tiếng Việt của vai trò
  String get displayRoleName {
    switch (permissionType.toLowerCase()) {
      case 'editor':
        return 'Người chỉnh sửa';
      case 'viewer':
      default:
        return 'Người xem';
    }
  }

  /// Khởi tạo từ Map/JSON trả về bởi Supabase PostgREST
  factory DocumentPermissionModel.fromJson(Map<String, dynamic> json) {
    // Trích xuất thông tin người dùng được join (nếu có)
    Map<String, dynamic>? userMap;
    if (json['users'] is Map<String, dynamic>) {
      userMap = json['users'] as Map<String, dynamic>;
    }

    return DocumentPermissionModel(
      id: json['id'] as String? ?? '',
      documentId: json['document_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      permissionType: (json['permission_type'] as String? ?? 'viewer').toLowerCase(),
      grantedBy: json['granted_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      userEmail: userMap?['email'] as String? ?? json['user_email'] as String?,
      userDisplayName: userMap?['display_name'] as String? ?? json['user_display_name'] as String?,
      userPhotoUrl: userMap?['photo_url'] as String? ?? json['user_photo_url'] as String?,
    );
  }

  /// Payload cho thao tác INSERT vào bảng public.permissions
  /// Trigger guard_permissions tự động gán NEW.granted_by = current_user_id()
  Map<String, dynamic> toJsonForInsert() {
    return {
      'document_id': documentId,
      'user_id': userId,
      'permission_type': permissionType,
    };
  }

  /// Payload cho thao tác UPDATE quyền (chỉ cho phép đổi permission_type)
  Map<String, dynamic> toJsonForUpdate() {
    return {
      'permission_type': permissionType,
    };
  }

  DocumentPermissionModel copyWith({
    String? id,
    String? documentId,
    String? userId,
    String? permissionType,
    String? grantedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userEmail,
    String? userDisplayName,
    String? userPhotoUrl,
  }) {
    return DocumentPermissionModel(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      userId: userId ?? this.userId,
      permissionType: permissionType ?? this.permissionType,
      grantedBy: grantedBy ?? this.grantedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userEmail: userEmail ?? this.userEmail,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentPermissionModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          documentId == other.documentId &&
          userId == other.userId &&
          permissionType == other.permissionType;

  @override
  int get hashCode =>
      id.hashCode ^ documentId.hashCode ^ userId.hashCode ^ permissionType.hashCode;

  @override
  String toString() {
    return 'DocumentPermissionModel(id: $id, doc: $documentId, user: $userId, role: $permissionType)';
  }
}
