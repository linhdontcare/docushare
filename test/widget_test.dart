// Smoke test cho ứng dụng EduVault
import 'package:flutter_test/flutter_test.dart';
import 'package:docushare/domain/models/document_model.dart';
import 'package:docushare/data/database/converters/type_converters.dart';

void main() {
  test('DocumentModel domain entity integrity test', () {
    final now = DateTime.now();
    final doc = DocumentModel(
      id: 'test_doc_1',
      title: 'Đề cương Cấu trúc dữ liệu',
      subject: 'Khoa học máy tính',
      categoryId: 'cat_lecture_notes',
      categoryName: 'Bài giảng & Ghi chú',
      filePathOrUrl: 'https://example.com/slide.pdf',
      notes: 'Ôn tập chương cây nhị phân và đồ thị',
      priority: DocumentPriority.high,
      createdDate: now,
      updatedDate: now,
    );

    expect(doc.id, 'test_doc_1');
    expect(doc.title, 'Đề cương Cấu trúc dữ liệu');
    expect(doc.hasAttachment, true);
    expect(doc.isWebLink, true);
  });
}
