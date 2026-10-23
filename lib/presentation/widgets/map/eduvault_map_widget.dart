// ==============================================================================
// PRESENTATION WIDGET: eduvault_map_widget.dart
// Bản đồ số tích hợp OpenStreetMap qua flutter_map và latlong2.
// Hỗ trợ đồng thời 2 chế độ:
// 1. Chế độ Xem (View Mode): Hiển thị vị trí tài liệu với marker, zoom và nút chỉ đường.
// 2. Chế độ Chọn (Picker Mode): Cho phép người dùng chạm chọn tọa độ khi Thêm/Sửa tài liệu.
// Tương thích tối ưu cho cả Flutter Web và Android/iOS.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';

class EduVaultMapWidget extends StatefulWidget {
  /// Tọa độ ban đầu (vĩ độ, kinh độ)
  final double? latitude;
  final double? longitude;

  /// Tiêu đề vị trí (hiển thị trên marker tooltip hoặc thanh thông tin)
  final String? locationTitle;

  /// Địa chỉ chi tiết (kệ, tầng, tòa nhà)
  final String? locationSubtitle;

  /// Chiều cao widget bản đồ (mặc định 280)
  final double height;

  /// Bật chế độ chọn tọa độ (cho màn hình Thêm/Sửa tài liệu)
  final bool isPicker;

  /// Callback khi người dùng chọn tọa độ mới (chỉ dùng trong chế độ Picker)
  final ValueChanged<LatLng>? onCoordinatesChanged;

  /// Bộ điều khiển bản đồ từ bên ngoài nếu cần di chuyển
  final MapController? externalController;

  const EduVaultMapWidget({
    super.key,
    this.latitude,
    this.longitude,
    this.locationTitle,
    this.locationSubtitle,
    this.height = 280,
    this.isPicker = false,
    this.onCoordinatesChanged,
    this.externalController,
  });

  @override
  State<EduVaultMapWidget> createState() => _EduVaultMapWidgetState();
}

class _EduVaultMapWidgetState extends State<EduVaultMapWidget> {
  late final MapController _mapController;
  LatLng? _currentPoint;
  bool _isMapReady = false;

  // Tọa độ trung tâm mặc định (Đại học Bách Khoa Hà Nội) nếu chưa có tọa độ
  static const LatLng _kDefaultCenter = LatLng(21.0049, 105.8433);

  @override
  void initState() {
    super.initState();
    _mapController = widget.externalController ?? MapController();
    if (_isValidCoordinate(widget.latitude, widget.longitude)) {
      _currentPoint = LatLng(widget.latitude!, widget.longitude!);
    }
  }

  @override
  void dispose() {
    _isMapReady = false;
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EduVaultMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.latitude != oldWidget.latitude || widget.longitude != oldWidget.longitude) {
      if (_isValidCoordinate(widget.latitude, widget.longitude)) {
        final newPoint = LatLng(widget.latitude!, widget.longitude!);
        setState(() => _currentPoint = newPoint);
        if (_isMapReady) {
          try {
            _mapController.move(newPoint, _mapController.camera.zoom);
          } catch (e) {
            debugPrint('[EduVaultMapWidget] MapController.move error: $e');
          }
        }
      } else {
        setState(() => _currentPoint = null);
      }
    }
  }

  bool _isValidCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    return lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0;
  }

  void _handleTap(TapPosition tapPosition, LatLng point) {
    if (!widget.isPicker) return;
    setState(() => _currentPoint = point);
    widget.onCoordinatesChanged?.call(point);
  }

  void _zoomIn() {
    if (!_isMapReady) return;
    try {
      final zoom = (_mapController.camera.zoom + 1).clamp(3.0, 18.0);
      _mapController.move(_currentPoint ?? _mapController.camera.center, zoom);
    } catch (_) {}
  }

  void _zoomOut() {
    if (!_isMapReady) return;
    try {
      final zoom = (_mapController.camera.zoom - 1).clamp(3.0, 18.0);
      _mapController.move(_currentPoint ?? _mapController.camera.center, zoom);
    } catch (_) {}
  }

  void _recenter() {
    if (!_isMapReady) return;
    try {
      if (_currentPoint != null) {
        _mapController.move(_currentPoint!, 16.0);
      } else {
        _mapController.move(_kDefaultCenter, 14.0);
      }
    } catch (_) {}
  }

  Future<void> _openExternalDirections() async {
    if (_currentPoint == null) return;
    final url =
        'https://www.google.com/maps/search/?api=1&query=${_currentPoint!.latitude},${_currentPoint!.longitude}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasValidPoint = _currentPoint != null;

    // Trong chế độ View (không phải picker): nếu không có tọa độ, hiển thị placeholder
    if (!widget.isPicker && !hasValidPoint) {
      return Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_off_rounded,
                size: 32,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Chưa thiết lập tọa độ bản đồ',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.locationTitle != null && widget.locationTitle!.isNotEmpty
                  ? 'Vị trí đã lưu: ${widget.locationTitle}'
                  : 'Tài liệu này chưa được gán vị trí vật lý trên bản đồ.',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    final initialCenter = _currentPoint ?? _kDefaultCenter;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isPicker
                ? Colors.amber.withValues(alpha: 0.5)
                : AppTheme.primaryColor.withValues(alpha: 0.4),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Lớp bản đồ OpenStreetMap
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: hasValidPoint ? 16.0 : 13.0,
                minZoom: 3.0,
                maxZoom: 18.0,
                onTap: _handleTap,
                onMapReady: () {
                  if (mounted) {
                    setState(() => _isMapReady = true);
                  }
                },
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.linhdontcare.eduvault',
                  maxZoom: 19,
                ),
                if (_currentPoint != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentPoint!,
                        width: 50,
                        height: 50,
                        alignment: Alignment.topCenter,
                        child: _buildPinMarker(),
                      ),
                    ],
                  ),
              ],
            ),

            // Badge gợi ý chế độ Picker
            if (widget.isPicker)
              Positioned(
                top: 10,
                left: 10,
                right: 60,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.6)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.touch_app_rounded, color: Colors.amber, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _currentPoint != null
                              ? 'Tọa độ: ${_currentPoint!.latitude.toStringAsFixed(4)}°, ${_currentPoint!.longitude.toStringAsFixed(4)}°'
                              : 'Chạm vào bản đồ để chọn tọa độ lưu trữ',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Nút điều khiển Zoom và Recenter ở góc phải
            Positioned(
              right: 10,
              top: 10,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMapControlButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Phóng to',
                    onTap: _zoomIn,
                  ),
                  const SizedBox(height: 6),
                  _buildMapControlButton(
                    icon: Icons.remove_rounded,
                    tooltip: 'Thu nhỏ',
                    onTap: _zoomOut,
                  ),
                  if (hasValidPoint) ...[
                    const SizedBox(height: 6),
                    _buildMapControlButton(
                      icon: Icons.my_location_rounded,
                      tooltip: 'Về vị trí tài liệu',
                      onTap: _recenter,
                      iconColor: AppTheme.primaryColor,
                    ),
                  ],
                ],
              ),
            ),

            // Nút mở Google Maps ở góc dưới trái (chế độ xem)
            if (!widget.isPicker && hasValidPoint)
              Positioned(
                bottom: 10,
                left: 10,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.cardBackground.withValues(alpha: 0.92),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.borderSubtle),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _openExternalDirections,
                  icon: const Icon(Icons.directions_rounded, size: 16, color: Colors.amber),
                  label: const Text(
                    'Chỉ đường',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            // Attribution OpenStreetMap ở góc dưới phải
            Positioned(
              bottom: 4,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 9, color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.amber.shade600,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.5),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.menu_book_rounded,
            size: 16,
            color: Colors.white,
          ),
        ),
        CustomPaint(
          size: const Size(10, 6),
          painter: _TrianglePainter(color: Colors.amber.shade700),
        ),
      ],
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color iconColor = AppTheme.textPrimary,
  }) {
    return Material(
      color: AppTheme.cardBackground.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.borderSubtle),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  const _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
