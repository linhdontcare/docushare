// ==============================================================================
// DATA LAYER: Category DAO (Data Access Object)
// Cashew phân tách các tác vụ truy vấn SQL thô vào các DAO riêng biệt.
// Lợi ích: Cô lập truy vấn cơ sở dữ liệu, code gọn gàng, hỗ trợ Unit Test độc lập.
// ==============================================================================

import 'package:drift/drift.dart';
import '../drift_database.dart';
import '../tables.dart';

part 'category_dao.g.dart';

@DriftAccessor(tables: [CategoriesTable])
class CategoryDao extends DatabaseAccessor<AppDatabase> with _$CategoryDaoMixin {
  CategoryDao(super.db);

  /// Lắng nghe Stream danh sách toàn bộ danh mục học tập (Reactive UI)
  Stream<List<CategoriesTableData>> watchAllCategories() {
    return (select(categoriesTable)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  }

  /// Lấy danh sách toàn bộ danh mục (Future)
  Future<List<CategoriesTableData>> getAllCategories() {
    return (select(categoriesTable)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  }

  /// Tìm danh mục theo ID
  Future<CategoriesTableData?> getCategoryById(String id) {
    return (select(categoriesTable)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// Chèn danh mục mới hoặc thay thế nếu đã tồn tại
  Future<int> insertCategory(CategoriesTableCompanion entry) {
    return into(categoriesTable).insert(entry, mode: InsertMode.insertOrReplace);
  }

  /// Cập nhật thông tin danh mục
  Future<bool> updateCategory(CategoriesTableCompanion entry) {
    return update(categoriesTable).replace(entry);
  }

  /// Xóa danh mục theo ID
  Future<int> deleteCategory(String id) {
    return (delete(categoriesTable)..where((tbl) => tbl.id.equals(id))).go();
  }
}
