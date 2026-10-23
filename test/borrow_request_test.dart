// ==============================================================================
// UNIT TEST: borrow_request_test.dart
// Kiểm thử nghiệp vụ Mượn / Trả tài liệu (BorrowRequestModel)
// - Vòng đời trạng thái: pending -> approved / rejected -> returned
// - Tính toán số ngày còn lại (daysRemaining) và quá hạn (isOverdue)
// - Ánh xạ JSON với Supabase PostgREST
// ==============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:docushare/domain/models/borrow_request_model.dart';

void main() {
  group('BorrowRequestModel Workflow & Business Logic Tests', () {
    final now = DateTime.now();

    test('Khởi tạo trạng thái ban đầu "pending" chính xác', () {
      final req = BorrowRequestModel(
        id: 'req-001',
        documentId: 'doc-001',
        documentTitle: 'Sách Cấu trúc dữ liệu và giải thuật',
        requesterId: 'user-req-1',
        requesterEmail: 'sinhvien@hust.edu.vn',
        ownerId: 'user-owner-1',
        status: 'pending',
        requestDate: now,
        dueDate: now.add(const Duration(days: 14)),
      );

      expect(req.isPending, isTrue);
      expect(req.isApproved, isFalse);
      expect(req.isRejected, isFalse);
      expect(req.isReturned, isFalse);
      expect(req.isCurrentlyBorrowed, isFalse);
      expect(req.statusDisplay, equals('Chờ duyệt'));
      expect(req.daysRemaining, greaterThanOrEqualTo(13));
      expect(req.isOverdue, isFalse);
    });

    test('Trạng thái "approved" chuyển sang đang mượn', () {
      final req = BorrowRequestModel(
        id: 'req-002',
        documentId: 'doc-001',
        documentTitle: 'Sách Giải tích',
        requesterId: 'user-req-1',
        requesterEmail: 'sinhvien@hust.edu.vn',
        ownerId: 'user-owner-1',
        status: 'approved',
        requestDate: now.subtract(const Duration(days: 2)),
        dueDate: now.add(const Duration(days: 7)),
      );

      expect(req.isPending, isFalse);
      expect(req.isApproved, isTrue);
      expect(req.isCurrentlyBorrowed, isTrue);
      expect(req.statusDisplay, equals('Đang mượn'));
      expect(req.isOverdue, isFalse);
    });

    test('Phát hiện quá hạn mượn (Overdue Detection)', () {
      final req = BorrowRequestModel(
        id: 'req-003',
        documentId: 'doc-001',
        documentTitle: 'Giáo trình Vật lý đại cương',
        requesterId: 'user-req-1',
        requesterEmail: 'sinhvien@hust.edu.vn',
        ownerId: 'user-owner-1',
        status: 'approved',
        requestDate: now.subtract(const Duration(days: 20)),
        dueDate: now.subtract(const Duration(days: 2)), // Đã quá hạn 2 ngày
      );

      expect(req.isCurrentlyBorrowed, isTrue);
      expect(req.isOverdue, isTrue);
      expect(req.daysRemaining, isNegative);
    });

    test('Trạng thái "returned" đã hoàn tất không còn tính quá hạn', () {
      final req = BorrowRequestModel(
        id: 'req-004',
        documentId: 'doc-001',
        documentTitle: 'Giáo trình Hóa đại cương',
        requesterId: 'user-req-1',
        requesterEmail: 'sinhvien@hust.edu.vn',
        ownerId: 'user-owner-1',
        status: 'returned',
        requestDate: now.subtract(const Duration(days: 30)),
        dueDate: now.subtract(const Duration(days: 10)),
        returnDate: now.subtract(const Duration(days: 9)),
      );

      expect(req.isReturned, isTrue);
      expect(req.isCurrentlyBorrowed, isFalse);
      expect(req.isOverdue, isFalse);
      expect(req.statusDisplay, equals('Đã hoàn trả'));
    });

    test('Tuần tự hóa JSON (toJsonForInsert) tuân thủ RLS Supabase', () {
      final req = BorrowRequestModel(
        id: 'c879d722-1d5b-4d4a-9b48-8dfca87c0e81',
        documentId: '3f6e1f0e-2495-4eb8-b99b-dca6823bb9a1',
        documentTitle: 'Kiến trúc máy tính',
        requesterId: '7d56e727-4a57-4148-9f37-1249b6b797f1',
        requesterEmail: 'user@edu.vn',
        ownerId: '8e67f838-5b68-4259-af48-2350c7c808f2',
        requestDate: now,
        dueDate: now.add(const Duration(days: 14)),
        notes: 'Em muốn mượn ôn thi cuối kỳ',
      );

      final json = req.toJsonForInsert();

      expect(json['id'], equals('c879d722-1d5b-4d4a-9b48-8dfca87c0e81'));
      expect(json['document_id'], equals('3f6e1f0e-2495-4eb8-b99b-dca6823bb9a1'));
      expect(json['requester_id'], equals('7d56e727-4a57-4148-9f37-1249b6b797f1'));
      expect(json['owner_id'], equals('8e67f838-5b68-4259-af48-2350c7c808f2'));
      expect(json['status'], equals('pending'));
      expect(json['notes'], equals('Em muốn mượn ôn thi cuối kỳ'));
    });
  });
}
