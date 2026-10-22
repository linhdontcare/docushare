import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import 'user_permission.dart';

/// Các vai trò người dùng trong hệ thống DocuShare (RBAC)
enum UserRole {
  /// Quản trị viên hệ thống - Có toàn quyền kiểm soát
  admin(
    name: 'Quản trị viên',
    code: 'ADMIN',
    description: 'Toàn quyền cấu hình hệ thống, quản lý người dùng và duyệt tài liệu.',
    color: AppColors.error,
    icon: Icons.admin_panel_settings,
  ),

  /// Thủ thư kho lưu trữ - Quản lý nghiệp vụ kho, mượn trả & vị trí
  librarian(
    name: 'Thủ thư',
    code: 'LIBRARIAN',
    description: 'Quản lý kho tài liệu, vị trí kệ sách, kiểm duyệt và phê duyệt mượn - trả.',
    color: AppColors.primary,
    icon: Icons.local_library,
  ),

  /// Giảng viên - Đăng tải học liệu, tạo nhóm môn học & mượn ưu tiên
  lecturer(
    name: 'Giảng viên',
    code: 'LECTURER',
    description: 'Đăng tải giáo trình, đề thi, bài giảng và chia sẻ tài liệu theo học phần.',
    color: AppColors.tertiary,
    icon: Icons.school,
  ),

  /// Sinh viên - Tìm kiếm, đọc số hóa, mượn trả & tương tác
  student(
    name: 'Sinh viên',
    code: 'STUDENT',
    description: 'Tra cứu, đọc tài liệu số, đăng ký mượn sách giấy và đánh giá bài học.',
    color: AppColors.secondary,
    icon: Icons.person_pin,
  );

  final String name;
  final String code;
  final String description;
  final Color color;
  final IconData icon;

  const UserRole({
    required this.name,
    required this.code,
    required this.description,
    required this.color,
    required this.icon,
  });

  /// Danh sách các quyền được cấp cho vai trò này
  Set<UserPermission> get permissions {
    switch (this) {
      case UserRole.admin:
        // Admin sở hữu toàn bộ các quyền trong hệ thống
        return UserPermission.values.toSet();

      case UserRole.librarian:
        return {
          UserPermission.manageAllDocuments,
          UserPermission.uploadDocuments,
          UserPermission.manageStorageLocations,
          UserPermission.approveBorrowRequests,
          UserPermission.borrowPhysicalDocs,
          UserPermission.readOnlineDocs,
          UserPermission.shareDocuments,
          UserPermission.writeReviews,
        };

      case UserRole.lecturer:
        return {
          UserPermission.uploadDocuments,
          UserPermission.borrowPhysicalDocs,
          UserPermission.readOnlineDocs,
          UserPermission.shareDocuments,
          UserPermission.writeReviews,
        };

      case UserRole.student:
        return {
          UserPermission.borrowPhysicalDocs,
          UserPermission.readOnlineDocs,
          UserPermission.shareDocuments,
          UserPermission.writeReviews,
        };
    }
  }

  /// Kiểm tra xem vai trò có quyền cụ thể không
  bool hasPermission(UserPermission permission) {
    return permissions.contains(permission);
  }
}
