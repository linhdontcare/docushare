// ==============================================================================
// WIDGET TEST: share_document_dialog_responsive_test.dart
// Kiểm thử giao diện thích ứng & chống tràn RenderFlex của ShareDocumentDialog
// - Màn hình chuẩn (412 x 892)
// - Màn hình nhỏ (320 x 480)
// - Màn hình compact (360 x 640)
// - Khi bàn phím xuất hiện (viewInsets.bottom = 300)
// - Kiểm tra form validation và tương tác chọn vai trò Viewer / Editor
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docushare/domain/models/document_model.dart';
import 'package:docushare/presentation/widgets/share_document_dialog.dart';

void main() {
  final sampleDocument = DocumentModel(
    id: 'doc-uuid-test-12345',
    title: 'Giáo trình Cấu trúc dữ liệu và Giải thuật nâng cao phiên bản 2026',
    subject: 'Khoa học máy tính',
    categoryId: 'cat-textbooks',
    categoryName: 'Sách giáo trình',
    filePathOrUrl: 'users/user-owner-uuid-1/documents/doc-uuid-test-12345/dsa.pdf',
    createdDate: DateTime.now(),
    updatedDate: DateTime.now(),
    userPermissionRole: 'owner',
    ownerEmail: 'owner@gmail.com',
  );

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => child,
              );
            },
            child: const Text('Mở Dialog'),
          ),
        ),
      ),
    );
  }

  group('ShareDocumentDialog Responsive & Overflow Tests', () {
    testWidgets('1. Hiển thị hoàn hảo trên màn hình chuẩn 412x892 mà không bị RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(412, 892);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestableWidget(
          ShareDocumentDialog(
            document: sampleDocument,
            currentUserEmail: 'owner@gmail.com',
          ),
        ),
      );

      // Nhấn mở dialog
      await tester.tap(find.text('Mở Dialog'));
      await tester.pumpAndSettle();

      // Kiểm tra các phần tử cốt lõi xuất hiện đầy đủ
      expect(find.text('Chia sẻ tài liệu'), findsOneWidget);
      expect(find.text(sampleDocument.title), findsOneWidget);
      expect(find.text('Thêm người nhận bằng email:'), findsOneWidget);
      expect(find.text('Người xem'), findsOneWidget);
      expect(find.text('Người chỉnh sửa'), findsOneWidget);
      expect(find.text('Cấp quyền chia sẻ'), findsOneWidget);
      expect(find.text('Đang được chia sẻ với:'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('2. Thích ứng hoàn hảo trên màn hình nhỏ 320x480 không gây RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestableWidget(
          ShareDocumentDialog(
            document: sampleDocument,
            currentUserEmail: 'owner@gmail.com',
          ),
        ),
      );

      await tester.tap(find.text('Mở Dialog'));
      await tester.pumpAndSettle();

      // Kiểm tra không có bất kỳ lỗi tràn màn hình nào được ném ra
      expect(tester.takeException(), isNull);
      expect(find.text('Chia sẻ tài liệu'), findsOneWidget);
      expect(find.text('Cấp quyền chia sẻ'), findsOneWidget);
    });

    testWidgets('3. Thích ứng khi bàn phím ảo xuất hiện (viewInsets.bottom = 300) trên màn hình 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });

      await tester.pumpWidget(
        buildTestableWidget(
          ShareDocumentDialog(
            document: sampleDocument,
            currentUserEmail: 'owner@gmail.com',
          ),
        ),
      );

      await tester.tap(find.text('Mở Dialog'));
      await tester.pumpAndSettle();

      // Đảm bảo không bị tràn dưới khi có bàn phím ảo
      expect(tester.takeException(), isNull);
      expect(find.text('Chia sẻ tài liệu'), findsOneWidget);
    });

    testWidgets('4. Tương tác chọn vai trò (Viewer <-> Editor) và validation form email', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestableWidget(
          ShareDocumentDialog(
            document: sampleDocument,
            currentUserEmail: 'owner@gmail.com',
          ),
        ),
      );

      await tester.tap(find.text('Mở Dialog'));
      await tester.pumpAndSettle();

      // 4.1 Chuyển vai trò sang 'Người chỉnh sửa'
      await tester.tap(find.text('Người chỉnh sửa'));
      await tester.pumpAndSettle();

      // 4.2 Nhấn 'Cấp quyền chia sẻ' khi chưa nhập email -> báo lỗi validation
      await tester.tap(find.text('Cấp quyền chia sẻ'));
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập email người nhận'), findsOneWidget);

      // 4.3 Nhập email sai định dạng
      final emailInput = find.byType(TextFormField);
      await tester.enterText(emailInput, 'emailsai');
      await tester.tap(find.text('Cấp quyền chia sẻ'));
      await tester.pumpAndSettle();

      expect(find.text('Email không đúng định dạng'), findsOneWidget);

      // 4.4 Nhập email chính chủ -> báo lỗi không thể tự chia sẻ
      await tester.enterText(emailInput, 'owner@gmail.com');
      await tester.tap(find.text('Cấp quyền chia sẻ'));
      await tester.pumpAndSettle();

      expect(find.text('Bạn là chủ sở hữu, không thể tự chia sẻ tài liệu cho chính mình.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
