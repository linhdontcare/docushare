import '../../../tagging/domain/models/tag_model.dart';

/// Mô hình tài liệu trong kho DocuShare (Documents Feature)
class DocumentModel {
  final String id;
  final String ownerId; // id người đăng (AuthService.currentUser.id)
  final String ownerEmail;
  final String title;
  final String author;
  final String category;
  final String description;
  final String fileUrl; // public URL trên Supabase Storage (rỗng nếu chưa có file)
  final String fileName;
  final DateTime createdAt;
  final List<TagModel> tags;

  const DocumentModel({
    required this.id,
    required this.ownerId,
    required this.ownerEmail,
    required this.title,
    required this.author,
    required this.category,
    required this.description,
    required this.fileUrl,
    required this.fileName,
    required this.createdAt,
    this.tags = const [],
  });

  static const List<String> categories = [
    'Giáo trình',
    'Đề thi',
    'Slide bài giảng',
    'Báo cáo đồ án',
    'Khác',
  ];

  bool isOwnedBy(String? userId) => userId != null && ownerId == userId;

  List<String> get tagNames => tags.map((t) => t.name).toList();

  factory DocumentModel.fromMap(Map<String, dynamic> map,
      {List<TagModel> tags = const []}) {
    return DocumentModel(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String? ?? '',
      ownerEmail: map['owner_email'] as String? ?? '',
      title: map['title'] as String? ?? '',
      author: map['author'] as String? ?? '',
      category: map['category'] as String? ?? 'Khác',
      description: map['description'] as String? ?? '',
      fileUrl: map['file_url'] as String? ?? '',
      fileName: map['file_name'] as String? ?? '',
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      tags: tags,
    );
  }
}
