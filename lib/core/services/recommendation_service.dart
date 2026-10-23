// ==============================================================================
// CORE SERVICE: recommendation_service.dart
// Thuật toán Recommendation gợi ý tài liệu học tập thông minh dựa trên:
// 1. Độ tương đồng thẻ Tag (Jaccard Index)
// 2. Độ liên quan môn học (Subject affinity)
// 3. Danh mục tài liệu (Category match)
// 4. Mức độ ưu tiên và tương tác người dùng
// ==============================================================================

import 'dart:math';
import '../../domain/models/document_model.dart';
import '../../data/database/converters/type_converters.dart';

class DocumentRecommendation {
  final DocumentModel document;
  final double score; // Từ 0.0 đến 1.0
  final int matchPercentage; // Từ 0% đến 100%
  final String reason;
  final List<String> matchingTags;

  const DocumentRecommendation({
    required this.document,
    required this.score,
    required this.matchPercentage,
    required this.reason,
    this.matchingTags = const [],
  });
}

class DocumentRecommendationService {
  const DocumentRecommendationService();

  /// Tính toán danh sách tài liệu được gợi ý tốt nhất
  List<DocumentRecommendation> getRecommendations({
    required List<DocumentModel> allDocuments,
    required List<String> userPreferredTags,
    List<DocumentModel> userOwnedDocuments = const [],
    List<String> userPreferredSubjects = const [],
    int limit = 6,
  }) {
    if (allDocuments.isEmpty) return [];

    // Tổng hợp sở thích tự động từ tài liệu của người dùng nếu danh sách preferredTags rỗng
    final effectiveTags = Set<String>.from(
      userPreferredTags.map((t) => _normalizeTag(t)),
    );
    final effectiveSubjects = Set<String>.from(
      userPreferredSubjects.map((s) => s.trim().toLowerCase()),
    );

    if (effectiveTags.isEmpty && userOwnedDocuments.isNotEmpty) {
      for (final doc in userOwnedDocuments) {
        for (final tag in doc.tags) {
          effectiveTags.add(_normalizeTag(tag));
        }
        if (doc.subject.trim().isNotEmpty) {
          effectiveSubjects.add(doc.subject.trim().toLowerCase());
        }
      }
    }

    final recommendations = <DocumentRecommendation>[];

    for (final doc in allDocuments) {
      final docTags = doc.tags.map((t) => _normalizeTag(t)).toSet();
      final matchingTags = docTags.intersection(effectiveTags).toList();

      // 1. Điểm tương đồng Tag theo chỉ số Jaccard (Trọng số 0.50)
      double tagScore = 0.0;
      if (effectiveTags.isNotEmpty || docTags.isNotEmpty) {
        final unionTags = docTags.union(effectiveTags);
        if (unionTags.isNotEmpty) {
          tagScore = matchingTags.length / unionTags.length;
        }
      }

      // 2. Điểm tương quan Môn học (Trọng số 0.25)
      double subjectScore = 0.0;
      final docSubject = doc.subject.trim().toLowerCase();
      if (effectiveSubjects.contains(docSubject)) {
        subjectScore = 1.0;
      } else if (effectiveSubjects.any((s) => s.contains(docSubject) || docSubject.contains(s))) {
        subjectScore = 0.5;
      }

      // 3. Điểm mức độ ưu tiên Priority (Trọng số 0.15)
      double priorityScore = 0.2;
      switch (doc.priority) {
        case DocumentPriority.high:
          priorityScore = 1.0;
          break;
        case DocumentPriority.medium:
          priorityScore = 0.6;
          break;
        case DocumentPriority.low:
          priorityScore = 0.3;
          break;
      }

      // 4. Điểm sẵn sàng mượn / có đính kèm (Trọng số 0.10)
      double featureScore = 0.0;
      if (doc.hasAttachment) featureScore += 0.5;
      if (doc.hasPhysicalLocation) featureScore += 0.5;

      // Tính điểm tổng hợp có trọng số
      final totalScore = min(
        1.0,
        (tagScore * 0.50) +
        (subjectScore * 0.25) +
        (priorityScore * 0.15) +
        (featureScore * 0.10),
      );

      final percentage = (totalScore * 100).round();

      // Chỉ đề xuất nếu có mức độ phù hợp nhất định
      if (percentage >= 20 || matchingTags.isNotEmpty || subjectScore > 0) {
        final reasons = <String>[];
        if (matchingTags.isNotEmpty) {
          reasons.add('Khớp tag #${matchingTags.take(2).join(', #')}');
        }
        if (subjectScore > 0) {
          reasons.add('Cùng môn ${doc.subject}');
        }
        if (doc.priority == DocumentPriority.high) {
          reasons.add('Ưu tiên cao');
        }
        if (doc.hasPhysicalLocation) {
          reasons.add('Có sách tại thư viện');
        }

        recommendations.add(
          DocumentRecommendation(
            document: doc,
            score: totalScore,
            matchPercentage: max(percentage, 25),
            reason: reasons.isNotEmpty ? reasons.join(' • ') : 'Gợi ý nổi bật',
            matchingTags: matchingTags,
          ),
        );
      }
    }

    // Sắp xếp theo điểm số giảm dần
    recommendations.sort((a, b) => b.score.compareTo(a.score));

    // Nếu không đủ gợi ý theo tiêu chuẩn, bổ sung các tài liệu ưu tiên cao hoặc mới nhất
    if (recommendations.isEmpty && allDocuments.isNotEmpty) {
      for (final doc in allDocuments.take(limit)) {
        recommendations.add(
          DocumentRecommendation(
            document: doc,
            score: 0.5,
            matchPercentage: 50,
            reason: 'Tài liệu tiêu biểu trong kho',
            matchingTags: doc.tags,
          ),
        );
      }
    }

    return recommendations.take(limit).toList();
  }

  static String _normalizeTag(String tag) {
    return tag.trim().replaceAll('#', '').toLowerCase();
  }
}
