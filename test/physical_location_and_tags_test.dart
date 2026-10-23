// ==============================================================================
// UNIT TEST: physical_location_and_tags_test.dart
// Kiểm thử quản lý Vị trí vật lý (PhysicalLocationModel), Tọa độ Bản đồ,
// và Phân loại tài liệu bằng Thẻ Tag
// ==============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:docushare/domain/models/document_model.dart';
import 'package:docushare/domain/models/location_model.dart';

void main() {
  group('Physical Location & Maps Integration Tests', () {
    test('PhysicalLocationModel khởi tạo và sinh URL Google Maps chính xác', () {
      final loc = PhysicalLocationModel(
        name: 'Thư viện Tạ Quang Bửu - ĐHBK',
        latitude: 21.0056,
        longitude: 105.8433,
        roomOrShelf: 'Phòng 302, Kệ A-14',
        notes: 'Chỉ đọc tại chỗ',
      );

      expect(loc.hasCoordinates, isTrue);
      expect(loc.googleMapsUrl, contains('21.0056,105.8433'));
      expect(loc.fullDisplayName, equals('Thư viện Tạ Quang Bửu - ĐHBK (Phòng 302, Kệ A-14)'));
    });

    test('Danh sách Campus Presets có đầy đủ các thư viện đại học tiêu biểu', () {
      expect(kCampusLocationPresets.isNotEmpty, isTrue);
      final hust = kCampusLocationPresets.firstWhere((p) => p.name.contains('Tạ Quang Bửu'));
      expect(hust.latitude, isNotNull);
      expect(hust.longitude, isNotNull);
      expect(hust.googleMapsUrl, isNotNull);

      final vnu = kCampusLocationPresets.firstWhere((p) => p.name.contains('ĐHQG'));
      expect(vnu.latitude, isNotNull);
      expect(vnu.longitude, isNotNull);
    });

    test('DocumentModel tích hợp thuộc tính vị trí vật lý và đường dẫn Google Maps', () {
      final docWithLocation = DocumentModel(
        id: 'doc-geo-1',
        title: 'Sách Hệ điều hành',
        subject: 'Khoa học máy tính',
        categoryId: 'cat-1',
        physicalLocation: 'Thư viện Trung tâm ĐHQG TP.HCM',
        latitude: 10.8700,
        longitude: 106.8031,
        locationNotes: 'Kệ B2 - Tầng 2',
        isAvailableForBorrow: true,
        createdDate: DateTime.now(),
        updatedDate: DateTime.now(),
      );

      expect(docWithLocation.hasPhysicalLocation, isTrue);
      expect(docWithLocation.hasCoordinates, isTrue);
      expect(docWithLocation.googleMapsUrl, contains('10.87,106.8031'));
      expect(docWithLocation.isAvailableForBorrow, isTrue);

      final docWithoutLocation = DocumentModel(
        id: 'doc-geo-2',
        title: 'Slide bài giảng online',
        subject: 'Toán tin',
        categoryId: 'cat-2',
        createdDate: DateTime.now(),
        updatedDate: DateTime.now(),
      );

      expect(docWithoutLocation.hasPhysicalLocation, isFalse);
      expect(docWithoutLocation.hasCoordinates, isFalse);
      expect(docWithoutLocation.googleMapsUrl, isNull);
    });
  });

  group('Document Tag Classification Tests', () {
    test('Xử lý và chuẩn hóa danh sách thẻ Tag trong DocumentModel', () {
      final doc = DocumentModel(
        id: 'doc-tag-1',
        title: 'Bài tập Mạng máy tính',
        subject: 'Mạng máy tính',
        categoryId: 'cat-net',
        tags: ['tcp_ip', 'lan_wan', 'cisco', 'bai_tap'],
        createdDate: DateTime.now(),
        updatedDate: DateTime.now(),
      );

      expect(doc.tags.length, equals(4));
      expect(doc.tags, contains('tcp_ip'));
      expect(doc.tags, contains('cisco'));
    });

    test('Immutable copyWith cập nhật Tags và Location an toàn', () {
      final original = DocumentModel(
        id: 'doc-orig',
        title: 'Tài liệu Gốc',
        subject: 'Toán',
        categoryId: 'cat-1',
        tags: ['toan_1'],
        createdDate: DateTime.now(),
        updatedDate: DateTime.now(),
      );

      final updated = original.copyWith(
        tags: ['toan_1', 'de_thi', 'on_tap'],
        physicalLocation: 'Tủ sách cá nhân',
        latitude: 21.0285,
        longitude: 105.8542,
        isAvailableForBorrow: false,
      );

      expect(updated.tags.length, equals(3));
      expect(updated.hasPhysicalLocation, isTrue);
      expect(updated.isAvailableForBorrow, isFalse);
      // Tài liệu gốc giữ nguyên tính bất biến (Immutable)
      expect(original.tags.length, equals(1));
      expect(original.hasPhysicalLocation, isFalse);
    });
  });
}
