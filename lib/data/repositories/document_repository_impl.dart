// ==============================================================================
// DATA LAYER: Document Repository Implementation
// Hiện thực hóa interface DocumentRepository của tầng Domain theo chuẩn Cashew:
// - Tách biệt hoàn toàn tầng dữ liệu (Drift SQLite) khỏi tầng giao diện
// - Thực hiện ánh xạ (Mapping) hai chiều giữa Drift TableData và Domain Models
// - Tận dụng SQL JOIN giữa DocumentsTable và CategoriesTable để lấy kèm metadata danh mục
// - Phục vụ luồng dữ liệu phản ứng Reactive Streams (watch) và tác vụ đơn nhất (Future)
// ==============================================================================

import 'package:drift/drift.dart';
import '../../domain/models/category_model.dart';
import '../../domain/models/document_model.dart';
import '../../domain/repositories/document_repository.dart';
import '../database/drift_database.dart';

class DocumentRepositoryImpl implements DocumentRepository {
  final AppDatabase _db;

  DocumentRepositoryImpl(this._db);

  @override
  Stream<List<DocumentModel>> watchAllDocuments() {
    // Thực hiện truy vấn JOIN giữa DocumentsTable và CategoriesTable
    final query = _db.select(_db.documentsTable).join([
      leftOuterJoin(
        _db.categoriesTable,
        _db.categoriesTable.id.equalsExp(_db.documentsTable.categoryId),
      ),
    ])..orderBy([OrderingTerm.desc(_db.documentsTable.createdDate)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final doc = row.readTable(_db.documentsTable);
        final cat = row.readTableOrNull(_db.categoriesTable);
        return _mapToDomain(doc, cat);
      }).toList();
    });
  }

  @override
  Future<List<DocumentModel>> getAllDocuments() async {
    final query = _db.select(_db.documentsTable).join([
      leftOuterJoin(
        _db.categoriesTable,
        _db.categoriesTable.id.equalsExp(_db.documentsTable.categoryId),
      ),
    ])..orderBy([OrderingTerm.desc(_db.documentsTable.createdDate)]);

    final rows = await query.get();
    return rows.map((row) {
      final doc = row.readTable(_db.documentsTable);
      final cat = row.readTableOrNull(_db.categoriesTable);
      return _mapToDomain(doc, cat);
    }).toList();
  }

  @override
  Stream<List<DocumentModel>> watchFilteredDocuments({
    String? categoryId,
    String? searchQuery,
  }) {
    final query = _db.select(_db.documentsTable).join([
      leftOuterJoin(
        _db.categoriesTable,
        _db.categoriesTable.id.equalsExp(_db.documentsTable.categoryId),
      ),
    ]);

    // Lọc theo Category nếu khác 'all'
    if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') {
      query.where(_db.documentsTable.categoryId.equals(categoryId));
    }

    // Lọc theo tiêu đề hoặc môn học bằng toán tử LIKE trong SQLite
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final pattern = '%${searchQuery.trim()}%';
      query.where(
        _db.documentsTable.title.like(pattern) |
            _db.documentsTable.subject.like(pattern),
      );
    }

    query.orderBy([OrderingTerm.desc(_db.documentsTable.createdDate)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final doc = row.readTable(_db.documentsTable);
        final cat = row.readTableOrNull(_db.categoriesTable);
        return _mapToDomain(doc, cat);
      }).toList();
    });
  }

  @override
  Future<DocumentModel?> getDocumentById(String id) async {
    final query = _db.select(_db.documentsTable).join([
      leftOuterJoin(
        _db.categoriesTable,
        _db.categoriesTable.id.equalsExp(_db.documentsTable.categoryId),
      ),
    ])..where(_db.documentsTable.id.equals(id));

    final row = await query.getSingleOrNull();
    if (row == null) return null;

    final doc = row.readTable(_db.documentsTable);
    final cat = row.readTableOrNull(_db.categoriesTable);
    return _mapToDomain(doc, cat);
  }

  @override
  Future<void> insertDocument(DocumentModel document) async {
    await _db.documentDao.insertDocument(
      DocumentsTableCompanion(
        id: Value(document.id),
        title: Value(document.title),
        subject: Value(document.subject),
        categoryId: Value(document.categoryId),
        filePathOrUrl: Value(document.filePathOrUrl),
        notes: Value(document.notes),
        tags: Value(document.tags),
        priority: Value(document.priority),
        createdDate: Value(document.createdDate),
        updatedDate: Value(document.updatedDate),
      ),
    );
  }

  @override
  Future<void> updateDocument(DocumentModel document) async {
    await _db.documentDao.updateDocument(
      DocumentsTableCompanion(
        id: Value(document.id),
        title: Value(document.title),
        subject: Value(document.subject),
        categoryId: Value(document.categoryId),
        filePathOrUrl: Value(document.filePathOrUrl),
        notes: Value(document.notes),
        tags: Value(document.tags),
        priority: Value(document.priority),
        createdDate: Value(document.createdDate),
        updatedDate: Value(document.updatedDate),
      ),
    );
  }

  @override
  Future<void> deleteDocument(String id) async {
    await _db.documentDao.deleteDocument(id);
  }

  @override
  Future<void> clearAllLocalDocuments() async {
    await _db.documentDao.deleteAllDocuments();
  }

  @override
  Stream<List<CategoryModel>> watchAllCategories() {
    return _db.categoryDao.watchAllCategories().map(
          (list) => list.map(_mapCategoryToDomain).toList(),
        );
  }

  @override
  Future<List<CategoryModel>> getAllCategories() async {
    final list = await _db.categoryDao.getAllCategories();
    return list.map(_mapCategoryToDomain).toList();
  }

  @override
  Future<void> insertCategory(CategoryModel category) async {
    await _db.categoryDao.insertCategory(
      CategoriesTableCompanion(
        id: Value(category.id),
        name: Value(category.name),
        icon: Value(category.icon),
        colorHex: Value(category.colorHex),
        createdAt: Value(category.createdAt),
      ),
    );
  }

  @override
  Future<void> deleteCategory(String id) async {
    await _db.categoryDao.deleteCategory(id);
  }

  // --- Các hàm chuyển đổi Mapper nội bộ (Data Transfer Object -> Domain Model) ---

  DocumentModel _mapToDomain(DocumentsTableData doc, CategoriesTableData? cat) {
    return DocumentModel(
      id: doc.id,
      title: doc.title,
      subject: doc.subject,
      categoryId: doc.categoryId,
      categoryName: cat?.name,
      categoryColorHex: cat?.colorHex,
      filePathOrUrl: doc.filePathOrUrl,
      notes: doc.notes,
      tags: doc.tags,
      priority: doc.priority,
      createdDate: doc.createdDate,
      updatedDate: doc.updatedDate,
    );
  }

  CategoryModel _mapCategoryToDomain(CategoriesTableData cat) {
    return CategoryModel(
      id: cat.id,
      name: cat.name,
      icon: cat.icon,
      colorHex: cat.colorHex,
      createdAt: cat.createdAt,
    );
  }
}
