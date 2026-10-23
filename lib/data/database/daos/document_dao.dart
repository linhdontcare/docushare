// ==============================================================================
// DATA LAYER: Document DAO (Data Access Object)
// Đảm nhiệm toàn bộ các thao tác CRUD và Filter/Search truy vấn SQL SQLite
// cho tài liệu học tập (DocumentsTable). 
// Tương tự pattern Cashew: tận dụng các toán tử logic của Drift để tối ưu tốc độ truy vấn.
// ==============================================================================

import 'package:drift/drift.dart';
import '../drift_database.dart';
import '../tables.dart';

part 'document_dao.g.dart';

@DriftAccessor(tables: [DocumentsTable, CategoriesTable])
class DocumentDao extends DatabaseAccessor<AppDatabase> with _$DocumentDaoMixin {
  DocumentDao(super.db);

  /// Lắng nghe Stream danh sách tài liệu mới nhất
  Stream<List<DocumentsTableData>> watchAllDocuments() {
    return (select(documentsTable)..orderBy([(t) => OrderingTerm.desc(t.createdDate)])).watch();
  }

  /// Lấy danh sách tài liệu một lần (Future)
  Future<List<DocumentsTableData>> getAllDocuments() {
    return (select(documentsTable)..orderBy([(t) => OrderingTerm.desc(t.createdDate)])).get();
  }

  /// Lấy tài liệu theo ID cụ thể
  Future<DocumentsTableData?> getDocumentById(String id) {
    return (select(documentsTable)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// Lắng nghe tài liệu kết hợp bộ lọc Category và Search từ khóa (tiêu đề hoặc môn học)
  Stream<List<DocumentsTableData>> watchFilteredDocuments({
    String? categoryId,
    String? searchQuery,
  }) {
    final query = select(documentsTable);

    // Lọc theo danh mục nếu có chỉ định (khác null và khác 'all')
    if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') {
      query.where((tbl) => tbl.categoryId.equals(categoryId));
    }

    // Lọc theo từ khóa tìm kiếm: kiểm tra khớp Tiêu đề HOẶC Môn học
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final searchPattern = '%${searchQuery.trim()}%';
      query.where((tbl) => tbl.title.like(searchPattern) | tbl.subject.like(searchPattern));
    }

    // Sắp xếp giảm dần theo ngày tạo (tài liệu mới nhất lên đầu)
    query.orderBy([(t) => OrderingTerm.desc(t.createdDate)]);

    return query.watch();
  }

  /// Thêm mới tài liệu vào bảng
  Future<int> insertDocument(DocumentsTableCompanion entry) {
    return into(documentsTable).insert(entry, mode: InsertMode.insertOrReplace);
  }

  /// Cập nhật tài liệu
  Future<bool> updateDocument(DocumentsTableCompanion entry) {
    return update(documentsTable).replace(entry);
  }

  /// Xóa tài liệu theo ID
  Future<int> deleteDocument(String id) {
    return (delete(documentsTable)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// Xóa sạch toàn bộ tài liệu trong bộ nhớ đệm SQLite cục bộ (dùng khi đăng xuất / đổi tài khoản)
  Future<int> deleteAllDocuments() {
    return delete(documentsTable).go();
  }
}
