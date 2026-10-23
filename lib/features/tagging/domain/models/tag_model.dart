/// Mô hình thẻ tag phân loại tài liệu (Tagging Feature)
class TagModel {
  final String id;
  final String name;
  final int documentCount;

  const TagModel({
    required this.id,
    required this.name,
    this.documentCount = 0,
  });

  factory TagModel.fromMap(Map<String, dynamic> map) => TagModel(
        id: map['id'] as String,
        name: map['name'] as String,
      );

  TagModel copyWith({String? id, String? name, int? documentCount}) {
    return TagModel(
      id: id ?? this.id,
      name: name ?? this.name,
      documentCount: documentCount ?? this.documentCount,
    );
  }
}
