import 'package:flutter_test/flutter_test.dart';
import 'package:docushare/domain/models/document_model.dart';
import 'package:docushare/domain/models/supabase_document_model.dart';

void main() {
  group('SupabaseDocumentModel Domain Entity Tests', () {
    test('Xác thực UUID hợp lệ và ánh xạ tất định UUID v5 cho ID cũ', () {
      const validUuid = 'c8e19b88-43d7-4df3-a12b-31327170a4a8';
      expect(SupabaseDocumentModel.isValidUuid(validUuid), isTrue);
      expect(SupabaseDocumentModel.toValidUuid(validUuid), equals(validUuid));

      // ID cũ không phải UUID (vd: 'old_doc_123')
      const legacyId = 'old_doc_123';
      expect(SupabaseDocumentModel.isValidUuid(legacyId), isFalse);

      final normalizedUuid1 = SupabaseDocumentModel.toValidUuid(legacyId);
      final normalizedUuid2 = SupabaseDocumentModel.toValidUuid(legacyId);

      // Đảm bảo kết quả là UUID hợp lệ và nhất quán (tất định)
      expect(SupabaseDocumentModel.isValidUuid(normalizedUuid1), isTrue);
      expect(normalizedUuid1, equals(normalizedUuid2));
    });

    test('toJsonForInsert bao gồm đầy đủ các trường bắt buộc của public.documents', () {
      const doc = SupabaseDocumentModel(
        id: 'c8e19b88-43d7-4df3-a12b-31327170a4a8',
        ownerId: '9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d',
        title: 'Tài liệu Ôn tập Toán Cao cấp',
        description: 'Chương 1 và 2',
        subject: 'Toán cao cấp',
        categoryId: 'math',
        fileName: 'toan_cao_cap.pdf',
        fileType: 'pdf',
        fileSize: 1048576,
        storagePath: 'users/kLgMf/documents/c8e19b88/toan_cao_cap.pdf',
      );

      final json = doc.toJsonForInsert();

      expect(json['id'], equals('c8e19b88-43d7-4df3-a12b-31327170a4a8'));
      expect(json['owner_id'], equals('9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d'));
      expect(json['title'], equals('Tài liệu Ôn tập Toán Cao cấp'));
      expect(json['description'], equals('Chương 1 và 2'));
      expect(json['subject'], equals('Toán cao cấp'));
      expect(json['category_id'], equals('math'));
      expect(json['file_name'], equals('toan_cao_cap.pdf'));
      expect(json['file_type'], equals('pdf'));
      expect(json['file_size'], equals(1048576));
      expect(json['storage_path'], equals('users/kLgMf/documents/c8e19b88/toan_cao_cap.pdf'));

      // Đảm bảo không chứa timestamps vì server PostgreSQL tự sinh now()
      expect(json.containsKey('created_at'), isFalse);
      expect(json.containsKey('updated_at'), isFalse);
    });

    test('toJsonForUpdate TUYỆT ĐỐI KHÔNG chứa id, owner_id, created_at, updated_at', () {
      const doc = SupabaseDocumentModel(
        id: 'c8e19b88-43d7-4df3-a12b-31327170a4a8',
        ownerId: '9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d',
        title: 'Tài liệu Tiếng Anh B1 Cập nhật',
        description: 'Ghi chú mới',
        subject: 'Tiếng Anh',
        categoryId: 'english',
        fileName: 'english.pdf',
        fileType: 'pdf',
        fileSize: 2048,
        storagePath: 'users/kLgMf/documents/c8e19b88/english.pdf',
      );

      final updatePayload = doc.toJsonForUpdate();

      // Chỉ được chứa đúng 4 trường metadata cho phép
      expect(updatePayload.keys, containsAll(['title', 'description', 'subject', 'category_id']));
      expect(updatePayload.length, equals(4));

      // Ngăn chặn vi phạm trigger eduvault_guard_documents
      expect(updatePayload.containsKey('id'), isFalse);
      expect(updatePayload.containsKey('owner_id'), isFalse);
      expect(updatePayload.containsKey('created_at'), isFalse);
      expect(updatePayload.containsKey('updated_at'), isFalse);
      expect(updatePayload.containsKey('storage_path'), isFalse);
      expect(updatePayload.containsKey('file_name'), isFalse);
      expect(updatePayload.containsKey('file_size'), isFalse);
    });

    test('toJsonForFileUpdate bao gồm cả thông tin tệp mới nhưng bảo vệ id, owner_id, timestamps', () {
      const doc = SupabaseDocumentModel(
        id: 'c8e19b88-43d7-4df3-a12b-31327170a4a8',
        ownerId: '9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d',
        title: 'Tài liệu Thay tệp mới',
        description: 'Đã cập nhật file PDF mới',
        subject: 'Vật lý 1',
        categoryId: 'physics',
        fileName: 'vat_ly_moi.pdf',
        fileType: 'pdf',
        fileSize: 3145728,
        storagePath: 'users/kLgMf/documents/c8e19b88/vat_ly_moi.pdf',
      );

      final fileUpdatePayload = doc.toJsonForFileUpdate();

      // Phải có 8 trường: 4 metadata cơ bản + 4 trường thông tin file mới
      expect(
        fileUpdatePayload.keys,
        containsAll([
          'title',
          'description',
          'subject',
          'category_id',
          'file_name',
          'file_type',
          'file_size',
          'storage_path',
        ]),
      );
      expect(fileUpdatePayload.length, equals(8));
      expect(fileUpdatePayload['file_name'], equals('vat_ly_moi.pdf'));
      expect(fileUpdatePayload['file_size'], equals(3145728));
      expect(fileUpdatePayload['storage_path'], equals('users/kLgMf/documents/c8e19b88/vat_ly_moi.pdf'));

      // Tuyệt đối không gửi id, owner_id, timestamps vi phạm trigger eduvault_guard_documents
      expect(fileUpdatePayload.containsKey('id'), isFalse);
      expect(fileUpdatePayload.containsKey('owner_id'), isFalse);
      expect(fileUpdatePayload.containsKey('created_at'), isFalse);
      expect(fileUpdatePayload.containsKey('updated_at'), isFalse);
    });

    test('Khởi tạo từ DocumentModel với tài liệu web link và kích thước 0', () {
      final domainDoc = DocumentModel(
        id: 'web_link_101',
        title: 'Trang tài liệu Wikipedia',
        subject: 'Lịch sử',
        categoryId: 'history',
        filePathOrUrl: 'https://vi.wikipedia.org/wiki/L%E1%BB%8Bch_s%E1%BB%AD',
        notes: 'Liên kết tham khảo thêm',
        createdDate: DateTime(2026, 1, 1),
        updatedDate: DateTime(2026, 1, 2),
      );

      final supabaseDoc = SupabaseDocumentModel.fromDomain(
        doc: domainDoc,
        ownerId: '9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d',
        storagePath: domainDoc.filePathOrUrl!,
        fileName: 'Wikipedia Lịch sử',
        fileType: 'link',
        fileSize: 0,
      );

      expect(SupabaseDocumentModel.isValidUuid(supabaseDoc.id), isTrue);
      expect(supabaseDoc.fileSize, equals(0));
      expect(supabaseDoc.fileType, equals('link'));
      expect(supabaseDoc.storagePath, startsWith('https://'));
    });

    test('fromJson giải mã chính xác dữ liệu trả về từ Supabase PostgREST', () {
      final rawPostgrestResponse = {
        'id': 'c8e19b88-43d7-4df3-a12b-31327170a4a8',
        'owner_id': '9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d',
        'title': 'Giáo trình Giải tích 1',
        'description': 'Bản scan PDF chất lượng cao',
        'subject': 'Toán',
        'category_id': 'all',
        'file_name': 'giai_tich_1.pdf',
        'file_type': 'pdf',
        'file_size': 5242880,
        'storage_path': 'users/uid123/documents/c8e19b88/giai_tich_1.pdf',
        'created_at': '2026-10-13T07:00:00.000Z',
        'updated_at': '2026-10-13T07:30:00.000Z',
      };

      final parsedDoc = SupabaseDocumentModel.fromJson(rawPostgrestResponse);

      expect(parsedDoc.id, equals('c8e19b88-43d7-4df3-a12b-31327170a4a8'));
      expect(parsedDoc.ownerId, equals('9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d'));
      expect(parsedDoc.title, equals('Giáo trình Giải tích 1'));
      expect(parsedDoc.fileSize, equals(5242880));
      expect(parsedDoc.createdAt, isNotNull);
      expect(parsedDoc.updatedAt, isNotNull);
    });
  });
}
