// ==============================================================================
// DOMAIN LAYER: Document Repository Interface (Giao diện trừu tượng Repository)
// Định nghĩa hợp đồng (contract) thao tác dữ liệu độc lập với công nghệ lưu trữ.
// Giúp tầng Presentation không phụ thuộc trực tiếp vào Drift hay SQLite, 
// dễ dàng thay thế sang Firebase/REST API hoặc viết Unit Test Mocking theo chuẩn Cashew.
// ==============================================================================

import '../models/category_model.dart';
import '../models/document_model.dart';

abstract class DocumentRepository {
  /// Lắng nghe Stream danh sách toàn bộ tài liệu (tự động cập nhật khi DB thay đổi)
  Stream<List<DocumentModel>> watchAllDocuments();

  /// Lấy danh sách tài liệu một lần (Future)
  Future<List<DocumentModel>> getAllDocuments();

  /// Lắng nghe Stream tài liệu được lọc theo danh mục và từ khóa tìm kiếm
  Stream<List<DocumentModel>> watchFilteredDocuments({
    String? categoryId,
    String? searchQuery,
  });

  /// Lấy chi tiết tài liệu theo ID
  Future<DocumentModel?> getDocumentById(String id);

  /// Thêm mới tài liệu vào kho dữ liệu
  Future<void> insertDocument(DocumentModel document);

  /// Cập nhật thông tin tài liệu hiện có
  Future<void> updateDocument(DocumentModel document);

  /// Xóa tài liệu theo ID
  Future<void> deleteDocument(String id);

  /// Xóa toàn bộ tài liệu trong bộ nhớ đệm cục bộ (khi đăng xuất / đổi tài khoản)
  Future<void> clearAllLocalDocuments();

  /// Lắng nghe Stream danh sách toàn bộ danh mục học tập
  Stream<List<CategoryModel>> watchAllCategories();

  /// Lấy danh sách toàn bộ danh mục (Future)
  Future<List<CategoryModel>> getAllCategories();

  /// Thêm danh mục mới
  Future<void> insertCategory(CategoryModel category);

  /// Xóa danh mục
  Future<void> deleteCategory(String id);
}
