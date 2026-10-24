// ==============================================================================
// PRESENTATION WIDGET: eduvault_map_widget.dart
// Bản đồ số mini (Minimap) tích hợp OpenStreetMap qua flutter_map và latlong2.
// Hỗ trợ đồng thời 2 chế độ:
// 1. Chế độ Xem (View Mode): Luôn hiển thị bản đồ số sắc nét với marker, radar pulse,
//    thanh thông tin vị trí, nút phóng to/thu nhỏ, nút mở toàn màn hình và chỉ đường.
// 2. Chế độ Chọn (Picker Mode): Chạm chọn tọa độ khi Thêm/Sửa tài liệu, hỗ trợ crosshair.
// Tương thích tối ưu cho cả Flutter Web (Edge/Chrome) và Android/iOS.
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

  /// Callback khi bấm vào nút "Thiết lập vị trí" trên bản đồ xem
  final VoidCallback? onTapSetLocation;

  /// Bộ điều khiển bản đồ từ bên ngoài nếu cần di chuyển
  final MapController? externalController;

  /// Cho phép mở hộp thoại bản đồ toàn màn hình
  final bool enableFullScreen;

  const EduVaultMapWidget({
    super.key,
    this.latitude,
    this.longitude,
    this.locationTitle,
    this.locationSubtitle,
    this.height = 280,
    this.isPicker = false,
    this.onCoordinatesChanged,
    this.onTapSetLocation,
    this.externalController,
    this.enableFullScreen = true,
  });

  @override
  State<EduVaultMapWidget> createState() => _EduVaultMapWidgetState();
}

class _EduVaultMapWidgetState extends State<EduVaultMapWidget>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  LatLng? _currentPoint;
  bool _isMapReady = false;

  // Hiệu ứng Animation Radar Pulse cho marker
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // Tọa độ trung tâm mặc định (Đại học Bách Khoa Hà Nội - Thư viện Tạ Quang Bửu)
  static const LatLng _kDefaultCenter = LatLng(21.0049, 105.8433);

  @override
  void initState() {
    super.initState();
    _mapController = widget.externalController ?? MapController();
    if (_isValidCoordinate(widget.latitude, widget.longitude)) {
      _currentPoint = LatLng(widget.latitude!, widget.longitude!);
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeOutQuad,
    );
  }

  @override
  void dispose() {
    _isMapReady = false;
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EduVaultMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.latitude != oldWidget.latitude ||
        widget.longitude != oldWidget.longitude) {
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
    if (lat == 0.0 && lng == 0.0) return false;
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
        _mapController.move(_currentPoint!, 16.5);
      } else {
        _mapController.move(_kDefaultCenter, 15.0);
      }
    } catch (_) {}
  }

  Future<void> _openExternalDirections() async {
    final target = _currentPoint ?? _kDefaultCenter;
    final url =
        'https://www.google.com/maps/search/?api=1&query=${target.latitude},${target.longitude}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openFullScreenMap(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 850,
            height: 600,
            color: const Color(0xFF0F172A),
            child: Stack(
              children: [
                EduVaultMapWidget(
                  latitude: widget.latitude,
                  longitude: widget.longitude,
                  locationTitle: widget.locationTitle,
                  locationSubtitle: widget.locationSubtitle,
                  height: double.infinity,
                  isPicker: widget.isPicker,
                  onCoordinatesChanged: widget.onCoordinatesChanged,
                  enableFullScreen: false,
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.map_rounded, size: 16, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          widget.locationTitle ?? 'Bản đồ vị trí tài liệu',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasValidPoint = _currentPoint != null;
    final initialCenter = _currentPoint ?? _kDefaultCenter;
    final initialZoom = hasValidPoint ? 16.5 : 14.5;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasValidPoint
                ? AppTheme.primaryColor.withValues(alpha: 0.5)
                : Colors.amber.withValues(alpha: 0.4),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Lớp bản đồ OpenStreetMap luôn luôn được render trực quan
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: initialZoom,
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
                  userAgentPackageName: 'com.docushare.app',
                  maxZoom: 19,
                ),

                // Lớp Marker chính (vị trí tài liệu hoặc tâm khuôn viên)
                MarkerLayer(
                  markers: [
                    if (hasValidPoint)
                      Marker(
                        point: _currentPoint!,
                        width: 70,
                        height: 70,
                        alignment: Alignment.center,
                        child: _buildPulsingMarker(
                          isRealCoord: true,
                          title: widget.locationTitle ?? 'Vị trí tài liệu',
                        ),
                      )
                    else
                      Marker(
                        point: _kDefaultCenter,
                        width: 60,
                        height: 60,
                        alignment: Alignment.center,
                        child: _buildPulsingMarker(
                          isRealCoord: false,
                          title: 'Khuôn viên trường (Mặc định)',
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // Banner trạng thái trên cùng: Hiển thị tọa độ hoặc hướng dẫn
            Positioned(
              top: 10,
              left: 10,
              right: 60,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasValidPoint
                        ? AppTheme.primaryColor.withValues(alpha: 0.6)
                        : Colors.amber.withValues(alpha: 0.6),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isPicker
                          ? Icons.touch_app_rounded
                          : (hasValidPoint
                              ? Icons.location_on_rounded
                              : Icons.info_outline_rounded),
                      color: hasValidPoint ? AppTheme.primaryColor : Colors.amber,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.isPicker
                            ? (_currentPoint != null
                                ? 'Đã chọn: ${_currentPoint!.latitude.toStringAsFixed(4)}°, ${_currentPoint!.longitude.toStringAsFixed(4)}°'
                                : 'Chạm trên bản đồ để chọn tọa độ lưu trữ')
                            : (hasValidPoint
                                ? (widget.locationTitle != null && widget.locationTitle!.isNotEmpty
                                    ? widget.locationTitle!
                                    : 'Tọa độ: ${_currentPoint!.latitude.toStringAsFixed(4)}°, ${_currentPoint!.longitude.toStringAsFixed(4)}°')
                                : 'Bản đồ tham chiếu (Tài liệu chưa ghim GPS cụ thể)'),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Cột nút điều khiển ở góc phải (Zoom, Về vị trí, Mở toàn màn hình)
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
                  const SizedBox(height: 6),
                  _buildMapControlButton(
                    icon: Icons.my_location_rounded,
                    tooltip: hasValidPoint ? 'Về vị trí tài liệu' : 'Về trung tâm trường',
                    onTap: _recenter,
                    iconColor: hasValidPoint ? AppTheme.primaryColor : Colors.amber,
                  ),
                  if (widget.enableFullScreen) ...[
                    const SizedBox(height: 6),
                    _buildMapControlButton(
                      icon: Icons.fullscreen_rounded,
                      tooltip: 'Mở bản đồ lớn',
                      onTap: () => _openFullScreenMap(context),
                      iconColor: Colors.white,
                    ),
                  ],
                ],
              ),
            ),

            // Nút Thao tác ở góc dưới trái (Chỉ đường hoặc Thiết lập vị trí)
            Positioned(
              bottom: 10,
              left: 10,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!widget.isPicker) ...[
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B).withValues(alpha: 0.95),
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: hasValidPoint
                              ? AppTheme.primaryColor.withValues(alpha: 0.4)
                              : Colors.amber.withValues(alpha: 0.4),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _openExternalDirections,
                      icon: const Icon(Icons.directions_rounded, size: 15, color: Colors.amber),
                      label: Text(
                        hasValidPoint ? 'Chỉ đường' : 'Mở Google Maps',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  if (!widget.isPicker && !hasValidPoint && widget.onTapSetLocation != null) ...[
                    const SizedBox(width: 6),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.amber.withValues(alpha: 0.2),
                        foregroundColor: Colors.amber,
                        side: const BorderSide(color: Colors.amber),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: widget.onTapSetLocation,
                      icon: const Icon(Icons.add_location_alt_rounded, size: 14),
                      label: const Text(
                        'Ghim vị trí',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Attribution bản quyền OpenStreetMap góc dưới phải
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
                  '© OpenStreetMap',
                  style: TextStyle(fontSize: 8.5, color: Colors.white60),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Marker có hiệu ứng sóng radar ping và icon sách
  Widget _buildPulsingMarker({
    required bool isRealCoord,
    required String title,
  }) {
    final baseColor = isRealCoord ? AppTheme.primaryColor : Colors.amber;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Vòng sóng radar tỏa ra
            if (isRealCoord)
              Container(
                width: 32 + (_pulseAnimation.value * 28),
                height: 32 + (_pulseAnimation.value * 28),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: baseColor.withValues(
                    alpha: (1.0 - _pulseAnimation.value) * 0.35,
                  ),
                  border: Border.all(
                    color: baseColor.withValues(
                      alpha: (1.0 - _pulseAnimation.value) * 0.7,
                    ),
                    width: 1.5,
                  ),
                ),
              ),

            // Lõi marker chính
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: baseColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: baseColor.withValues(alpha: 0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                isRealCoord ? Icons.menu_book_rounded : Icons.school_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color iconColor = AppTheme.textPrimary,
  }) {
    return Material(
      color: const Color(0xFF1E293B).withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.borderSubtle),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
        ),
      ),
    );
  }
}
