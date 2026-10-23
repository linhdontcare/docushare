// ==============================================================================
// UNIT TEST: recommendation_service_test.dart
// Kiểm thử Thuật toán Gợi ý tài liệu học tập (Recommendation Engine)
// - Tính toán độ tương đồng Tag (Jaccard Index)
// - Tương quan môn học (Subject Affinity)
// - Điểm ưu tiên và sắp xếp kết quả
// ==============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:docushare/core/services/recommendation_service.dart';
import 'package:docushare/data/database/converters/type_converters.dart';
import 'package:docushare/domain/models/document_model.dart';

void main() {
  group('DocumentRecommendationService Unit Tests', () {
    const service = DocumentRecommendationService();

    final doc1 = DocumentModel(
      id: 'doc-1',
      title: 'Giáo trình Lập trình Flutter',
      subject: 'Lập trình di động',
      categoryId: 'cat-1',
      tags: ['flutter', 'dart', 'mobile'],
      priority: DocumentPriority.high,
      createdDate: DateTime.now(),
      updatedDate: DateTime.now(),
    );

    final doc2 = DocumentModel(
      id: 'doc-2',
      title: 'Toán cao cấp 1 - Đề thi',
      subject: 'Toán cao cấp',
      categoryId: 'cat-2',
      tags: ['toan', 'de_thi'],
      priority: DocumentPriority.low,
      createdDate: DateTime.now(),
      updatedDate: DateTime.now(),
    );

    final doc3 = DocumentModel(
      id: 'doc-3',
      title: 'Học máy & Trí tuệ nhân tạo',
      subject: 'Trí tuệ nhân tạo',
      categoryId: 'cat-3',
      tags: ['ai', 'machine_learning', 'python'],
      priority: DocumentPriority.medium,
      createdDate: DateTime.now(),
      updatedDate: DateTime.now(),
    );

    final allDocs = [doc1, doc2, doc3];

    test('Gợi ý chính xác dựa trên sở thích Tag của người dùng (Jaccard Match)', () {
      final userTags = ['flutter', 'mobile'];

      final recs = service.getRecommendations(
        allDocuments: allDocs,
        userPreferredTags: userTags,
      );

      expect(recs.isNotEmpty, isTrue);
      // doc1 phải có điểm số cao nhất vì khớp 2 tag 'flutter' và 'mobile'
      expect(recs.first.document.id, equals('doc-1'));
      expect(recs.first.matchingTags, containsAll(['flutter', 'mobile']));
      expect(recs.first.matchPercentage, greaterThanOrEqualTo(45));
      expect(recs.first.reason, contains('Khớp tag'));
    });

    test('Gợi ý chính xác dựa trên Môn học tương đồng (Subject Affinity)', () {
      final recs = service.getRecommendations(
        allDocuments: allDocs,
        userPreferredTags: [],
        userPreferredSubjects: ['Toán cao cấp'],
      );

      expect(recs.isNotEmpty, isTrue);
      final toanDoc = recs.firstWhere((r) => r.document.id == 'doc-2');
      expect(toanDoc.reason, contains('Toán cao cấp'));
    });

    test('Tự động khai phá sở thích từ danh mục tài liệu người dùng đã có', () {
      // Người dùng chưa khai báo tag sở thích thủ công, nhưng đã sở hữu doc1
      final recs = service.getRecommendations(
        allDocuments: allDocs,
        userPreferredTags: [],
        userOwnedDocuments: [doc1],
      );

      expect(recs.isNotEmpty, isTrue);
      // Hệ thống trích xuất tag 'flutter', 'dart', 'mobile' từ doc1 để tính điểm
      expect(recs.any((r) => r.matchingTags.contains('flutter')), isTrue);
    });

    test('Ưu tiên tài liệu có mức độ ưu tiên cao (Priority Boost)', () {
      final docLow = DocumentModel(
        id: 'doc-low',
        title: 'Tài liệu A',
        subject: 'Chung',
        categoryId: 'cat-1',
        tags: ['cntt'],
        priority: DocumentPriority.low,
        createdDate: DateTime.now(),
        updatedDate: DateTime.now(),
      );

      final docHigh = DocumentModel(
        id: 'doc-high',
        title: 'Tài liệu B',
        subject: 'Chung',
        categoryId: 'cat-1',
        tags: ['cntt'],
        priority: DocumentPriority.high,
        createdDate: DateTime.now(),
        updatedDate: DateTime.now(),
      );

      final recs = service.getRecommendations(
        allDocuments: [docLow, docHigh],
        userPreferredTags: ['cntt'],
      );

      expect(recs.first.document.id, equals('doc-high'));
      expect(recs.first.score, greaterThan(recs.last.score));
    });

    test('Trả về danh sách rỗng an toàn khi không có tài liệu nào', () {
      final recs = service.getRecommendations(
        allDocuments: [],
        userPreferredTags: ['flutter'],
      );

      expect(recs.isEmpty, isTrue);
    });
  });
}
