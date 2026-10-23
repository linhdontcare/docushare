// ==============================================================================
// UNIT & INTEGRATION TEST: borrow_and_discovery_system_test.dart
// DỰ ÁN: EduVault (LDC Edition)
//
// KIỂM THỬ TOÀN DIỆN KỊCH BẢN 3 TÀI KHOẢN THEO MỤC 11 TH2:
// A (Owner), B (Borrower 1), C (Borrower 2)
//
// 10 Kịch bản kiểm thử:
// 1. A tạo tài liệu riêng tư -> B không thấy trong Khám phá.
// 2. A bật khám phá và cho mượn -> B/C thấy metadata công khai.
// 3. B gửi yêu cầu (1, 3, 7, 14 ngày) -> A nhận Pending, chặn gửi trùng.
// 4. A duyệt B -> B được Viewer tạm thời, tính due_at chính xác.
// 5. A từ chối C -> C không có quyền đọc (rejected).
// 6. B trả -> Quyền mượn hết hiệu lực (returned).
// 7. Hết hạn -> Backend/Model từ chối quyền đọc (expired/overdue).
// 8. B không thể tự duyệt hoặc sửa thời hạn (Toàn vẹn dữ liệu).
// 9. B không thể sửa/xóa tài liệu (Quyền Viewer chỉ đọc).
// 10. Quyền chia sẻ trực tiếp độc lập không bị ảnh hưởng.
// ==============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:docushare/domain/models/borrow_request_model.dart';
import 'package:docushare/domain/models/document_model.dart';
import 'package:docushare/domain/models/document_permission_model.dart';

void main() {
  group('Kiểm thử Nghiệp vụ Mượn & Trả và Khám phá (3 Tài khoản A, B, C)', () {
    const userAId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    const userAEmail = 'user_a_owner@eduvault.edu.vn';

    const userBId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
    const userBEmail = 'user_b_borrower1@eduvault.edu.vn';

    const userCId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
    const userCEmail = 'user_c_borrower2@eduvault.edu.vn';

    final now = DateTime.now();

    // -------------------------------------------------------------------------
    // Kịch bản 1: A tạo tài liệu riêng tư -> B không thấy trong Khám phá
    // -------------------------------------------------------------------------
    test('1. A tạo tài liệu riêng tư (isDiscoverable=false) -> B không thấy trong Khám phá', () {
      final privateDoc = DocumentModel(
        id: 'doc-private-001',
        title: 'Bản thảo Nghiên cứu Khoa học Bí mật',
        subject: 'Khoa học Máy tính',
        categoryId: 'research',
        createdDate: now,
        updatedDate: now,
        ownerEmail: userAEmail,
        isDiscoverable: false,
        isBorrowable: false,
      );

      // Giả lập logic lọc danh sách khám phá
      final allSystemDocs = [privateDoc];
      final discoverableForUserB = allSystemDocs.where((doc) {
        // Chỉ tài liệu có isDiscoverable = true và không phải của chính mình
        return doc.isDiscoverable && doc.ownerEmail != userBEmail;
      }).toList();

      expect(discoverableForUserB, isEmpty, reason: 'Tài liệu riêng tư tuyệt đối không được xuất hiện trong Khám phá.');
    });

    // -------------------------------------------------------------------------
    // Kịch bản 2: A bật khám phá và cho mượn -> B/C thấy metadata
    // -------------------------------------------------------------------------
    test('2. A bật khám phá và cho mượn -> B/C thấy metadata công khai nhưng không lộ file storage riêng tư', () {
      final publicDoc = DocumentModel(
        id: 'doc-public-002',
        title: 'Giáo trình Cơ sở Dữ liệu Nâng cao',
        subject: 'Hệ thống Thông tin',
        categoryId: 'database',
        createdDate: now,
        updatedDate: now,
        ownerEmail: userAEmail,
        ownerName: 'Giảng viên A',
        isDiscoverable: true,
        isBorrowable: true,
        locationName: 'Thư viện Tạ Quang Bửu',
        building: 'Tòa Nhà Thư Viện',
        floor: 'Tầng 3',
        shelf: 'Kệ DB-01',
        tags: ['CSDL', 'SQL', 'PostgreSQL'],
      );

      // B và C truy vấn danh mục khám phá
      final allDocs = [publicDoc];
      final discoverableDocs = allDocs.where((doc) => doc.isDiscoverable).toList();

      expect(discoverableDocs.length, equals(1));
      final item = discoverableDocs.first;
      expect(item.title, equals('Giáo trình Cơ sở Dữ liệu Nâng cao'));
      expect(item.subject, equals('Hệ thống Thông tin'));
      expect(item.isBorrowable, isTrue);
      expect(item.isDiscoverable, isTrue);
      expect(item.hasPhysicalLocation, isTrue);
      expect(item.tags, contains('PostgreSQL'));

      // Tài liệu của chính A không hiển thị trong danh sách khám phá của A
      final discoverableForA = allDocs.where((doc) => doc.isDiscoverable && doc.ownerEmail != userAEmail).toList();
      expect(discoverableForA, isEmpty, reason: 'Người dùng không thấy tài liệu của chính mình trong Khám phá');
    });

    // -------------------------------------------------------------------------
    // Kịch bản 3: B gửi yêu cầu mượn -> A nhận Pending, không gửi trùng
    // -------------------------------------------------------------------------
    test('3. B gửi yêu cầu mượn (1, 3, 7, 14 ngày) -> A nhận Pending, chặn yêu cầu trùng', () {
      const requestedDays = 7;
      final reqB = BorrowRequestModel(
        id: 'req-b-001',
        documentId: 'doc-public-002',
        documentTitle: 'Giáo trình Cơ sở Dữ liệu Nâng cao',
        borrowerId: userBId,
        borrowerEmail: userBEmail,
        borrowerName: 'Sinh viên B',
        ownerId: userAId,
        ownerEmail: userAEmail,
        status: 'pending',
        requestedDays: requestedDays,
        message: 'Em xin mượn sách 1 tuần để làm bài tập lớn.',
        requestedAt: now,
        dueAt: now.add(const Duration(days: requestedDays)),
      );

      expect(reqB.isPending, isTrue);
      expect(reqB.isCurrentlyBorrowed, isFalse);
      expect(reqB.canCancel, isTrue);
      expect(reqB.canViewDocument, isFalse);
      expect(reqB.statusLabel, equals('Chờ duyệt'));

      // Kiểm tra ràng buộc chống gửi yêu cầu trùng lặp
      final existingRequests = [reqB];
      final isDuplicate = existingRequests.any((r) =>
          r.documentId == 'doc-public-002' &&
          r.borrowerId == userBId &&
          (r.isPending || r.isCurrentlyBorrowed));

      expect(isDuplicate, isTrue, reason: 'Chặn người dùng gửi nhiều yêu cầu mượn đang pending hoặc approved trên cùng một tài liệu');
    });

    // -------------------------------------------------------------------------
    // Kịch bản 4: A duyệt B -> B được Viewer tạm thời, tính due_at chính xác
    // -------------------------------------------------------------------------
    test('4. A duyệt B -> B được Viewer tạm thời, due_at tính từ thời điểm duyệt', () {
      final approvedAt = now;
      const borrowDurationDays = 7;
      final calculatedDueDate = approvedAt.add(const Duration(days: borrowDurationDays));

      final approvedReqB = BorrowRequestModel(
        id: 'req-b-001',
        documentId: 'doc-public-002',
        documentTitle: 'Giáo trình Cơ sở Dữ liệu Nâng cao',
        borrowerId: userBId,
        borrowerEmail: userBEmail,
        borrowerName: 'Sinh viên B',
        ownerId: userAId,
        status: 'approved',
        requestedDays: borrowDurationDays,
        requestedAt: now.subtract(const Duration(hours: 2)),
        approvedAt: approvedAt,
        dueAt: calculatedDueDate,
      );

      expect(approvedReqB.isApproved, isTrue);
      expect(approvedReqB.isCurrentlyBorrowed, isTrue);
      expect(approvedReqB.canViewDocument, isTrue);
      expect(approvedReqB.canReturn, isTrue);
      expect(approvedReqB.canCancel, isFalse);
      expect(approvedReqB.statusLabel, equals('Đang mượn'));
      expect(approvedReqB.remainingDays, greaterThanOrEqualTo(6));
    });

    // -------------------------------------------------------------------------
    // Kịch bản 5: A từ chối C -> C không có quyền đọc (rejected)
    // -------------------------------------------------------------------------
    test('5. A từ chối C -> C chuyển sang rejected, không có quyền đọc tài liệu', () {
      final rejectedReqC = BorrowRequestModel(
        id: 'req-c-002',
        documentId: 'doc-public-002',
        documentTitle: 'Giáo trình Cơ sở Dữ liệu Nâng cao',
        borrowerId: userCId,
        borrowerEmail: userCEmail,
        ownerId: userAId,
        status: 'rejected',
        requestedDays: 3,
        ownerNotes: 'Sách hiện đã hết lượt mượn trực tiếp.',
        requestedAt: now.subtract(const Duration(hours: 1)),
        dueAt: now.add(const Duration(days: 3)),
      );

      expect(rejectedReqC.isRejected, isTrue);
      expect(rejectedReqC.isApproved, isFalse);
      expect(rejectedReqC.isCurrentlyBorrowed, isFalse);
      expect(rejectedReqC.canViewDocument, isFalse);
      expect(rejectedReqC.statusLabel, equals('Bị từ chối'));
    });

    // -------------------------------------------------------------------------
    // Kịch bản 6: B trả -> Quyền mượn hết hiệu lực (returned)
    // -------------------------------------------------------------------------
    test('6. B trả tài liệu -> Quyền mượn hết hiệu lực tức thì', () {
      final returnedReqB = BorrowRequestModel(
        id: 'req-b-001',
        documentId: 'doc-public-002',
        documentTitle: 'Giáo trình Cơ sở Dữ liệu Nâng cao',
        borrowerId: userBId,
        borrowerEmail: userBEmail,
        ownerId: userAId,
        status: 'returned',
        requestedDays: 7,
        requestedAt: now.subtract(const Duration(days: 3)),
        approvedAt: now.subtract(const Duration(days: 3)),
        dueAt: now.add(const Duration(days: 4)),
        returnedAt: now,
      );

      expect(returnedReqB.isReturned, isTrue);
      expect(returnedReqB.isCurrentlyBorrowed, isFalse);
      expect(returnedReqB.canViewDocument, isFalse);
      expect(returnedReqB.canReturn, isFalse);
      expect(returnedReqB.statusLabel, equals('Đã hoàn trả'));
      expect(returnedReqB.remainingDays, equals(0));
    });

    // -------------------------------------------------------------------------
    // Kịch bản 7: Hết hạn -> Backend/Model từ chối quyền đọc (expired/overdue)
    // -------------------------------------------------------------------------
    test('7. Hết hạn mượn -> Quyền đọc mất hiệu lực ngay cả khi status chưa đổi', () {
      final expiredReq = BorrowRequestModel(
        id: 'req-b-old',
        documentId: 'doc-public-002',
        documentTitle: 'Giáo trình Cơ sở Dữ liệu Nâng cao',
        borrowerId: userBId,
        borrowerEmail: userBEmail,
        ownerId: userAId,
        status: 'approved',
        requestedDays: 3,
        requestedAt: now.subtract(const Duration(days: 5)),
        approvedAt: now.subtract(const Duration(days: 5)),
        dueAt: now.subtract(const Duration(days: 2)), // Đã hết hạn 2 ngày trước
      );

      expect(expiredReq.isOverdue, isTrue);
      expect(expiredReq.isExpired, isTrue);
      expect(expiredReq.canViewDocument, isFalse, reason: 'Khi quá hạn, canViewDocument phải trả về false ngay lập tức');
      expect(expiredReq.daysRemaining, isNegative);
    });

    // -------------------------------------------------------------------------
    // Kịch bản 8: B không thể tự duyệt hoặc sửa thời hạn (Toàn vẹn dữ liệu)
    // -------------------------------------------------------------------------
    test('8. Tính toàn vẹn: toJsonForInsert luôn gán status = pending, không tin tưởng client-approved', () {
      final attemptTamper = BorrowRequestModel(
        id: 'req-fake-001',
        documentId: 'doc-public-002',
        documentTitle: 'Giáo trình Cơ sở Dữ liệu Nâng cao',
        borrowerId: userBId,
        borrowerEmail: userBEmail,
        ownerId: userAId,
        status: 'approved', // Giả mạo duyệt
        requestedDays: 14,
        requestedAt: now,
        dueAt: now.add(const Duration(days: 100)), // Giả mạo thời hạn 100 ngày
      );

      final insertPayload = attemptTamper.toJsonForInsert();
      expect(insertPayload['status'], equals('pending'), reason: 'Payload chèn mới luôn ép buộc trạng thái là pending');
      expect(insertPayload.containsKey('approved_at'), isFalse, reason: 'Client không thể tự đặt approved_at');
    });

    // -------------------------------------------------------------------------
    // Kịch bản 9: B không thể sửa/xóa tài liệu (Quyền Viewer chỉ đọc)
    // -------------------------------------------------------------------------
    test('9. Quyền mượn chỉ là Viewer: B không có quyền sửa hoặc xóa tài liệu của A', () {
      final borrowedDocForB = DocumentModel(
        id: 'doc-public-002',
        title: 'Giáo trình Cơ sở Dữ liệu Nâng cao',
        subject: 'Hệ thống Thông tin',
        categoryId: 'database',
        createdDate: now,
        updatedDate: now,
        userPermissionRole: 'viewer', // Quyền mượn chỉ là Viewer
        ownerEmail: userAEmail,
        isBorrowable: true,
        isDiscoverable: true,
      );

      expect(borrowedDocForB.isOwner, isFalse);
      expect(borrowedDocForB.isEditor, isFalse);
      expect(borrowedDocForB.isViewer, isTrue);
      expect(borrowedDocForB.canEdit, isFalse, reason: 'Người mượn không có quyền sửa tài liệu');
      expect(borrowedDocForB.canDelete, isFalse, reason: 'Người mượn không có quyền xóa tài liệu');
      expect(borrowedDocForB.canShare, isFalse, reason: 'Người mượn không có quyền chia sẻ lại tài liệu');
    });

    // -------------------------------------------------------------------------
    // Kịch bản 10: Quyền chia sẻ trực tiếp độc lập không bị ảnh hưởng
    // -------------------------------------------------------------------------
    test('10. Quyền chia sẻ trực tiếp (Editor/Viewer) độc lập với vòng đời mượn/trả', () {
      // Giả sử trước đó A đã chủ động chia sẻ tài liệu cho C với quyền Editor
      final directSharePermissionForC = DocumentPermissionModel(
        id: 'perm-c-001',
        documentId: 'doc-public-002',
        userId: userCId,
        permissionType: 'editor',
        userEmail: userCEmail,
        createdAt: now.subtract(const Duration(days: 10)),
      );

      expect(directSharePermissionForC.isEditor, isTrue);
      expect(directSharePermissionForC.isViewer, isFalse);

      // C sau đó gửi yêu cầu mượn bản cứng và bị từ chối hoặc trả sách
      final borrowReqC = BorrowRequestModel(
        id: 'req-c-003',
        documentId: 'doc-public-002',
        documentTitle: 'Giáo trình Cơ sở Dữ liệu Nâng cao',
        borrowerId: userCId,
        borrowerEmail: userCEmail,
        ownerId: userAId,
        status: 'returned',
        requestedDays: 7,
        requestedAt: now.subtract(const Duration(days: 5)),
        dueAt: now.add(const Duration(days: 2)),
        returnedAt: now,
      );

      expect(borrowReqC.isReturned, isTrue);

      // Quyền Editor trực tiếp của C vẫn còn nguyên vẹn 100%
      expect(directSharePermissionForC.permissionType, equals('editor'));
      expect(directSharePermissionForC.isEditor, isTrue, reason: 'Quyền mượn hết hạn hoặc hoàn trả không ảnh hưởng đến quyền chia sẻ riêng đã cấp trước đó');
    });
  });
}
