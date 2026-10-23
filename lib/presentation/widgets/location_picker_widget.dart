// ==============================================================================
// PRESENTATION WIDGET: location_picker_widget.dart
// Quản lý vị trí vật lý lưu trữ tài liệu (thư viện, tòa nhà, tầng, kệ sách, tọa độ GPS)
// và tích hợp bản đồ số thực tế OpenStreetMap (flutter_map).
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/location_model.dart';
import 'map/eduvault_map_widget.dart';

/// Widget chọn và nhập vị trí vật lý chi tiết kèm bản đồ số tương tác
class LocationPickerWidget extends StatefulWidget {
  final String? initialLocation;
  final String? initialLocationName;
  final String? initialBuilding;
  final String? initialFloor;
  final String? initialShelf;
  final double? initialLat;
  final double? initialLng;
  final String? initialNotes;

  /// Callback tương thích với giao diện cũ
  final Function(String location, double? lat, double? lng, String? notes)? onLocationChanged;

  /// Callback mở rộng cung cấp đủ các trường vị trí chi tiết
  final void Function({
    String? locationName,
    String? building,
    String? floor,
    String? shelf,
    String? physicalLocation,
    double? lat,
    double? lng,
    String? notes,
  })? onDetailedLocationChanged;

  const LocationPickerWidget({
    super.key,
    this.initialLocation,
    this.initialLocationName,
    this.initialBuilding,
    this.initialFloor,
    this.initialShelf,
    this.initialLat,
    this.initialLng,
    this.initialNotes,
    this.onLocationChanged,
    this.onDetailedLocationChanged,
  });

  @override
  State<LocationPickerWidget> createState() => _LocationPickerWidgetState();
}

class _LocationPickerWidgetState extends State<LocationPickerWidget> {
  late TextEditingController _locationNameController;
  late TextEditingController _buildingController;
  late TextEditingController _floorController;
  late TextEditingController _shelfController;
  late TextEditingController _notesController;
  final MapController _mapController = MapController();

  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    // Khởi tạo các trường chi tiết hoặc tách từ chuỗi vị trí cũ nếu chưa có
    _locationNameController = TextEditingController(
      text: widget.initialLocationName ?? widget.initialLocation ?? '',
    );
    _buildingController = TextEditingController(text: widget.initialBuilding ?? '');
    _floorController = TextEditingController(text: widget.initialFloor ?? '');
    _shelfController = TextEditingController(text: widget.initialShelf ?? '');
    _notesController = TextEditingController(text: widget.initialNotes ?? '');

    _latitude = widget.initialLat;
    _longitude = widget.initialLng;
  }

  void _applyPreset(PhysicalLocationModel preset) {
    setState(() {
      _locationNameController.text = preset.name;
      _buildingController.text = preset.building ?? '';
      _floorController.text = preset.floor ?? '';
      _shelfController.text = preset.shelf ?? preset.roomOrShelf ?? '';
      _notesController.text = preset.notes ?? '';
      _latitude = preset.latitude;
      _longitude = preset.longitude;
    });
    _notifyParent();
  }

  void _clearCoordinates() {
    setState(() {
      _latitude = null;
      _longitude = null;
    });
    _notifyParent();
  }

  String _buildFormattedAddress() {
    final parts = <String>[];
    if (_shelfController.text.trim().isNotEmpty) parts.add(_shelfController.text.trim());
    if (_floorController.text.trim().isNotEmpty) parts.add(_floorController.text.trim());
    if (_buildingController.text.trim().isNotEmpty) parts.add(_buildingController.text.trim());
    if (_locationNameController.text.trim().isNotEmpty) {
      parts.add(_locationNameController.text.trim());
    }
    return parts.join(' - ');
  }

  void _notifyParent() {
    final formatted = _buildFormattedAddress();
    final locName = _locationNameController.text.trim().isEmpty ? null : _locationNameController.text.trim();
    final bld = _buildingController.text.trim().isEmpty ? null : _buildingController.text.trim();
    final flr = _floorController.text.trim().isEmpty ? null : _floorController.text.trim();
    final shf = _shelfController.text.trim().isEmpty ? null : _shelfController.text.trim();
    final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

    widget.onLocationChanged?.call(
      formatted,
      _latitude,
      _longitude,
      notes,
    );

    widget.onDetailedLocationChanged?.call(
      locationName: locName,
      building: bld,
      floor: flr,
      shelf: shf,
      physicalLocation: formatted.isEmpty ? null : formatted,
      lat: _latitude,
      lng: _longitude,
      notes: notes,
    );
  }

  @override
  void dispose() {
    _locationNameController.dispose();
    _buildingController.dispose();
    _floorController.dispose();
    _shelfController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasCoordinates = _latitude != null && _longitude != null;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_on_rounded, size: 20, color: Colors.amber),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vị trí lưu trữ vật lý & Bản đồ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Xác định vị trí sách/tài liệu trong thư viện hoặc khuôn viên trường',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Chọn nhanh địa điểm mẫu tại trường đại học
          Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 14, color: Colors.amber),
              const SizedBox(width: 4),
              const Text(
                'Chọn nhanh cơ sở / thư viện mẫu:',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: PhysicalLocationModel.presetLocations.map((preset) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    avatar: const Icon(Icons.place_outlined, size: 14, color: Colors.amber),
                    backgroundColor: AppTheme.scaffoldBackground,
                    side: BorderSide(color: Colors.amber.withValues(alpha: 0.3)),
                    label: Text(
                      preset.name.split('(').first.trim(),
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textPrimary),
                    ),
                    onPressed: () => _applyPreset(preset),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Nhóm 1: Tên địa điểm & Tòa nhà
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              final locNameField = TextFormField(
                controller: _locationNameController,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration: _buildInputDecoration(
                  label: 'Tên địa điểm / Cơ sở',
                  hint: 'Ví dụ: Thư viện Tạ Quang Bửu, Lab AI',
                  icon: Icons.account_balance_outlined,
                ),
                onChanged: (_) => _notifyParent(),
              );

              final bldField = TextFormField(
                controller: _buildingController,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration: _buildInputDecoration(
                  label: 'Tòa nhà / Khu vực',
                  hint: 'Ví dụ: Nhà TQB, Tòa nhà E3, Nhà B1',
                  icon: Icons.business_outlined,
                ),
                onChanged: (_) => _notifyParent(),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    locNameField,
                    const SizedBox(height: 10),
                    bldField,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: locNameField),
                  const SizedBox(width: 12),
                  Expanded(child: bldField),
                ],
              );
            },
          ),
          const SizedBox(height: 10),

          // Nhóm 2: Tầng & Phòng/Kệ sách
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              final floorField = TextFormField(
                controller: _floorController,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration: _buildInputDecoration(
                  label: 'Tầng',
                  hint: 'Ví dụ: Tầng 2, Tầng 3',
                  icon: Icons.layers_outlined,
                ),
                onChanged: (_) => _notifyParent(),
              );

              final shelfField = TextFormField(
                controller: _shelfController,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration: _buildInputDecoration(
                  label: 'Phòng / Kệ sách cụ thể',
                  hint: 'Ví dụ: Phòng mượn - Kệ IT-04',
                  icon: Icons.shelves,
                ),
                onChanged: (_) => _notifyParent(),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    floorField,
                    const SizedBox(height: 10),
                    shelfField,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 2, child: floorField),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: shelfField),
                ],
              );
            },
          ),
          const SizedBox(height: 10),

          // Nhóm 3: Lưu ý mượn tại chỗ
          TextFormField(
            controller: _notesController,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            decoration: _buildInputDecoration(
              label: 'Lưu ý khi mượn / tiếp cận (tùy chọn)',
              hint: 'Ví dụ: Xuất trình thẻ SV tại quầy lễ tân tầng 1...',
              icon: Icons.info_outline_rounded,
            ),
            onChanged: (_) => _notifyParent(),
          ),
          const SizedBox(height: 16),

          // Khối Bản đồ tương tác OpenStreetMap
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.map_outlined, size: 16, color: Colors.amber),
                  const SizedBox(width: 6),
                  const Text(
                    'Bản đồ vị trí (OpenStreetMap):',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              if (hasCoordinates)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  onPressed: _clearCoordinates,
                  icon: const Icon(Icons.clear_rounded, size: 14),
                  label: const Text('Xóa tọa độ', style: TextStyle(fontSize: 11.5)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Nhấn vào bất kỳ vị trí nào trên bản đồ để ghim tọa độ tài liệu:',
            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),

          EduVaultMapWidget(
            latitude: _latitude,
            longitude: _longitude,
            locationTitle: _locationNameController.text.trim().isEmpty
                ? 'Vị trí tài liệu'
                : _locationNameController.text.trim(),
            locationSubtitle: _buildFormattedAddress(),
            height: 250,
            isPicker: true,
            externalController: _mapController,
            onCoordinatesChanged: (point) {
              setState(() {
                _latitude = point.latitude;
                _longitude = point.longitude;
              });
              _notifyParent();
            },
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      prefixIcon: Icon(icon, color: Colors.amber, size: 18),
      filled: true,
      fillColor: AppTheme.scaffoldBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.amber, width: 1.2),
      ),
    );
  }
}

/// Hộp thoại hiển thị vị trí bản đồ chi tiết của tài liệu tích hợp EduVaultMapWidget
void showLocationDetailDialog(
  BuildContext context, {
  required String title,
  required String physicalLocation,
  String? locationName,
  String? building,
  String? floor,
  String? shelf,
  double? latitude,
  double? longitude,
  String? notes,
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppTheme.borderSubtle),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.location_on_rounded, color: Colors.amber, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Vị trí lưu trữ vật lý',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
              const SizedBox(height: 12),

              // Bảng thông tin địa điểm chi tiết
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.scaffoldBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      icon: Icons.place_rounded,
                      iconColor: Colors.amber,
                      label: 'Địa chỉ / Vị trí',
                      value: physicalLocation,
                    ),
                    if (building != null && building.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildDetailRow(
                        icon: Icons.business_outlined,
                        iconColor: Colors.lightBlueAccent,
                        label: 'Tòa nhà',
                        value: building,
                      ),
                    ],
                    if (floor != null && floor.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildDetailRow(
                        icon: Icons.layers_outlined,
                        iconColor: Colors.lightBlueAccent,
                        label: 'Tầng',
                        value: floor,
                      ),
                    ],
                    if (shelf != null && shelf.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildDetailRow(
                        icon: Icons.shelves,
                        iconColor: Colors.lightBlueAccent,
                        label: 'Phòng / Kệ sách',
                        value: shelf,
                      ),
                    ],
                    if (latitude != null && longitude != null) ...[
                      const SizedBox(height: 6),
                      _buildDetailRow(
                        icon: Icons.my_location_rounded,
                        iconColor: Colors.amberAccent,
                        label: 'Tọa độ GPS',
                        value: '${latitude.toStringAsFixed(4)}° N, ${longitude.toStringAsFixed(4)}° E',
                      ),
                    ],
                    if (notes != null && notes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildDetailRow(
                        icon: Icons.info_outline_rounded,
                        iconColor: AppTheme.textSecondary,
                        label: 'Ghi chú',
                        value: notes,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Widget bản đồ thật
              EduVaultMapWidget(
                latitude: latitude,
                longitude: longitude,
                locationTitle: locationName ?? physicalLocation,
                locationSubtitle: physicalLocation,
                height: 220,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Đóng', style: TextStyle(color: AppTheme.textSecondary)),
        ),
      ],
    ),
  );
}

Widget _buildDetailRow({
  required IconData icon,
  required Color iconColor,
  required String label,
  required String value,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 15, color: iconColor),
      const SizedBox(width: 8),
      Text(
        '$label: ',
        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
      ),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
}
