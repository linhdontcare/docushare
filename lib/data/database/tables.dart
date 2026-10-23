// ==============================================================================
// DATA LAYER: Drift Database Tables (Bảng SQLite Schema)
// Phản chiếu trực tiếp mô hình Table definition của Drift theo chuẩn Cashew:
// Định nghĩa schema tường minh, rằng buộc khóa ngoại (foreign key reference),
// giá trị mặc định, kiểm tra độ dài và tích hợp TypeConverter.
// ==============================================================================

import 'package:drift/drift.dart';
import '../../core/constants/app_constants.dart';
import 'converters/type_converters.dart';

/// Bảng CategoriesTable: Quản lý danh mục tài liệu (Bài giảng, Bài tập, Tài liệu tham khảo,...)
class CategoriesTable extends Table {
  // Khóa chính: Chuỗi ID dạng UUID hoặc mã định danh duy nhất
  TextColumn get id => text()();

  // Tên hiển thị của danh mục (tối đa 100 ký tự)
  TextColumn get name => text().withLength(min: 1, max: AppConstants.subjectMaxLength)();

  // Tên biểu tượng (Material Icon name)
  TextColumn get icon => text().nullable()();

  // Mã màu hiển thị định dạng Hex (ví dụ: #2563EB)
  TextColumn get colorHex => text().nullable()();

  // Thời gian tạo danh mục
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bảng DocumentsTable: Quản lý tài liệu học tập
class DocumentsTable extends Table {
  // Khóa chính tài liệu
  TextColumn get id => text()();

  // Tiêu đề tài liệu (Title)
  TextColumn get title => text().withLength(min: 1, max: AppConstants.titleMaxLength)();

  // Môn học liên quan (Subject: ví dụ "Toán rời rạc", "Lập trình di động")
  TextColumn get subject => text().withLength(min: 1, max: AppConstants.subjectMaxLength)();

  // Khóa ngoại liên kết tới CategoriesTable
  TextColumn get categoryId => text().references(
        CategoriesTable,
        #id,
        onDelete: KeyAction.cascade,
        onUpdate: KeyAction.cascade,
      )();

  // Đường dẫn tệp nội bộ hoặc liên kết tài liệu trực tuyến (URL / File path)
  TextColumn get filePathOrUrl => text().nullable()();

  // Ghi chú bổ sung (Notes)
  TextColumn get notes => text().nullable().withLength(max: AppConstants.notesMaxLength)();

  // Danh sách thẻ phân loại, chuyển đổi sang JSON qua StringListConverter
  TextColumn get tags => text().map(const StringListConverter()).withDefault(const Constant('[]'))();

  // Mức độ ưu tiên/quan trọng, chuyển đổi qua DocumentPriorityConverter
  TextColumn get priority => text().map(const DocumentPriorityConverter()).withDefault(const Constant('low'))();

  // Ngày tạo tài liệu
  DateTimeColumn get createdDate => dateTime().withDefault(currentDateAndTime)();

  // Ngày cập nhật tài liệu gần nhất
  DateTimeColumn get updatedDate => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
