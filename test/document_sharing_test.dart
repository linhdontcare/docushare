// ==============================================================================
// UNIT TESTS: document_sharing_test.dart
// Kiểm thử chức năng Chia sẻ tài liệu & Phân quyền (EduVault - LDC Edition)
// ==============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:docushare/domain/models/document_model.dart';
import 'package:docushare/domain/models/document_permission_model.dart';

void main() {
  group('Kiểm thử DocumentPermissionModel Domain Entity', () {
    test('1. Khởi tạo và kiểm tra các thuộc tính vai trò (Viewer / Editor)', () {
      const viewerPerm = DocumentPermissionModel(
        id: 'perm-1',
        documentId: 'doc-1',
        userId: 'user-2',
        permissionType: 'viewer',
        userEmail: 'student2@gmail.com',
      );

      expect(viewerPerm.isViewer, isTrue);
      expect(viewerPerm.isEditor, isFalse);
      expect(viewerPerm.displayRoleName, 'Người xem');

      const editorPerm = DocumentPermissionModel(
        id: 'perm-2',
        documentId: 'doc-1',
        userId: 'user-3',
        permissionType: 'editor',
        userEmail: 'student3@gmail.com',
      );

      expect(editorPerm.isViewer, isFalse);
      expect(editorPerm.isEditor, isTrue);
      expect(editorPerm.displayRoleName, 'Người chỉnh sửa');
    });

    test('2. Serialization JSON to/from Map với dữ liệu join từ public.users', () {
      final jsonPayload = {
        'id': 'perm-100',
        'document_id': 'doc-uuid-1',
        'user_id': 'user-uuid-recipient',
        'permission_type': 'editor',
        'granted_by': 'user-uuid-owner',
        'created_at': '2026-10-13T12:00:00.000Z',
        'updated_at': '2026-10-13T12:05:00.000Z',
        'users': {
          'id': 'user-uuid-recipient',
          'email': 'collaborator@edu.vn',
          'display_name': 'Nguyen Van B',
          'photo_url': 'https://photos.google.com/avatar.png',
        },
      };

      final model = DocumentPermissionModel.fromJson(jsonPayload);
      expect(model.id, 'perm-100');
      expect(model.documentId, 'doc-uuid-1');
      expect(model.userId, 'user-uuid-recipient');
      expect(model.isEditor, isTrue);
      expect(model.userEmail, 'collaborator@edu.vn');
      expect(model.userDisplayName, 'Nguyen Van B');
      expect(model.userPhotoUrl, 'https://photos.google.com/avatar.png');
    });

    test('3. Payload toJsonForInsert tuân thủ bảo vệ trigger Supabase guard_permissions', () {
      const perm = DocumentPermissionModel(
        id: 'perm-new',
        documentId: 'doc-123',
        userId: 'user-456',
        permissionType: 'viewer',
        grantedBy: 'should-not-be-sent',
      );

      final insertPayload = perm.toJsonForInsert();
      // Trigger guard_permissions tự động gán NEW.granted_by = current_user_id()
      expect(insertPayload.containsKey('granted_by'), isFalse);
      expect(insertPayload['document_id'], 'doc-123');
      expect(insertPayload['user_id'], 'user-456');
      expect(insertPayload['permission_type'], 'viewer');
    });

    test('4. Payload toJsonForUpdate chỉ chứa duy nhất trường permission_type', () {
      const perm = DocumentPermissionModel(
        id: 'perm-existing',
        documentId: 'doc-123',
        userId: 'user-456',
        permissionType: 'editor',
      );

      final updatePayload = perm.toJsonForUpdate();
      expect(updatePayload.length, 1);
      expect(updatePayload['permission_type'], 'editor');
    });
  });

  group('Kiểm thử Phân quyền trên DocumentModel', () {
    final baseDate = DateTime(2026, 10, 13);

    test('1. Tài liệu thuộc sở hữu của Owner có đầy đủ các quyền: xem, sửa, xóa, chia sẻ', () {
      final doc = DocumentModel(
        id: 'doc-owner',
        title: 'Báo cáo giải thuật',
        subject: 'Cấu trúc dữ liệu',
        categoryId: 'all',
        userPermissionRole: 'owner',
        createdDate: baseDate,
        updatedDate: baseDate,
      );

      expect(doc.isOwner, isTrue);
      expect(doc.isEditor, isFalse);
      expect(doc.isViewer, isFalse);
      expect(doc.canEdit, isTrue);
      expect(doc.canDelete, isTrue);
      expect(doc.canShare, isTrue);
    });

    test('2. Tài liệu được chia sẻ với quyền Editor: có thể sửa metadata, KHÔNG được xóa, KHÔNG được chia sẻ', () {
      final doc = DocumentModel(
        id: 'doc-shared-editor',
        title: 'Đề cương ôn tập',
        subject: 'Toán cao cấp',
        categoryId: 'math',
        userPermissionRole: 'editor',
        ownerEmail: 'owner@gmail.com',
        ownerName: 'Giáo viên A',
        createdDate: baseDate,
        updatedDate: baseDate,
      );

      expect(doc.isOwner, isFalse);
      expect(doc.isEditor, isTrue);
      expect(doc.isViewer, isFalse);
      expect(doc.canEdit, isTrue);
      expect(doc.canDelete, isFalse); // Bị chặn xóa
      expect(doc.canShare, isFalse); // Bị chặn chia sẻ tiếp
      expect(doc.ownerEmail, 'owner@gmail.com');
    });

    test('3. Tài liệu được chia sẻ với quyền Viewer: CHỈ XEM, không sửa, không xóa, không chia sẻ', () {
      final doc = DocumentModel(
        id: 'doc-shared-viewer',
        title: 'Slide bài giảng',
        subject: 'Nhập môn AI',
        categoryId: 'it',
        userPermissionRole: 'viewer',
        ownerEmail: 'teacher@edu.vn',
        createdDate: baseDate,
        updatedDate: baseDate,
      );

      expect(doc.isOwner, isFalse);
      expect(doc.isEditor, isFalse);
      expect(doc.isViewer, isTrue);
      expect(doc.canEdit, isFalse); // Bị chặn chỉnh sửa
      expect(doc.canDelete, isFalse); // Bị chặn xóa
      expect(doc.canShare, isFalse); // Bị chặn chia sẻ
    });

    test('4. copyWith bảo toàn thông tin vai trò quyền và chủ sở hữu', () {
      final doc = DocumentModel(
        id: 'doc-1',
        title: 'Tài liệu cũ',
        subject: 'Vật lý',
        categoryId: 'all',
        userPermissionRole: 'editor',
        ownerEmail: 'owner@gmail.com',
        createdDate: baseDate,
        updatedDate: baseDate,
      );

      final updated = doc.copyWith(title: 'Tài liệu đã cập nhật');
      expect(updated.title, 'Tài liệu đã cập nhật');
      expect(updated.userPermissionRole, 'editor');
      expect(updated.ownerEmail, 'owner@gmail.com');
      expect(updated.isEditor, isTrue);
    });
  });

  group('Kiểm thử logic Chia sẻ và Bảo vệ tính toàn vẹn', () {
    test('1. Kiểm tra chống tự chia sẻ cho chính mình qua email', () {
      const currentUserEmail = 'myaccount@gmail.com';
      const inputEmail = 'MyAccount@gmail.com';

      final isSelfSharing = inputEmail.trim().toLowerCase() == currentUserEmail.trim().toLowerCase();
      expect(isSelfSharing, isTrue);
    });

    test('2. Phân biệt danh sách Tài liệu của tôi và Tài liệu được chia sẻ', () {
      final myDocs = [
        DocumentModel(
          id: 'my-1',
          title: 'Bài tập 1',
          subject: 'Toán',
          categoryId: 'math',
          userPermissionRole: 'owner',
          createdDate: DateTime.now(),
          updatedDate: DateTime.now(),
        ),
      ];

      final sharedDocs = [
        DocumentModel(
          id: 'shared-1',
          title: 'Bài tập nhóm 2',
          subject: 'Tin học',
          categoryId: 'it',
          userPermissionRole: 'viewer',
          ownerEmail: 'friend@gmail.com',
          createdDate: DateTime.now(),
          updatedDate: DateTime.now(),
        ),
        DocumentModel(
          id: 'shared-2',
          title: 'Dự án chung',
          subject: 'Kỹ thuật phần mềm',
          categoryId: 'it',
          userPermissionRole: 'editor',
          ownerEmail: 'lead@gmail.com',
          createdDate: DateTime.now(),
          updatedDate: DateTime.now(),
        ),
      ];

      // Đảm bảo không bị lẫn lộn giữa hai tập dữ liệu
      expect(myDocs.every((d) => d.isOwner), isTrue);
      expect(sharedDocs.every((d) => !d.isOwner), isTrue);
      expect(sharedDocs.where((d) => d.isEditor).length, 1);
      expect(sharedDocs.where((d) => d.isViewer).length, 1);
    });
  });
}
