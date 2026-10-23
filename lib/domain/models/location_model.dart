// ==============================================================================
// DOMAIN MODEL: location_model.dart
// Đại diện cho vị trí vật lý lưu trữ tài liệu (thư viện, tòa nhà, tầng, kệ sách, tọa độ GPS)
// ==============================================================================

class PhysicalLocationModel {
  final String name;
  final String? address;
  final String? building;
  final String? floor;
  final String? shelf;
  final String? roomOrShelf;
  final double latitude;
  final double longitude;
  final String? notes;

  const PhysicalLocationModel({
    required this.name,
    this.address,
    this.building,
    this.floor,
    this.shelf,
    String? roomOrShelf,
    required this.latitude,
    required this.longitude,
    this.notes,
  }) : roomOrShelf = roomOrShelf ?? shelf;

  /// Kiểm tra tọa độ GPS có nằm trong giới hạn hợp lệ của bản đồ không
  bool get hasCoordinates =>
      latitude >= -90.0 && latitude <= 90.0 && longitude >= -180.0 && longitude <= 180.0;

  /// Tên hiển thị đầy đủ bao gồm kệ/phòng nếu có
  String get fullDisplayName {
    final effectiveShelf = shelf ?? roomOrShelf;
    if (effectiveShelf != null && effectiveShelf.isNotEmpty) {
      return '$name ($effectiveShelf)';
    }
    return name;
  }

  /// Địa chỉ chi tiết từ cấp nhỏ đến cấp lớn (Kệ -> Tầng -> Tòa nhà -> Địa điểm)
  String get detailedAddress {
    final parts = <String>[];
    final effectiveShelf = shelf ?? roomOrShelf;
    if (effectiveShelf != null && effectiveShelf.trim().isNotEmpty) {
      parts.add(effectiveShelf.trim());
    }
    if (floor != null && floor!.trim().isNotEmpty) {
      parts.add(floor!.trim());
    }
    if (building != null && building!.trim().isNotEmpty) {
      parts.add(building!.trim());
    }
    if (name.trim().isNotEmpty) {
      parts.add(name.trim());
    }
    return parts.join(' - ');
  }

  /// Tạo đường dẫn URL mở trên Google Maps
  String get googleMapsUrl =>
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

  /// Danh sách các địa điểm mẫu khuôn viên trường học / viện nghiên cứu
  static const List<PhysicalLocationModel> presetLocations = [
    PhysicalLocationModel(
      name: 'Thư viện Tạ Quang Bửu (ĐHBK Hà Nội)',
      address: 'Số 1 Đại Cồ Việt, Hai Bà Trưng, Hà Nội',
      building: 'Nhà Tạ Quang Bửu',
      floor: 'Tầng 3',
      shelf: 'Phòng đọc - Kệ sách Giáo trình A2',
      latitude: 21.0049,
      longitude: 105.8433,
      notes: 'Mở cửa từ 8:00 - 21:00 các ngày trong tuần. Yêu cầu thẻ sinh viên.',
    ),
    PhysicalLocationModel(
      name: 'Thư viện Trung tâm ĐHQG',
      address: 'Khu đô thị ĐHQG, Linh Trung, Thủ Đức, TP.HCM',
      building: 'Tòa nhà Thư viện Trung tâm',
      floor: 'Tầng 2',
      shelf: 'Phòng mượn - Kệ IT-04',
      latitude: 10.8700,
      longitude: 106.8030,
      notes: 'Có khu tự học 24/7 và quầy mượn trả tự động RFID.',
    ),
    PhysicalLocationModel(
      name: 'Lab Nghiên cứu AI & Khoa học Dữ liệu',
      address: 'Số 1 Đại Cồ Việt, Hà Nội',
      building: 'Nhà B1',
      floor: 'Tầng 4',
      shelf: 'Phòng 402 - Tủ tài liệu chuyên khảo AI/ML',
      latitude: 21.0055,
      longitude: 105.8440,
      notes: 'Ưu tiên thành viên Lab và sinh viên làm đồ án tốt nghiệp.',
    ),
    PhysicalLocationModel(
      name: 'Văn phòng Khoa Công nghệ Thông tin',
      address: '144 Xuân Thủy, Cầu Giấy, Hà Nội',
      building: 'Tòa nhà E3',
      floor: 'Tầng 5',
      shelf: 'Kệ Luận văn & Đồ án lưu trữ',
      latitude: 21.0378,
      longitude: 105.7818,
      notes: 'Liên hệ trợ lý giáo vụ để đăng ký mượn tài liệu lưu trữ.',
    ),
    PhysicalLocationModel(
      name: 'Tủ sách Cộng đồng CLB Học thuật',
      address: 'Khu KTX Sinh viên Đại học Bách Khoa',
      building: 'Nhà D6',
      floor: 'Tầng 1',
      shelf: 'Phòng Sinh hoạt Thanh niên - Ngăn tài liệu ôn thi',
      latitude: 21.0035,
      longitude: 105.8420,
      notes: 'Mượn trả tự giác, ghi sổ theo dõi tại bàn lễ tân.',
    ),
  ];

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'building': building,
      'floor': floor,
      'shelf': shelf ?? roomOrShelf,
      'roomOrShelf': roomOrShelf ?? shelf,
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
    };
  }

  factory PhysicalLocationModel.fromJson(Map<String, dynamic> json) {
    return PhysicalLocationModel(
      name: json['name'] as String? ?? 'Vị trí chưa đặt tên',
      address: json['address'] as String?,
      building: json['building'] as String?,
      floor: json['floor'] as String?,
      shelf: json['shelf'] as String? ?? json['roomOrShelf'] as String?,
      roomOrShelf: json['roomOrShelf'] as String? ?? json['shelf'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 21.0049,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 105.8433,
      notes: json['notes'] as String?,
    );
  }
}

/// Danh sách vị trí khuôn viên đại học gợi ý sẵn
const kCampusLocationPresets = PhysicalLocationModel.presetLocations;
