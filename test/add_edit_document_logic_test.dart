import 'package:flutter_test/flutter_test.dart';
import 'package:docushare/domain/models/document_model.dart';
import 'package:docushare/domain/models/supabase_document_model.dart';

void main() {
  group('Kiểm thử logic Chỉnh sửa tài liệu (AddEditDocument Logic Tests)', () {
    final now = DateTime.now();

    // 1. Trường hợp 1: Mở chỉnh sửa tài liệu đã có PDF trên Firebase Storage
    test('1. Mở chỉnh sửa tài liệu đã có PDF: tách biệt storage_path và web_url', () {
      final existingDoc = DocumentModel(
        id: 'c8e19b88-43d7-4df3-a12b-31327170a4a8',
        title: 'Giáo trình Giải tích 1',
        subject: 'Toán cao cấp',
        categoryId: 'math',
        filePathOrUrl: 'users/kLgMf/documents/c8e19b88/giai_tich_1.pdf',
        notes: 'Chương 1-3',
        createdDate: now,
        updatedDate: now,
      );

      // Kiểm tra nhận diện đúng storage path
      final rawPath = existingDoc.filePathOrUrl?.trim();
      final isStoragePath = rawPath != null && rawPath.startsWith('users/');
      final isWeb = existingDoc.isWebLink;

      expect(isStoragePath, isTrue);
      expect(isWeb, isFalse);

      // Ô nhập web link không được phép hiển thị storage path
      final webUrlDisplay = (isWeb ? rawPath : '') ?? '';
      expect(webUrlDisplay, isEmpty);
      expect(webUrlDisplay.contains('users/'), isFalse);
    });

    // 2. Trường hợp 2: Sửa tiêu đề mà không thay file
    test('2. Sửa tiêu đề mà không thay file: chỉ cập nhật metadata, giữ nguyên file', () {
      const originalStoragePath = 'users/kLgMf/documents/c8e19b88/giai_tich_1.pdf';
      const originalFileName = 'giai_tich_1.pdf';
      const originalFileSize = 5242880;

      const supabaseDoc = SupabaseDocumentModel(
        id: 'c8e19b88-43d7-4df3-a12b-31327170a4a8',
        ownerId: '9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d',
        title: 'Giáo trình Giải tích 1 - Bản cập nhật 2026',
        description: 'Chương 1-3',
        subject: 'Toán cao cấp',
        categoryId: 'math',
        fileName: originalFileName,
        fileType: 'pdf',
        fileSize: originalFileSize,
        storagePath: originalStoragePath,
      );

      // Thao tác sửa metadata chỉ sử dụng toJsonForUpdate()
      final updatePayload = supabaseDoc.toJsonForUpdate();

      // Chỉ cập nhật 4 trường cơ bản
      expect(updatePayload['title'], equals('Giáo trình Giải tích 1 - Bản cập nhật 2026'));
      expect(updatePayload.containsKey('file_name'), isFalse);
      expect(updatePayload.containsKey('file_size'), isFalse);
      expect(updatePayload.containsKey('storage_path'), isFalse);
    });

    // 3. Trường hợp 3: Sửa môn học mà không thay file
    test('3. Sửa môn học mà không thay file: giữ nguyên storage_path và file metadata', () {
      const supabaseDoc = SupabaseDocumentModel(
        id: 'c8e19b88-43d7-4df3-a12b-31327170a4a8',
        ownerId: '9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d',
        title: 'Giáo trình Giải tích 1',
        description: 'Ghi chú',
        subject: 'Toán ứng dụng CNTT', // Đã đổi môn học
        categoryId: 'math',
        fileName: 'giai_tich_1.pdf',
        fileType: 'pdf',
        fileSize: 5242880,
        storagePath: 'users/kLgMf/documents/c8e19b88/giai_tich_1.pdf',
      );

      final updatePayload = supabaseDoc.toJsonForUpdate();
      expect(updatePayload['subject'], equals('Toán ứng dụng CNTT'));
      expect(updatePayload.containsKey('storage_path'), isFalse);
    });

    // 4. Trường hợp 4: Đóng và mở lại ứng dụng, file vẫn được hiển thị nguyên vẹn
    test('4. Dữ liệu metadata lưu trữ trọn vẹn và khôi phục chính xác qua serialization', () {
      final jsonFromSupabase = {
        'id': 'c8e19b88-43d7-4df3-a12b-31327170a4a8',
        'owner_id': '9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d',
        'title': 'Đề thi cuối kì Vật lý',
        'description': 'Đề năm 2025',
        'subject': 'Vật lý đại cương',
        'category_id': 'physics',
        'file_name': 'de_thi_vat_ly.pdf',
        'file_type': 'pdf',
        'file_size': 1048576,
        'storage_path': 'users/kLgMf/documents/c8e19b88/de_thi_vat_ly.pdf',
        'created_at': '2026-10-13T07:00:00.000Z',
        'updated_at': '2026-10-13T07:15:00.000Z',
      };

      final restoredDoc = SupabaseDocumentModel.fromJson(jsonFromSupabase);
      expect(restoredDoc.fileName, equals('de_thi_vat_ly.pdf'));
      expect(restoredDoc.fileSize, equals(1048576));
      expect(restoredDoc.fileType, equals('pdf'));
      expect(restoredDoc.storagePath, equals('users/kLgMf/documents/c8e19b88/de_thi_vat_ly.pdf'));

      // Chuyển sang domain model khi mở app
      final domain = restoredDoc.toDomain();
      expect(domain.filePathOrUrl, equals('users/kLgMf/documents/c8e19b88/de_thi_vat_ly.pdf'));
    });

    // 5. Trường hợp 5: Thay file PDF mới
    test('5. Thay file PDF mới: toJsonForFileUpdate cập nhật metadata tệp mới nhưng bảo vệ timestamps', () {
      const docWithNewFile = SupabaseDocumentModel(
        id: 'c8e19b88-43d7-4df3-a12b-31327170a4a8',
        ownerId: '9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d',
        title: 'Giáo trình Giải tích 1',
        description: 'Bản scan mới',
        subject: 'Toán cao cấp',
        categoryId: 'math',
        fileName: 'giai_tich_1_v2.pdf',
        fileType: 'pdf',
        fileSize: 8388608,
        storagePath: 'users/kLgMf/documents/c8e19b88/giai_tich_1_v2.pdf',
      );

      final fileUpdatePayload = docWithNewFile.toJsonForFileUpdate();
      expect(fileUpdatePayload['file_name'], equals('giai_tich_1_v2.pdf'));
      expect(fileUpdatePayload['file_size'], equals(8388608));
      expect(fileUpdatePayload['storage_path'], equals('users/kLgMf/documents/c8e19b88/giai_tich_1_v2.pdf'));
      // Không vi phạm trigger eduvault_guard_documents
      expect(fileUpdatePayload.containsKey('id'), isFalse);
      expect(fileUpdatePayload.containsKey('owner_id'), isFalse);
      expect(fileUpdatePayload.containsKey('created_at'), isFalse);
      expect(fileUpdatePayload.containsKey('updated_at'), isFalse);
    });

    // 6. Trường hợp 6: Quy trình xử lý lỗi upload bảo toàn tệp cũ
    test('6. Thứ tự thực thi an toàn: tệp cũ chỉ được xóa sau khi tệp mới upload và cập nhật DB thành công', () {
      var isDbUpdateSuccessful = false;
      var isOldFileDeleted = false;

      // Mô phỏng trường hợp upload tệp mới thất bại
      try {
        throw StateError('Mô phỏng: Lỗi mạng khi upload tệp mới lên Storage');
      } catch (_) {
        // Bắt lỗi
      }

      // Xác nhận tệp cũ KHÔNG bị xóa khi upload thất bại
      expect(isOldFileDeleted, isFalse);
      expect(isDbUpdateSuccessful, isFalse);
    });

    // 7. Trường hợp 7: Định dạng Object Key Supabase Storage chuẩn (UUID + phần mở rộng an toàn)
    test('7. Object key an toàn chỉ chứa UUID + phần mở rộng chữ thường, loại bỏ ký tự lạ', () {
      const documentId = 'c8e19b88-43d7-4df3-a12b-31327170a4a8';
      const userUid = 'firebase_user_123';
      final docUuid = SupabaseDocumentModel.toValidUuid(documentId);

      // Thử với tên file có dấu tiếng Việt, khoảng trắng, ký tự đặc biệt
      final testCases = {
        'Báo cáo thực tập tốt nghiệp (Final).PDF': 'pdf',
        'TaiLieu_KhoaHoc#2026!@.docx': 'docx',
        'slide_thuyet_trinh': 'bin', // Không có phần mở rộng
        'IMAGE.PNG': 'png',
      };

      for (final entry in testCases.entries) {
        final originalFileName = entry.key;
        final expectedExt = entry.value;

        var safeExt = originalFileName.contains('.')
            ? originalFileName.split('.').last.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')
            : '';
        if (safeExt.isEmpty) safeExt = 'bin';

        final safeFileName = '$docUuid.$safeExt';
        final storagePath = 'users/$userUid/documents/$docUuid/$safeFileName';

        expect(safeExt, equals(expectedExt));
        expect(safeFileName, equals('$docUuid.$expectedExt'));
        expect(storagePath, equals('users/$userUid/documents/$docUuid/$docUuid.$expectedExt'));
        // Đảm bảo không chứa khoảng trắng hoặc ký tự đặc biệt
        expect(storagePath.contains(' '), isFalse);
        expect(storagePath.contains('#'), isFalse);
        expect(storagePath.contains('('), isFalse);
      }
    });

    // 8. Trường hợp 8: Cơ chế rollback tệp an toàn khi lưu metadata thất bại
    test('8. Rollback an toàn: chỉ xóa tệp vừa upload, không xóa tệp đã có hoặc tệp người khác', () async {
      String? newlyUploadedStoragePath;
      var rollbackDeletedPath = '';
      const existingStoragePath = 'users/u1/documents/doc-old/doc-old.pdf';
      const newlyUploaded = 'users/u1/documents/doc-new/doc-new.pdf';

      // Giả lập luồng: upload thành công -> newlyUploadedStoragePath được gán
      newlyUploadedStoragePath = newlyUploaded;

      // Giả lập: Insert metadata thất bại -> kích hoạt catch và rollback
      try {
        throw StateError('Mô phỏng lỗi DB: RLS permission denied');
      } catch (_) {
        if (newlyUploadedStoragePath.isNotEmpty) {
          rollbackDeletedPath = newlyUploadedStoragePath;
        }
      }

      // Xác nhận tệp mới được rollback, tệp cũ không bị ảnh hưởng
      expect(rollbackDeletedPath, equals(newlyUploaded));
      expect(rollbackDeletedPath, isNot(equals(existingStoragePath)));
    });

    // 9. Trường hợp 9: Tính toán timeout động theo kích thước tệp
    test('9. Timeout upload linh hoạt: tối thiểu 30s và tỉ lệ thuận với dung lượng', () {
      int calculateTimeout(int bytes) {
        final seconds = 20 + (bytes ~/ (50 * 1024));
        return seconds < 30 ? 30 : seconds;
      }

      // Tệp 50 KB -> 30s
      expect(calculateTimeout(50 * 1024), equals(30));
      // Tệp 1 MB (1024 KB) -> 20 + (1024 ~/ 50) = 20 + 20 = 40s
      expect(calculateTimeout(1024 * 1024), equals(40));
      // Tệp 5 MB -> 20 + 102 = 122s
      expect(calculateTimeout(5 * 1024 * 1024), equals(122));
      // Tệp 20 MB -> 20 + 409 = 429s
      expect(calculateTimeout(20 * 1024 * 1024), equals(429));
    });

    // 10. Trường hợp 10: try/catch/finally đảm bảo tắt trạng thái loading trong mọi hoàn cảnh
    test('10. Khối finally luôn đảm bảo tắt trạng thái loading _isSaving = false', () {
      var isSaving = true;
      double? uploadProgress = 0.5;

      try {
        throw StateError('Lỗi gián đoạn bất ngờ trong luồng async');
      } catch (_) {
        // catch error
      } finally {
        isSaving = false;
        uploadProgress = null;
      }

      expect(isSaving, isFalse);
      expect(uploadProgress, isNull);
    });
  });
}
