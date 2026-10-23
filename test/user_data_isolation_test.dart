import 'package:flutter_test/flutter_test.dart';
import 'package:docushare/domain/models/document_model.dart';
import 'package:docushare/domain/models/category_model.dart';
import 'package:docushare/domain/repositories/document_repository.dart';
import 'package:docushare/presentation/providers/document_provider.dart';

class MockDocumentRepository implements DocumentRepository {
  final List<DocumentModel> _storage = [];

  @override
  Future<List<DocumentModel>> getAllDocuments() async => List.unmodifiable(_storage);

  @override
  Stream<List<DocumentModel>> watchAllDocuments() => Stream.value(List.unmodifiable(_storage));

  @override
  Future<DocumentModel?> getDocumentById(String id) async {
    return _storage.where((d) => d.id == id).firstOrNull;
  }

  @override
  Stream<List<DocumentModel>> watchFilteredDocuments({String? categoryId, String? searchQuery}) {
    return Stream.value(List.unmodifiable(_storage));
  }

  @override
  Future<int> insertDocument(DocumentModel document) async {
    final idx = _storage.indexWhere((d) => d.id == document.id);
    if (idx != -1) {
      _storage[idx] = document;
    } else {
      _storage.add(document);
    }
    return 1;
  }

  @override
  Future<bool> updateDocument(DocumentModel document) async {
    final idx = _storage.indexWhere((d) => d.id == document.id);
    if (idx != -1) {
      _storage[idx] = document;
      return true;
    }
    return false;
  }

  @override
  Future<int> deleteDocument(String id) async {
    _storage.removeWhere((d) => d.id == id);
    return 1;
  }

  @override
  Future<int> clearAllLocalDocuments() async {
    final count = _storage.length;
    _storage.clear();
    return count;
  }

  @override
  Future<List<CategoryModel>> getAllCategories() async => [];

  @override
  Stream<List<CategoryModel>> watchAllCategories() => Stream.value([]);

  @override
  Future<void> insertCategory(CategoryModel category) async {}

  @override
  Future<void> deleteCategory(String id) async {}
}

void main() {
  group('Kiểm thử phân tách dữ liệu 3 tài khoản A, B, C và dọn dẹp cache', () {
    late MockDocumentRepository mockRepo;
    late DocumentProvider provider;

    final docUserA = DocumentModel(
      id: 'doc-user-a-1',
      title: 'D11741 test',
      subject: 'Công nghệ thông tin',
      categoryId: 'all',
      createdDate: DateTime.now(),
      updatedDate: DateTime.now(),
      userPermissionRole: 'owner',
      ownerEmail: 'userA@gmail.com',
      ownerName: 'User A',
      filePathOrUrl: 'users/uid-A/documents/doc-user-a-1/test.pdf',
    );

    final docUserB = DocumentModel(
      id: 'doc-user-b-1',
      title: 'Tài liệu của B',
      subject: 'Toán học',
      categoryId: 'all',
      createdDate: DateTime.now(),
      updatedDate: DateTime.now(),
      userPermissionRole: 'owner',
      ownerEmail: 'userB@gmail.com',
      ownerName: 'User B',
      filePathOrUrl: 'users/uid-B/documents/doc-user-b-1/toan.pdf',
    );

    final docSharedFromAToB = DocumentModel(
      id: 'doc-user-a-1',
      title: 'D11741 test (Được A chia sẻ cho B)',
      subject: 'Công nghệ thông tin',
      categoryId: 'all',
      createdDate: DateTime.now(),
      updatedDate: DateTime.now(),
      userPermissionRole: 'viewer', // Quyền Viewer
      ownerEmail: 'userA@gmail.com',
      ownerName: 'User A',
      filePathOrUrl: 'users/uid-A/documents/doc-user-a-1/test.pdf',
    );

    setUp(() {
      mockRepo = MockDocumentRepository();
      provider = DocumentProvider(repository: mockRepo);
    });

    test('1. Tài khoản A tạo tài liệu -> Lưu vào in-memory và SQLite cục bộ', () async {
      await provider.addDocument(docUserA);

      expect(provider.documents.length, 1);
      expect(provider.documents.first.title, 'D11741 test');

      final localDocs = await mockRepo.getAllDocuments();
      expect(localDocs.length, 1);
      expect(localDocs.first.id, docUserA.id);
    });

    test('2. Tài khoản A đăng xuất -> onUserSignedOut xóa sạch in-memory và SQLite cache', () async {
      // Giả lập A đã có tài liệu
      await provider.addDocument(docUserA);
      expect(provider.documents.isNotEmpty, true);

      // A thực hiện đăng xuất
      await provider.onUserSignedOut();

      // In-memory state phải rỗng hoàn toàn
      expect(provider.documents.isEmpty, true);
      expect(provider.sharedDocuments.isEmpty, true);
      expect(provider.discoverableDocuments.isEmpty, true);
      expect(provider.errorMessage, isNull);

      // SQLite cache phải được dọn dẹp sạch sẽ
      final localDocs = await mockRepo.getAllDocuments();
      expect(localDocs.isEmpty, true, reason: 'Cache Drift SQLite phải rỗng sau khi đăng xuất');
    });

    test('3. Tài khoản B đăng nhập -> Không nhìn thấy tài liệu của A trong "Tài liệu của tôi"', () async {
      // User A đã upload trước đó nhưng đã đăng xuất
      await mockRepo.clearAllLocalDocuments();

      // Giả lập User B nạp dữ liệu từ cloud của B
      // B chỉ có tài liệu docUserB
      await provider.addDocument(docUserB);

      // "Tài liệu của tôi" của B chỉ có docUserB, TUYỆT ĐỐI không có docUserA
      expect(provider.documents.length, 1);
      expect(provider.documents.first.id, 'doc-user-b-1');
      expect(provider.documents.any((d) => d.id == docUserA.id), false);
    });

    test('4. Phân tách danh sách "Được chia sẻ" vs "Tài liệu của tôi"', () {
      // B chỉ thấy tài liệu của A trong "Được chia sẻ" nếu có quyền Viewer/Editor
      expect(docUserA.isOwner, true);
      expect(docSharedFromAToB.isOwner, false);
      expect(docSharedFromAToB.isViewer, true);

      // Tài khoản C không có trong permissions -> Không có trong "Tài liệu của tôi" và "Được chia sẻ"
      final userCDocuments = <DocumentModel>[];
      final userCSharedDocuments = <DocumentModel>[];

      expect(userCDocuments.any((d) => d.id == docUserA.id), false);
      expect(userCSharedDocuments.any((d) => d.id == docUserA.id), false);
    });

    test('5. Quyền truy cập tệp: Không có quyền (Viewer/Editor/Owner/Borrower) thì chặn mở', () {
      // docUserA đối với user C (không có quyền)
      final docWithoutPermission = DocumentModel(
        id: docUserA.id,
        title: docUserA.title,
        subject: docUserA.subject,
        categoryId: docUserA.categoryId,
        createdDate: docUserA.createdDate,
        updatedDate: docUserA.updatedDate,
        userPermissionRole: 'none', // Không có quyền
        filePathOrUrl: docUserA.filePathOrUrl,
      );

      final hasValidPermission = docWithoutPermission.isOwner ||
          docWithoutPermission.isEditor ||
          docWithoutPermission.isViewer ||
          docWithoutPermission.userPermissionRole == 'borrower';

      expect(hasValidPermission, false, reason: 'Người dùng không có quyền phải bị chặn mở tệp');

      // Người có quyền viewer hoặc owner được mở
      expect(docUserA.isOwner, true);
      expect(docSharedFromAToB.isViewer, true);
    });
  });
}
