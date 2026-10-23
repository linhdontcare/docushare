// ==============================================================================
// DOMAIN MODEL: supabase_document_model.dart
// Đại diện cho thực thể Metadata tài liệu trong bảng public.documents của Supabase
// Hỗ trợ ánh xạ hai chiều với DocumentModel, chuẩn hóa UUID và kiểm soát payload an toàn
// ==============================================================================

import 'package:uuid/uuid.dart';

import 'document_model.dart';

class SupabaseDocumentModel {
  final String id;
  final String ownerId;
  final String title;
  final String? description;
  final String? subject;
  final String categoryId;
  final String fileName;
  final String fileType;
  final int fileSize;
  final String storagePath;
  final String? locationName;
  final String? building;
  final String? floor;
  final String? shelf;
  final String? physicalLocation;
  final double? latitude;
  final double? longitude;
  final String? locationNotes;
  final bool? isAvailableForBorrow;
  final bool isDiscoverable;
  final bool isBorrowable;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SupabaseDocumentModel({
    required this.id,
    required this.ownerId,
    required this.title,
    this.description,
    this.subject,
    this.categoryId = 'all',
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.storagePath,
    this.locationName,
    this.building,
    this.floor,
    this.shelf,
    this.physicalLocation,
    this.latitude,
    this.longitude,
    this.locationNotes,
    this.isAvailableForBorrow,
    this.isDiscoverable = false,
    this.isBorrowable = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Biểu thức chính quy kiểm tra định dạng UUID v4/v5/generic chuẩn
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Kiểm tra một chuỗi có phải UUID hợp lệ hay không
  static bool isValidUuid(String str) {
    return _uuidRegex.hasMatch(str.trim());
  }

  /// Chuẩn hóa ID tài liệu:
  /// - Nếu đã là UUID hợp lệ -> Giữ nguyên.
  /// - Nếu là chuỗi cũ/tùy biến (vd 'doc_1', 'my-file') -> Ánh xạ tất định (deterministic)
  ///   thành UUID v5 dựa trên namespace URL để không bao giờ sinh ra ID trùng khi đồng bộ lại.
  static String toValidUuid(String rawId) {
    final trimmed = rawId.trim();
    if (isValidUuid(trimmed)) {
      return trimmed.toLowerCase();
    }
    // Dùng UUID v5 tất định từ Namespace URL
    return const Uuid().v5(Namespace.url.value, 'eduvault:doc:$trimmed').toLowerCase();
  }

  /// Khởi tạo từ JSON trả về bởi Supabase PostgREST
  factory SupabaseDocumentModel.fromJson(Map<String, dynamic> json) {
    return SupabaseDocumentModel(
      id: json['id'] as String? ?? '',
      ownerId: json['owner_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      subject: json['subject'] as String?,
      categoryId: json['category_id'] as String? ?? 'all',
      fileName: json['file_name'] as String? ?? '',
      fileType: json['file_type'] as String? ?? '',
      fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
      storagePath: json['storage_path'] as String? ?? '',
      locationName: json['location_name'] as String?,
      building: json['building'] as String?,
      floor: json['floor'] as String?,
      shelf: json['shelf'] as String?,
      physicalLocation: json['physical_location'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationNotes: json['location_notes'] as String?,
      isAvailableForBorrow: json['is_available_for_borrow'] as bool? ?? (json['is_borrowable'] as bool? ?? false),
      isDiscoverable: json['is_discoverable'] as bool? ?? false,
      isBorrowable: json['is_borrowable'] as bool? ?? (json['is_available_for_borrow'] as bool? ?? false),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  /// Khởi tạo từ DocumentModel của ứng dụng kết hợp thông tin file/user
  factory SupabaseDocumentModel.fromDomain({
    required DocumentModel doc,
    required String ownerId,
    required String storagePath,
    required String fileName,
    required String fileType,
    required int fileSize,
  }) {
    return SupabaseDocumentModel(
      id: toValidUuid(doc.id),
      ownerId: ownerId,
      title: doc.title,
      description: doc.notes,
      subject: doc.subject.trim().isEmpty ? null : doc.subject,
      categoryId: doc.categoryId.trim().isEmpty ? 'all' : doc.categoryId,
      fileName: fileName,
      fileType: fileType,
      fileSize: fileSize >= 0 ? fileSize : 0,
      storagePath: storagePath,
      locationName: doc.locationName,
      building: doc.building,
      floor: doc.floor,
      shelf: doc.shelf,
      physicalLocation: doc.physicalLocation,
      latitude: doc.latitude,
      longitude: doc.longitude,
      locationNotes: doc.locationNotes,
      isAvailableForBorrow: doc.isBorrowable,
      isDiscoverable: doc.isDiscoverable,
      isBorrowable: doc.isBorrowable,
      createdAt: doc.createdDate,
      updatedAt: doc.updatedDate,
    );
  }

  /// Payload cho thao tác INSERT:
  /// Cung cấp đầy đủ các trường bắt buộc của bảng public.documents kèm location nếu có
  Map<String, dynamic> toJsonForInsert() {
    final effectiveBorrow = isBorrowable || (isAvailableForBorrow ?? false);
    final payload = <String, dynamic>{
      'id': id,
      'owner_id': ownerId,
      'title': title,
      'description': description,
      'subject': subject,
      'category_id': categoryId,
      'file_name': fileName,
      'file_type': fileType,
      'file_size': fileSize >= 0 ? fileSize : 0,
      'storage_path': storagePath,
      'is_discoverable': isDiscoverable,
      'is_borrowable': effectiveBorrow,
      'is_available_for_borrow': effectiveBorrow,
    };
    if (locationName != null) payload['location_name'] = locationName;
    if (building != null) payload['building'] = building;
    if (floor != null) payload['floor'] = floor;
    if (shelf != null) payload['shelf'] = shelf;
    if (physicalLocation != null) payload['physical_location'] = physicalLocation;
    if (latitude != null) payload['latitude'] = latitude;
    if (longitude != null) payload['longitude'] = longitude;
    if (locationNotes != null) payload['location_notes'] = locationNotes;
    return payload;
  }

  /// Payload cho thao tác UPDATE khi chỉ cập nhật thông tin chung (không đổi file):
  /// TUYỆT ĐỐI KHÔNG GỬI 'id', 'owner_id', 'created_at', 'updated_at' để không vi phạm
  /// trigger bảo vệ `eduvault_guard_documents` trên Supabase (trigger tự set NEW.updated_at = now()).
  Map<String, dynamic> toJsonForUpdate({bool includeDiscoverability = false}) {
    final effectiveBorrow = isBorrowable || (isAvailableForBorrow ?? false);
    final payload = <String, dynamic>{
      'title': title,
      'description': description,
      'subject': subject,
      'category_id': categoryId,
    };
    if (includeDiscoverability) {
      payload['is_discoverable'] = isDiscoverable;
      payload['is_borrowable'] = effectiveBorrow;
    }
    if (locationName != null) payload['location_name'] = locationName;
    if (building != null) payload['building'] = building;
    if (floor != null) payload['floor'] = floor;
    if (shelf != null) payload['shelf'] = shelf;
    if (physicalLocation != null) payload['physical_location'] = physicalLocation;
    if (latitude != null) payload['latitude'] = latitude;
    if (longitude != null) payload['longitude'] = longitude;
    if (locationNotes != null) payload['location_notes'] = locationNotes;
    return payload;
  }

  /// Payload cho thao tác UPDATE khi Owner chủ động thay đổi tệp mới:
  /// Cập nhật thêm 4 trường tệp (file_name, file_type, file_size, storage_path)
  /// nhưng TUYỆT ĐỐI không gửi 'id', 'owner_id', 'created_at', 'updated_at'
  Map<String, dynamic> toJsonForFileUpdate({bool includeDiscoverability = false}) {
    final effectiveBorrow = isBorrowable || (isAvailableForBorrow ?? false);
    final payload = <String, dynamic>{
      'title': title,
      'description': description,
      'subject': subject,
      'category_id': categoryId,
      'file_name': fileName,
      'file_type': fileType,
      'file_size': fileSize >= 0 ? fileSize : 0,
      'storage_path': storagePath,
    };
    if (includeDiscoverability) {
      payload['is_discoverable'] = isDiscoverable;
      payload['is_borrowable'] = effectiveBorrow;
    }
    if (locationName != null) payload['location_name'] = locationName;
    if (building != null) payload['building'] = building;
    if (floor != null) payload['floor'] = floor;
    if (shelf != null) payload['shelf'] = shelf;
    if (physicalLocation != null) payload['physical_location'] = physicalLocation;
    if (latitude != null) payload['latitude'] = latitude;
    if (longitude != null) payload['longitude'] = longitude;
    if (locationNotes != null) payload['location_notes'] = locationNotes;
    return payload;
  }

  /// Chuyển đổi ngược lại DocumentModel để cập nhật vào tầng hiển thị nếu cần
  DocumentModel toDomain({
    String? categoryName,
    String? categoryColorHex,
  }) {
    return DocumentModel(
      id: id,
      title: title,
      subject: subject ?? '',
      categoryId: categoryId,
      categoryName: categoryName,
      categoryColorHex: categoryColorHex,
      filePathOrUrl: storagePath,
      notes: description,
      locationName: locationName,
      building: building,
      floor: floor,
      shelf: shelf,
      physicalLocation: physicalLocation,
      latitude: latitude,
      longitude: longitude,
      locationNotes: locationNotes,
      isAvailableForBorrow: isBorrowable,
      isDiscoverable: isDiscoverable,
      isBorrowable: isBorrowable,
      createdDate: createdAt ?? DateTime.now(),
      updatedDate: updatedAt ?? DateTime.now(),
    );
  }

  SupabaseDocumentModel copyWith({
    String? id,
    String? ownerId,
    String? title,
    String? description,
    String? subject,
    String? categoryId,
    String? fileName,
    String? fileType,
    int? fileSize,
    String? storagePath,
    String? locationName,
    String? building,
    String? floor,
    String? shelf,
    String? physicalLocation,
    double? latitude,
    double? longitude,
    String? locationNotes,
    bool? isAvailableForBorrow,
    bool? isDiscoverable,
    bool? isBorrowable,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final effectiveBorrowable = isBorrowable ?? isAvailableForBorrow ?? this.isBorrowable;
    return SupabaseDocumentModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      description: description ?? this.description,
      subject: subject ?? this.subject,
      categoryId: categoryId ?? this.categoryId,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      fileSize: fileSize ?? this.fileSize,
      storagePath: storagePath ?? this.storagePath,
      locationName: locationName ?? this.locationName,
      building: building ?? this.building,
      floor: floor ?? this.floor,
      shelf: shelf ?? this.shelf,
      physicalLocation: physicalLocation ?? this.physicalLocation,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationNotes: locationNotes ?? this.locationNotes,
      isAvailableForBorrow: effectiveBorrowable,
      isDiscoverable: isDiscoverable ?? this.isDiscoverable,
      isBorrowable: effectiveBorrowable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupabaseDocumentModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          ownerId == other.ownerId;

  @override
  int get hashCode => id.hashCode ^ ownerId.hashCode;

  @override
  String toString() {
    return 'SupabaseDocumentModel(id: $id, ownerId: $ownerId, title: $title, fileName: $fileName, location: $locationName)';
  }
}
