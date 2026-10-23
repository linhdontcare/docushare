// ==============================================================================
// TEST: document_detail_and_location_test.dart
// Kiểm thử chuyên sâu:
// 1. Model Vị trí chi tiết (DocumentModel & SupabaseDocumentModel)
// 2. Màn hình Chi tiết tài liệu (DocumentDetailScreen):
//    - Tách biệt "Xem file" và "Xem vị trí"
//    - Hiển thị đầy đủ thông tin: tên, mô tả, môn học, tags, file, location
//    - Trạng thái "Chưa thiết lập vị trí" khi không có dữ liệu (không hiển thị dữ liệu giả)
//    - Phân quyền Viewer không được Edit/Delete/Share
//    - Responsive (Mobile 400px & Web 1200px không bị RenderFlex overflow)
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:docushare/domain/models/document_model.dart';
import 'package:docushare/domain/models/supabase_document_model.dart';
import 'package:docushare/presentation/screens/document_detail_screen.dart';
import 'package:docushare/domain/models/borrow_request_model.dart';
import 'package:docushare/presentation/providers/document_provider.dart';

class MockDocumentProvider extends ChangeNotifier implements DocumentProvider {
  @override
  List<DocumentModel> documents = [];
  @override
  List<DocumentModel> sharedDocuments = [];
  @override
  List<BorrowRequestModel> myBorrowRequests = [];
  @override
  List<BorrowRequestModel> incomingBorrowRequests = [];
  @override
  List<DocumentModel> discoverableDocuments = [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('1. DocumentModel Detailed Location Unit Tests', () {
    test('Khởi tạo với thông tin vị trí phân cấp và định dạng địa chỉ đầy đủ', () {
      final doc = DocumentModel(
        id: 'doc-loc-01',
        title: 'Giáo trình Kiến trúc Máy tính',
        subject: 'Khoa học máy tính',
        categoryId: 'cat-cs',
        categoryName: 'Công nghệ thông tin',
        notes: 'Sách bìa cứng tham khảo cho sinh viên năm 2',
        tags: ['hardware', 'cpu', 'assembly'],
        locationName: 'Thư viện Trung tâm ĐHQG',
        building: 'Nhà A1',
        floor: 'Tầng 3',
        shelf: 'Kệ K-08',
        latitude: 10.8700,
        longitude: 106.8031,
        locationNotes: 'Mượn đọc tại chỗ phòng tự học',
        createdDate: DateTime(2026, 1, 15),
        updatedDate: DateTime(2026, 1, 16),
      );

      expect(doc.hasPhysicalLocation, isTrue);
      expect(doc.hasCoordinates, isTrue);
      expect(doc.displayLocationName, equals('Thư viện Trung tâm ĐHQG'));
      expect(doc.googleMapsUrl, contains('10.87,106.8031'));

      final fullAddress = doc.formattedLocationAddress;
      expect(fullAddress, contains('Kệ K-08'));
      expect(fullAddress, contains('Tầng 3'));
      expect(fullAddress, contains('Nhà A1'));
      expect(fullAddress, contains('Thư viện Trung tâm ĐHQG'));
    });

    test('Tài liệu không có vị trí hiển thị chính xác hasPhysicalLocation = false', () {
      final doc = DocumentModel(
        id: 'doc-no-loc',
        title: 'Tài liệu Ôn thi Online',
        subject: 'Toán',
        categoryId: 'cat-math',
        createdDate: DateTime(2026, 1, 1),
        updatedDate: DateTime(2026, 1, 1),
      );

      expect(doc.hasPhysicalLocation, isFalse);
      expect(doc.hasCoordinates, isFalse);
      expect(doc.displayLocationName, equals('Chưa thiết lập vị trí'));
      expect(doc.formattedLocationAddress, isNull);
      expect(doc.googleMapsUrl, isNull);
    });

    test('Không chấp nhận tọa độ mặc định (0.0, 0.0) làm vị trí thật', () {
      final doc = DocumentModel(
        id: 'doc-zero-coord',
        title: 'Tài liệu Tọa độ 0',
        subject: 'Toán',
        categoryId: 'cat-math',
        latitude: 0.0,
        longitude: 0.0,
        createdDate: DateTime(2026, 1, 1),
        updatedDate: DateTime(2026, 1, 1),
      );

      expect(doc.hasCoordinates, isFalse);
    });

    test('copyWith duy trì và cập nhật các trường vị trí mới an toàn', () {
      final original = DocumentModel(
        id: 'doc-copy-test',
        title: 'Tài liệu Gốc',
        subject: 'Vật lý',
        categoryId: 'cat-phy',
        createdDate: DateTime(2026, 1, 1),
        updatedDate: DateTime(2026, 1, 1),
      );

      final updated = original.copyWith(
        locationName: 'Thư viện Tạ Quang Bửu',
        building: 'Nhà D9',
        floor: 'Tầng 2',
        shelf: 'Kệ B-12',
        latitude: 21.0056,
        longitude: 105.8433,
      );

      expect(original.hasPhysicalLocation, isFalse);
      expect(updated.hasPhysicalLocation, isTrue);
      expect(updated.locationName, equals('Thư viện Tạ Quang Bửu'));
      expect(updated.building, equals('Nhà D9'));
      expect(updated.floor, equals('Tầng 2'));
      expect(updated.shelf, equals('Kệ B-12'));
      expect(updated.latitude, equals(21.0056));
      expect(updated.longitude, equals(105.8433));
    });
  });

  group('2. SupabaseDocumentModel Location Serialization Tests', () {
    test('toJsonForInsert bao gồm đầy đủ các trường vị trí mới', () {
      const doc = SupabaseDocumentModel(
        id: 'c8e19b88-43d7-4df3-a12b-31327170a4a8',
        ownerId: '9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d',
        title: 'Tài liệu Thư viện',
        description: 'Mô tả chi tiết',
        subject: 'Mạng máy tính',
        categoryId: 'network',
        fileName: 'network.pdf',
        fileType: 'pdf',
        fileSize: 1024,
        storagePath: 'users/kLgMf/documents/c8e19b88/network.pdf',
        locationName: 'Thư viện KHTN',
        building: 'Tòa F',
        floor: 'Tầng 4',
        shelf: 'Kệ F04',
        physicalLocation: 'Tòa F, Tầng 4, Kệ F04 - Thư viện KHTN',
        latitude: 10.7629,
        longitude: 106.6822,
        locationNotes: 'Tủ chuyên đề An toàn thông tin',
        isAvailableForBorrow: true,
      );

      final json = doc.toJsonForInsert();

      expect(json['location_name'], equals('Thư viện KHTN'));
      expect(json['building'], equals('Tòa F'));
      expect(json['floor'], equals('Tầng 4'));
      expect(json['shelf'], equals('Kệ F04'));
      expect(json['physical_location'], equals('Tòa F, Tầng 4, Kệ F04 - Thư viện KHTN'));
      expect(json['latitude'], equals(10.7629));
      expect(json['longitude'], equals(106.6822));
      expect(json['location_notes'], equals('Tủ chuyên đề An toàn thông tin'));
      expect(json['is_available_for_borrow'], isTrue);

      // Không chứa khóa cấm
      expect(json.containsKey('created_at'), isFalse);
      expect(json.containsKey('updated_at'), isFalse);
    });

    test('toJsonForUpdate bao gồm các trường vị trí và không chứa id/owner_id/timestamps', () {
      const doc = SupabaseDocumentModel(
        id: 'c8e19b88-43d7-4df3-a12b-31327170a4a8',
        ownerId: '9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d',
        title: 'Cập nhật vị trí',
        description: 'Đã chuyển kệ',
        subject: 'Hóa học',
        categoryId: 'chemistry',
        fileName: 'chemistry.pdf',
        fileType: 'pdf',
        fileSize: 2048,
        storagePath: 'users/kLgMf/documents/c8e19b88/chemistry.pdf',
        locationName: 'Thư viện Trung tâm',
        building: 'Nhà C',
        floor: 'Tầng 1',
        shelf: 'Kệ C-01',
      );

      final updatePayload = doc.toJsonForUpdate();

      expect(updatePayload['location_name'], equals('Thư viện Trung tâm'));
      expect(updatePayload['building'], equals('Nhà C'));
      expect(updatePayload['floor'], equals('Tầng 1'));
      expect(updatePayload['shelf'], equals('Kệ C-01'));

      // Tuyệt đối không chứa các trường trigger cấm
      expect(updatePayload.containsKey('id'), isFalse);
      expect(updatePayload.containsKey('owner_id'), isFalse);
      expect(updatePayload.containsKey('created_at'), isFalse);
      expect(updatePayload.containsKey('updated_at'), isFalse);
    });

    test('fromDomain và toDomain chuyển đổi tròn vẹn dữ liệu vị trí', () {
      final domain = DocumentModel(
        id: 'd8e19b88-43d7-4df3-a12b-31327170a4a9',
        title: 'Giáo trình Kinh tế vi mô',
        subject: 'Kinh tế',
        categoryId: 'economics',
        notes: 'Bản dịch tiếng Việt 2026',
        locationName: 'Thư viện FTU',
        building: 'Nhà B',
        floor: 'Tầng 5',
        shelf: 'Kệ E-15',
        latitude: 21.0225,
        longitude: 105.8038,
        locationNotes: 'Chỉ đọc tại chỗ',
        isAvailableForBorrow: false,
        createdDate: DateTime(2026, 2, 1),
        updatedDate: DateTime(2026, 2, 2),
      );

      final supabaseDoc = SupabaseDocumentModel.fromDomain(
        doc: domain,
        ownerId: '9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d',
        storagePath: 'users/123/documents/d8e19b88/kt.pdf',
        fileName: 'kt.pdf',
        fileType: 'pdf',
        fileSize: 5000,
      );

      expect(supabaseDoc.locationName, equals('Thư viện FTU'));
      expect(supabaseDoc.building, equals('Nhà B'));
      expect(supabaseDoc.floor, equals('Tầng 5'));
      expect(supabaseDoc.shelf, equals('Kệ E-15'));
      expect(supabaseDoc.latitude, equals(21.0225));
      expect(supabaseDoc.longitude, equals(105.8038));
      expect(supabaseDoc.isAvailableForBorrow, isFalse);

      final backToDomain = supabaseDoc.toDomain();
      expect(backToDomain.locationName, equals('Thư viện FTU'));
      expect(backToDomain.building, equals('Nhà B'));
      expect(backToDomain.floor, equals('Tầng 5'));
      expect(backToDomain.shelf, equals('Kệ E-15'));
      expect(backToDomain.latitude, equals(21.0225));
      expect(backToDomain.longitude, equals(105.8038));
      expect(backToDomain.hasCoordinates, isTrue);
    });
  });

  group('3. DocumentDetailScreen Widget Tests', () {
    Widget buildTestableWidget(Widget child) {
      return ChangeNotifierProvider<DocumentProvider>(
        create: (_) => MockDocumentProvider(),
        child: MaterialApp(
          home: child,
        ),
      );
    }

    testWidgets('Tài liệu KHÔNG có vị trí: hiển thị "Chưa thiết lập vị trí", không hiển thị dữ liệu giả', (tester) async {
      final docWithoutLocation = DocumentModel(
        id: 'doc-no-loc-widget',
        title: 'Tài liệu Không Vị Trí',
        notes: 'Tài liệu bài giảng PDF trực tuyến',
        subject: 'Giải tích 1',
        categoryId: 'math',
        categoryName: 'Toán học',
        tags: ['giai_tich', 'toan_1'],
        filePathOrUrl: 'path/to/calc.pdf',
        createdDate: DateTime(2026, 1, 1),
        updatedDate: DateTime(2026, 1, 2),
        userPermissionRole: 'owner',
      );

      await tester.pumpWidget(buildTestableWidget(
        DocumentDetailScreen(document: docWithoutLocation),
      ));
      await tester.pumpAndSettle();

      // Kiểm tra các thông tin metadata hiển thị đầy đủ
      expect(find.text('Tài liệu Không Vị Trí'), findsOneWidget);
      expect(find.textContaining('Giải tích 1'), findsOneWidget);
      expect(find.text('#giai_tich'), findsOneWidget);
      expect(find.text('#toan_1'), findsOneWidget);

      // Kiểm tra nút thao tác "Xem file" có mặt
      expect(find.textContaining('Xem file'), findsWidgets);

      // Kiểm tra trạng thái vị trí: Phải hiển thị "Chưa thiết lập vị trí"
      expect(find.text('Chưa thiết lập vị trí'), findsOneWidget);
      expect(
        find.text('Tài liệu này chưa được gán vị trí lưu trữ vật lý trong thư viện hoặc khuôn viên.'),
        findsOneWidget,
      );

      // Tuyệt đối không hiển thị tọa độ giả hay nút mở Google Maps
      expect(find.text('Mở Google Maps'), findsNothing);
    });

    testWidgets('Tài liệu CÓ vị trí và bản đồ trên Mobile: hiển thị nút Xem vị trí và thông tin địa điểm chi tiết', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final docWithLocation = DocumentModel(
        id: 'doc-loc-widget',
        title: 'Sách Trí tuệ Nhân tạo',
        notes: 'Giáo trình AI căn bản và nâng cao',
        subject: 'Khoa học máy tính',
        categoryId: 'cs',
        categoryName: 'Công nghệ thông tin',
        tags: ['ai', 'machine_learning'],
        locationName: 'Thư viện Tạ Quang Bửu',
        building: 'Nhà C2',
        floor: 'Tầng 3',
        shelf: 'Kệ AI-01',
        latitude: 21.0056,
        longitude: 105.8433,
        locationNotes: 'Tủ sách tham khảo đặc biệt',
        filePathOrUrl: 'path/to/ai.pdf',
        createdDate: DateTime(2026, 1, 1),
        updatedDate: DateTime(2026, 1, 2),
        userPermissionRole: 'owner',
      );

      await tester.pumpWidget(buildTestableWidget(
        DocumentDetailScreen(document: docWithLocation),
      ));
      await tester.pumpAndSettle();

      // Kiểm tra có nút "Xem file" và "Xem vị trí"
      expect(find.textContaining('Xem file'), findsWidgets);
      expect(find.text('Xem vị trí'), findsOneWidget);

      // Kiểm tra tên địa điểm và các badge chi tiết
      expect(find.text('Thư viện Tạ Quang Bửu'), findsWidgets);
      expect(find.text('Nhà C2'), findsOneWidget);
      expect(find.text('Tầng 3'), findsOneWidget);
      expect(find.text('Kệ AI-01'), findsOneWidget);
      expect(find.text('Tủ sách tham khảo đặc biệt'), findsOneWidget);

      // Kiểm tra nút mở chỉ đường Google Maps hiển thị khi có tọa độ
      expect(find.text('Chỉ đường'), findsOneWidget);
    });

    testWidgets('Quyền Viewer: Không hiển thị nút Chỉnh sửa và Xóa tài liệu', (tester) async {
      final viewerDoc = DocumentModel(
        id: 'doc-viewer-test',
        title: 'Tài liệu Quyền Viewer',
        subject: 'Vật lý',
        categoryId: 'physics',
        filePathOrUrl: 'path/to/phy.pdf',
        createdDate: DateTime(2026, 1, 1),
        updatedDate: DateTime(2026, 1, 2),
        userPermissionRole: 'viewer', // Chỉ có quyền xem
      );

      await tester.pumpWidget(buildTestableWidget(
        DocumentDetailScreen(document: viewerDoc),
      ));
      await tester.pumpAndSettle();

      // Nút Edit (icon edit_outlined) và Delete (icon delete_outline) KHÔNG được hiển thị
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.share_outlined), findsNothing);

      // Nút "Xem file" vẫn hiển thị bình thường cho viewer
      expect(find.textContaining('Xem file'), findsWidgets);
    });

    testWidgets('Responsive: Màn hình Mobile (400x800) không bị lỗi RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final doc = DocumentModel(
        id: 'doc-responsive-mobile',
        title: 'Tài liệu Mobile Test Tiêu Đề Rất Dài Để Kiểm Tra Tràn Chữ Trong Layout Thích Ứng',
        notes: 'Mô tả chi tiết với độ dài văn bản tương đối lớn để kiểm tra flex layout không bị overflow.',
        subject: 'Kỹ thuật phần mềm',
        categoryId: 'se',
        locationName: 'Thư viện Trung tâm Cơ sở 2',
        building: 'Tòa nhà H6',
        floor: 'Tầng 2',
        shelf: 'Kệ 204',
        latitude: 10.8700,
        longitude: 106.8031,
        filePathOrUrl: 'path/to/se.pdf',
        createdDate: DateTime(2026, 1, 1),
        updatedDate: DateTime(2026, 1, 2),
        userPermissionRole: 'owner',
      );

      await tester.pumpWidget(buildTestableWidget(
        DocumentDetailScreen(document: doc),
      ));
      await tester.pumpAndSettle();

      // Không phát sinh lỗi overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('Responsive: Màn hình Web/Desktop (1200x900) hiển thị dạng 2 cột không tràn', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final doc = DocumentModel(
        id: 'doc-responsive-web',
        title: 'Tài liệu Web Layout 2 Cột Test',
        subject: 'Hệ thống thông tin',
        categoryId: 'is',
        locationName: 'Thư viện Tạ Quang Bửu',
        building: 'Nhà D9',
        floor: 'Tầng 1',
        shelf: 'Kệ B-01',
        latitude: 21.0056,
        longitude: 105.8433,
        filePathOrUrl: 'path/to/is.pdf',
        createdDate: DateTime(2026, 1, 1),
        updatedDate: DateTime(2026, 1, 2),
        userPermissionRole: 'owner',
      );

      await tester.pumpWidget(buildTestableWidget(
        DocumentDetailScreen(document: doc),
      ));
      await tester.pumpAndSettle();

      // Cả 2 cột thông tin và bản đồ đều hiển thị
      expect(find.text('Tài liệu Web Layout 2 Cột Test'), findsOneWidget);
      expect(find.text('Vị trí vật lý & Bản đồ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
