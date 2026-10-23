// ==============================================================================
// DATA LAYER: Drift Database (Quản lý Database SQLite tập trung)
// Theo chuẩn Cashew app: AppDatabase kế thừa từ code sinh ra (_$AppDatabase),
// tích hợp MigrationStrategy để seed dữ liệu danh mục ban đầu,
// kích hoạt PRAGMA foreign_keys để đảm bảo tính toàn vẹn tham chiếu dữ liệu.
// ==============================================================================

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../core/database/connection.dart';
import 'converters/type_converters.dart';
import 'tables.dart';
import 'daos/category_dao.dart';
import 'daos/document_dao.dart';

part 'drift_database.g.dart';

@DriftDatabase(
  tables: [CategoriesTable, DocumentsTable],
  daos: [CategoryDao, DocumentDao],
)
class AppDatabase extends _$AppDatabase {
  // Constructor mặc định sử dụng LazyDatabase mở file SQLite trong app storage
  AppDatabase([QueryExecutor? e]) : super(e ?? openConnection());

  // Schema version cho cơ sở dữ liệu
  @override
  int get schemaVersion => 1;

  // Chiến lược Migration & Khởi tạo dữ liệu mẫu (Seeding)
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          // Tạo tất cả các bảng trong database
          await m.createAll();

          // Tự động chèn các danh mục chuẩn ban đầu (Seed initial categories)
          await _seedDefaultCategories();
        },
        beforeOpen: (details) async {
          // Bật tính năng kiểm tra khóa ngoại (Foreign Keys) trong SQLite
          if (!kIsWeb) {
            await customStatement('PRAGMA foreign_keys = ON;');
          }
          await _seedDefaultCategories();
        },
      );

  /// Khởi tạo dữ liệu danh mục mặc định ban đầu
  Future<void> _seedDefaultCategories() async {
    for (final entry in AppConstants.defaultCategoryNames.entries) {
      final id = entry.key;
      final name = entry.value;
      final colorHex = AppConstants.defaultCategoryColors[id];
      final icon = AppConstants.defaultCategoryIcons[id];

      await into(categoriesTable).insert(
        CategoriesTableCompanion.insert(
          id: id,
          name: name,
          colorHex: Value(colorHex),
          icon: Value(icon),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
  }
}
