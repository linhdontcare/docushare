// ==============================================================================
// DOMAIN LAYER: Document Model (Thực thể miền Tài liệu học tập)
// Đại diện cho lõi nghiệp vụ của ứng dụng: độc lập với Drift SQLite, 
// đóng gói đầy đủ các thuộc tính và hành vi nghiệp vụ của một tài liệu học tập.
// ==============================================================================

import '../../data/database/converters/type_converters.dart';

class DocumentModel {
  final String id;
  final String title;
  final String subject;
  final String categoryId;
  final String? categoryName; // Tên danh mục dùng để hiển thị trực tiếp trên UI
  final String? categoryColorHex; // Màu đại diện danh mục
  final String? filePathOrUrl;
  final String? notes;
  final List<String> tags;
  final DocumentPriority priority;
  final DateTime createdDate;
  final DateTime updatedDate;

  // Phân quyền trên tài liệu ('owner' | 'editor' | 'viewer') và thông tin chủ sở hữu
  final String? userPermissionRole;
  final String? ownerEmail;
  final String? ownerName;

  // Quản lý Vị trí vật lý lưu trữ tài liệu (bản in / thư viện / tủ sách)
  final String? locationName; // Tên địa điểm / cơ sở (VD: Thư viện Tạ Quang Bửu)
  final String? building;     // Tòa nhà / Khu vực (VD: Tòa nhà E3, Nhà B1)
  final String? floor;        // Tầng (VD: Tầng 2, Tầng 3)
  final String? shelf;        // Kệ / Phòng (VD: Kệ IT-04, Phòng đọc 302)
  final String? physicalLocation; // Tương thích ngược: chuỗi vị trí gộp
  final double? latitude;
  final double? longitude;
  final String? locationNotes;
  final bool isAvailableForBorrow;
  final bool isDiscoverable;
  final bool isBorrowable;

  const DocumentModel({
    required this.id,
    required this.title,
    required this.subject,
    required this.categoryId,
    this.categoryName,
    this.categoryColorHex,
    this.filePathOrUrl,
    this.notes,
    this.tags = const [],
    this.priority = DocumentPriority.low,
    required this.createdDate,
    required this.updatedDate,
    this.userPermissionRole = 'owner',
    this.ownerEmail,
    this.ownerName,
    this.locationName,
    this.building,
    this.floor,
    this.shelf,
    this.physicalLocation,
    this.latitude,
    this.longitude,
    this.locationNotes,
    this.isAvailableForBorrow = false,
    this.isDiscoverable = false,
    this.isBorrowable = false,
  });

  /// Kiểm tra tài liệu có vị trí vật lý hay không
  bool get hasPhysicalLocation =>
      (locationName != null && locationName!.trim().isNotEmpty) ||
      (building != null && building!.trim().isNotEmpty) ||
      (floor != null && floor!.trim().isNotEmpty) ||
      (shelf != null && shelf!.trim().isNotEmpty) ||
      (physicalLocation != null && physicalLocation!.trim().isNotEmpty) ||
      hasCoordinates;

  /// Kiểm tra tài liệu có tọa độ GPS hợp lệ hay không (-90 đến 90, -180 đến 180)
  /// Tuyệt đối không chấp nhận tọa độ mặc định (0.0, 0.0) làm vị trí thật
  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      !(latitude == 0.0 && longitude == 0.0) &&
      latitude! >= -90.0 &&
      latitude! <= 90.0 &&
      longitude! >= -180.0 &&
      longitude! <= 180.0;

  /// Tên vị trí hiển thị chính
  String get displayLocationName {
    if (locationName != null && locationName!.trim().isNotEmpty) {
      return locationName!.trim();
    }
    if (physicalLocation != null && physicalLocation!.trim().isNotEmpty) {
      return physicalLocation!.trim();
    }
    if (building != null && building!.trim().isNotEmpty) {
      return building!.trim();
    }
    return 'Chưa thiết lập vị trí';
  }

  /// Chuỗi vị trí đầy đủ từ Kệ -> Tầng -> Tòa nhà -> Cơ sở
  String? get formattedLocationAddress {
    final parts = <String>[];
    if (shelf != null && shelf!.trim().isNotEmpty) parts.add(shelf!.trim());
    if (floor != null && floor!.trim().isNotEmpty) parts.add(floor!.trim());
    if (building != null && building!.trim().isNotEmpty) parts.add(building!.trim());
    if (locationName != null && locationName!.trim().isNotEmpty) parts.add(locationName!.trim());

    if (parts.isNotEmpty) {
      return parts.join(' - ');
    }
    if (physicalLocation != null && physicalLocation!.trim().isNotEmpty) {
      return physicalLocation!.trim();
    }
    return null;
  }

  /// URL mở chỉ đường Google Maps
  String? get googleMapsUrl {
    if (hasCoordinates) {
      return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    }
    final address = formattedLocationAddress ?? physicalLocation;
    if (address != null && address.trim().isNotEmpty) {
      return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address.trim())}';
    }
    return null;
  }

  /// Kiểm tra tài liệu có thuộc sở hữu của người dùng hiện tại không
  bool get isOwner => userPermissionRole == null || userPermissionRole == 'owner';

  /// Kiểm tra người dùng có quyền Editor (chỉnh sửa metadata) không
  bool get isEditor => userPermissionRole == 'editor';

  /// Kiểm tra người dùng chỉ có quyền Viewer (chỉ đọc) không
  bool get isViewer => userPermissionRole == 'viewer';

  /// Kiểm tra người dùng có quyền chỉnh sửa tài liệu không (Owner hoặc Editor)
  bool get canEdit => isOwner || isEditor;

  /// Kiểm tra người dùng có quyền xóa tài liệu không (Chỉ Owner)
  bool get canDelete => isOwner;

  /// Kiểm tra người dùng có quyền chia sẻ tài liệu không (Chỉ Owner)
  bool get canShare => isOwner;

  /// Kiểm tra tài liệu có đính kèm file hoặc đường dẫn liên kết hay không
  bool get hasAttachment => filePathOrUrl != null && filePathOrUrl!.trim().isNotEmpty;

  /// Kiểm tra đường dẫn có phải liên kết web (http/https) hay file cục bộ
  bool get isWebLink =>
      hasAttachment &&
      (filePathOrUrl!.toLowerCase().startsWith('http://') ||
          filePathOrUrl!.toLowerCase().startsWith('https://'));

  /// Tạo bản sao có cập nhật các trường nhất định (Immutable Data Pattern)
  DocumentModel copyWith({
    String? id,
    String? title,
    String? subject,
    String? categoryId,
    String? categoryName,
    String? categoryColorHex,
    String? filePathOrUrl,
    String? notes,
    List<String>? tags,
    DocumentPriority? priority,
    DateTime? createdDate,
    DateTime? updatedDate,
    String? userPermissionRole,
    String? ownerEmail,
    String? ownerName,
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
  }) {
    final effectiveBorrowable = isBorrowable ?? isAvailableForBorrow ?? this.isBorrowable;
    return DocumentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryColorHex: categoryColorHex ?? this.categoryColorHex,
      filePathOrUrl: filePathOrUrl ?? this.filePathOrUrl,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
      priority: priority ?? this.priority,
      createdDate: createdDate ?? this.createdDate,
      updatedDate: updatedDate ?? this.updatedDate,
      userPermissionRole: userPermissionRole ?? this.userPermissionRole,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      ownerName: ownerName ?? this.ownerName,
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
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DocumentModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'DocumentModel(id: $id, title: $title, subject: $subject, categoryId: $categoryId, location: $displayLocationName)';
  }
}
