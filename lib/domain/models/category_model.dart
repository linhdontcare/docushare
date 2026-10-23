// ==============================================================================
// DOMAIN LAYER: Category Model (Thực thể miền Danh mục)
// Pure Dart Object không phụ thuộc vào bất kỳ framework hoặc cơ sở dữ liệu nào.
// Tuân thủ nguyên lý Dependency Inversion Principle và Cashew Clean Architecture.
// ==============================================================================

import '../../core/constants/app_constants.dart';

class CategoryModel {
  final String id;
  final String name;
  final String? icon;
  final String? colorHex;
  final DateTime createdAt;

  const CategoryModel({
    required this.id,
    required this.name,
    this.icon,
    this.colorHex,
    required this.createdAt,
  });

  /// Danh mục mặc định ban đầu bảo đảm giao diện combobox và bộ lọc luôn có dữ liệu
  static List<CategoryModel> get defaultCategories => [
        CategoryModel(
          id: AppConstants.catLectureNotesId,
          name: AppConstants.defaultCategoryNames[AppConstants.catLectureNotesId] ??
              'Bài giảng & Ghi chú',
          icon: AppConstants.defaultCategoryIcons[AppConstants.catLectureNotesId],
          colorHex:
              AppConstants.defaultCategoryColors[AppConstants.catLectureNotesId],
          createdAt: DateTime(2026, 1, 1),
        ),
        CategoryModel(
          id: AppConstants.catAssignmentsId,
          name: AppConstants.defaultCategoryNames[AppConstants.catAssignmentsId] ??
              'Bài tập & Tiểu luận',
          icon: AppConstants.defaultCategoryIcons[AppConstants.catAssignmentsId],
          colorHex:
              AppConstants.defaultCategoryColors[AppConstants.catAssignmentsId],
          createdAt: DateTime(2026, 1, 1),
        ),
        CategoryModel(
          id: AppConstants.catReferencesId,
          name: AppConstants.defaultCategoryNames[AppConstants.catReferencesId] ??
              'Tài liệu tham khảo',
          icon: AppConstants.defaultCategoryIcons[AppConstants.catReferencesId],
          colorHex:
              AppConstants.defaultCategoryColors[AppConstants.catReferencesId],
          createdAt: DateTime(2026, 1, 1),
        ),
        CategoryModel(
          id: AppConstants.catExamPrepId,
          name: AppConstants.defaultCategoryNames[AppConstants.catExamPrepId] ??
              'Đề thi & Ôn tập',
          icon: AppConstants.defaultCategoryIcons[AppConstants.catExamPrepId],
          colorHex:
              AppConstants.defaultCategoryColors[AppConstants.catExamPrepId],
          createdAt: DateTime(2026, 1, 1),
        ),
        CategoryModel(
          id: AppConstants.catLabReportsId,
          name: AppConstants.defaultCategoryNames[AppConstants.catLabReportsId] ??
              'Báo cáo thực hành',
          icon: AppConstants.defaultCategoryIcons[AppConstants.catLabReportsId],
          colorHex:
              AppConstants.defaultCategoryColors[AppConstants.catLabReportsId],
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

  /// Tạo bản sao có cập nhật các trường nhất định
  CategoryModel copyWith({
    String? id,
    String? name,
    String? icon,
    String? colorHex,
    DateTime? createdAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CategoryModel(id: $id, name: $name)';
}
