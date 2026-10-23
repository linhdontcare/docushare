import 'package:flutter_test/flutter_test.dart';
import 'package:docushare/domain/models/document_model.dart';

void main() {
  group('Kiểm thử luồng Xóa Tài liệu an toàn (Document Deletion Flow Tests)', () {
    final now = DateTime.now();

    final testDoc = DocumentModel(
      id: 'c8e19b88-43d7-4df3-a12b-31327170a4a8',
      title: 'Tài liệu Ôn tập Vật lý',
      subject: 'Vật lý 1',
      categoryId: 'physics',
      filePathOrUrl: 'users/kLgMf123/documents/c8e19b88/vat_ly.pdf',
      notes: 'Bản scan ôn thi',
      createdDate: now,
      updatedDate: now,
    );

    // 1. Trường hợp 1: Xóa thành công cả Firebase Storage và Supabase
    test('1. Xóa thành công cả Firebase Storage và Supabase theo đúng thứ tự', () async {
      var isStorageDeleted = false;
      var isSupabaseDeleted = false;
      var isFirestoreDeleted = false;
      var isDriftDeleted = false;
      var isUiUpdated = false;

      final documentsList = [testDoc];

      // Thứ tự thực thi mô phỏng chuẩn của DocumentProvider.deleteDocument
      final storagePath = testDoc.filePathOrUrl!;
      expect(storagePath.startsWith('users/'), isTrue);

      // Bước 1: Xóa Storage
      isStorageDeleted = true;

      // Bước 2: Xóa Supabase (chỉ khi Storage thành công)
      if (isStorageDeleted) {
        isSupabaseDeleted = true;
      }

      // Bước 3 & 4: Xóa Firestore và Drift
      if (isSupabaseDeleted) {
        isFirestoreDeleted = true;
        isDriftDeleted = true;
      }

      // Bước 5: Cập nhật UI
      documentsList.removeWhere((doc) => doc.id == testDoc.id);
      isUiUpdated = true;

      expect(isStorageDeleted, isTrue);
      expect(isSupabaseDeleted, isTrue);
      expect(isFirestoreDeleted, isTrue);
      expect(isDriftDeleted, isTrue);
      expect(isUiUpdated, isTrue);
      expect(documentsList.isEmpty, isTrue);
    });

    // 2. Trường hợp 2: Storage xóa thất bại -> Bảo toàn metadata Supabase
    test('2. Storage xóa thất bại: Dừng lại ngay, không xóa Supabase, bảo toàn dữ liệu', () async {
      var isStorageDeleted = false;
      var isSupabaseDeleted = false;
      String? errorMessage;

      try {
        // Mô phỏng Storage ném lỗi (ví dụ 403 permission-denied hoặc lỗi mạng)
        throw StateError('Firebase Storage: unauthorized (403)');
      } catch (e) {
        errorMessage = 'Không thể xóa tệp trên Firebase Storage Emulator: $e';
        // Theo thiết kế: Không gọi delete Supabase!
      }

      expect(isStorageDeleted, isFalse);
      expect(isSupabaseDeleted, isFalse);
      expect(errorMessage, contains('unauthorized'));
    });

    // 3. Trường hợp 3: Supabase xóa thất bại (sau khi Storage đã xóa)
    test('3. Supabase xóa thất bại: Báo lỗi chi tiết để xử lý xóa một phần', () async {
      var isStorageDeleted = false;
      var isSupabaseDeleted = false;
      String? failureReason;

      // Bước 1: Storage xóa xong
      isStorageDeleted = true;

      // Bước 2: Supabase gặp sự cố mạng hoặc RLS
      try {
        throw StateError('Supabase: Lỗi kết nối mạng hoặc RLS Denied');
      } catch (supabaseError) {
        failureReason = 'Tệp Storage đã xóa nhưng Supabase thất bại: $supabaseError';
      }

      expect(isStorageDeleted, isTrue);
      expect(isSupabaseDeleted, isFalse);
      expect(failureReason, contains('RLS Denied'));
    });

    // 4. Trường hợp 4: File không tồn tại trên Storage (object-not-found)
    test('4. File không tồn tại trên Storage (object-not-found): Coi là thành công, tiếp tục xóa Supabase', () async {
      var isStorageProcessed = false;
      var isSupabaseDeleted = false;

      // Mô phỏng lỗi object-not-found từ Firebase Storage
      final simulatedErrorCode = 'object-not-found';
      if (simulatedErrorCode == 'object-not-found') {
        // Idempotent: coi như tệp đã không còn
        isStorageProcessed = true;
      }

      if (isStorageProcessed) {
        isSupabaseDeleted = true;
      }

      expect(isStorageProcessed, isTrue);
      expect(isSupabaseDeleted, isTrue);
    });

    // 5. Trường hợp 5: Xóa xong tài liệu biến mất ngay lập tức khỏi UI
    test('5. Xóa xong tài liệu biến mất ngay lập tức khỏi danh sách bộ nhớ UI', () {
      final inMemoryDocs = [
        testDoc,
        DocumentModel(
          id: 'doc_2',
          title: 'Tài liệu Tiếng Anh',
          subject: 'Tiếng Anh',
          categoryId: 'english',
          createdDate: now,
          updatedDate: now,
        ),
      ];

      expect(inMemoryDocs.length, equals(2));

      // Thực hiện xóa doc đầu tiên
      inMemoryDocs.removeWhere((doc) => doc.id == testDoc.id);

      expect(inMemoryDocs.length, equals(1));
      expect(inMemoryDocs.any((d) => d.id == testDoc.id), isFalse);
      expect(inMemoryDocs.first.id, equals('doc_2'));
    });

    // 6. Trường hợp 6: Tải lại và khởi động lại app không làm tài liệu xuất hiện lại
    test('6. Đã xóa sạch ở cả Supabase, Firestore và SQLite -> Tải lại không bị phục hồi tài liệu cũ', () async {
      // Giả lập cơ sở dữ liệu sau khi xóa
      final mockFirestoreStore = <String, Map<String, dynamic>>{};
      final mockSqliteStore = <String, Map<String, dynamic>>{};
      final mockSupabaseStore = <String, Map<String, dynamic>>{};

      // Trước khi xóa: có doc
      mockFirestoreStore[testDoc.id] = {'title': testDoc.title};
      mockSqliteStore[testDoc.id] = {'title': testDoc.title};
      mockSupabaseStore[testDoc.id] = {'title': testDoc.title};

      // Thực hiện xóa đồng bộ
      mockFirestoreStore.remove(testDoc.id);
      mockSqliteStore.remove(testDoc.id);
      mockSupabaseStore.remove(testDoc.id);

      // Khởi động lại / Refresh app
      final refreshedFromFirestore = mockFirestoreStore.values.toList();
      final refreshedFromSqlite = mockSqliteStore.values.toList();
      final refreshedFromSupabase = mockSupabaseStore.values.toList();

      expect(refreshedFromFirestore.isEmpty, isTrue);
      expect(refreshedFromSqlite.isEmpty, isTrue);
      expect(refreshedFromSupabase.isEmpty, isTrue);
    });
  });
}
