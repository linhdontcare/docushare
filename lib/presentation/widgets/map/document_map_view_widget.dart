// ==============================================================================
// PRESENTATION WIDGET: document_map_view_widget.dart
// Bản đồ số tích hợp OpenStreetMap (flutter_map) trực quan hóa vị trí vật lý
// của toàn bộ tài liệu học tập trong khuôn viên trường / thư viện.
// Hỗ trợ marker nhóm theo tọa độ, lọc danh mục/tag, xem chi tiết và chỉ đường.
// ==============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/models/document_model.dart';
import '../../providers/document_provider.dart';
import '../borrow_request_dialog.dart';

class DocumentMapViewWidget extends StatefulWidget {
  final List<DocumentModel> documents;
  final ValueChanged<DocumentModel>? onDocumentTap;
  final VoidCallback? onSwitchToListView;

  const DocumentMapViewWidget({
    super.key,
    required this.documents,
    this.onDocumentTap,
    this.onSwitchToListView,
  });

  @override
  State<DocumentMapViewWidget> createState() => _DocumentMapViewWidgetState();
}

class _DocumentMapViewWidgetState extends State<DocumentMapViewWidget> {
  final MapController _mapController = MapController();
  DocumentModel? _selectedDocument;
  List<DocumentModel> _selectedCluster = [];
  bool _isMapReady = false;

  // Tọa độ mặc định (Khuôn viên Đại học Bách Khoa Hà Nội)
  static const LatLng _kDefaultCenter = LatLng(21.0049, 105.8433);

  @override
  void didUpdateWidget(covariant DocumentMapViewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedDocument != null &&
        !widget.documents.any((d) => d.id == _selectedDocument!.id)) {
      setState(() {
        _selectedDocument = null;
        _selectedCluster = [];
      });
    }
  }

  // Lọc danh sách tài liệu có tọa độ hợp lệ
  List<DocumentModel> get _docsWithCoordinates =>
      widget.documents.where((d) => d.hasCoordinates).toList();

  // Danh sách tài liệu có vị trí vật lý dạng text nhưng chưa có tọa độ GPS
  List<DocumentModel> get _docsTextOnlyLocation => widget.documents
      .where((d) => d.hasPhysicalLocation && !d.hasCoordinates)
      .toList();

  Color _parseColor(String? hexString, Color fallback) {
    if (hexString == null || hexString.isEmpty) return fallback;
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  LatLng _computeCenter() {
    final docs = _docsWithCoordinates;
    if (docs.isEmpty) return _kDefaultCenter;
    if (docs.length == 1) return LatLng(docs.first.latitude!, docs.first.longitude!);

    double sumLat = 0;
    double sumLng = 0;
    for (final d in docs) {
      sumLat += d.latitude!;
      sumLng += d.longitude!;
    }
    return LatLng(sumLat / docs.length, sumLng / docs.length);
  }


  void _recenterAll() {
    final docs = _docsWithCoordinates;
    if (docs.isEmpty || !_isMapReady) {
      _mapController.move(_kDefaultCenter, 15.0);
      return;
    }

    if (docs.length == 1) {
      _mapController.move(LatLng(docs.first.latitude!, docs.first.longitude!), 16.5);
      return;
    }

    double minLat = docs.first.latitude!;
    double maxLat = docs.first.latitude!;
    double minLng = docs.first.longitude!;
    double maxLng = docs.first.longitude!;

    for (final d in docs) {
      if (d.latitude! < minLat) minLat = d.latitude!;
      if (d.latitude! > maxLat) maxLat = d.latitude!;
      if (d.longitude! < minLng) minLng = d.longitude!;
      if (d.longitude! > maxLng) maxLng = d.longitude!;
    }

    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
          maxZoom: 17.5,
        ),
      );
    } catch (_) {
      _mapController.move(_computeCenter(), 15.5);
    }
  }

  // Nhóm các tài liệu có tọa độ rất gần nhau (dưới ~15m) để tránh đè marker
  Map<String, List<DocumentModel>> _groupNearbyDocuments() {
    final groups = <String, List<DocumentModel>>{};
    for (final doc in _docsWithCoordinates) {
      // Làm tròn 4 chữ số thập phân (~11m sai số)
      final key = '${doc.latitude!.toStringAsFixed(4)},${doc.longitude!.toStringAsFixed(4)}';
      groups.putIfAbsent(key, () => []).add(doc);
    }
    return groups;
  }

  Future<void> _openDirections(DocumentModel doc) async {
    final url = doc.googleMapsUrl;
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showTextOnlyLocationsDialog() {
    final textDocs = _docsTextOnlyLocation;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.borderSubtle),
        ),
        title: Row(
          children: [
            const Icon(Icons.place_outlined, color: Colors.amber, size: 22),
            const SizedBox(width: 8),
            Text(
              'Vị trí chưa có GPS (${textDocs.length})',
              style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: textDocs.isEmpty
              ? const Text(
                  'Tất cả tài liệu đều đã được thiết lập tọa độ GPS trên bản đồ.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: textDocs.length,
                  separatorBuilder: (context, index) => const Divider(color: AppTheme.borderSubtle, height: 16),
                  itemBuilder: (context, index) {
                    final d = textDocs[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        d.title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        d.formattedLocationAddress ?? d.displayLocationName,
                        style: const TextStyle(fontSize: 12, color: Colors.amber),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textSecondary),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        widget.onDocumentTap?.call(d);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng', style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docsWithCoords = _docsWithCoordinates;
    final textDocs = _docsTextOnlyLocation;
    final initialCenter = _computeCenter();
    final groupedMarkers = _groupNearbyDocuments();

    return Stack(
      children: [
        // Lớp Bản đồ OpenStreetMap
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: docsWithCoords.isNotEmpty ? 15.5 : 14.0,
            minZoom: 4.0,
            maxZoom: 18.5,
            onTap: (tapPosition, point) {
              if (_selectedDocument != null) {
                setState(() {
                  _selectedDocument = null;
                  _selectedCluster = [];
                });
              }
            },
            onMapReady: () {
              if (mounted) {
                setState(() => _isMapReady = true);
                if (docsWithCoords.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _recenterAll());
                }
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

            // Lớp Markers cho từng vị trí
            MarkerLayer(
              markers: groupedMarkers.entries.map((entry) {
                final cluster = entry.value;
                final firstDoc = cluster.first;
                final point = LatLng(firstDoc.latitude!, firstDoc.longitude!);
                final isSelected = _selectedCluster.any((d) => cluster.any((c) => c.id == d.id));
                final count = cluster.length;
                final categoryColor = _parseColor(firstDoc.categoryColorHex, AppTheme.primaryColor);

                return Marker(
                  point: point,
                  width: isSelected ? 56 : (count > 1 ? 50 : 44),
                  height: isSelected ? 56 : (count > 1 ? 50 : 44),
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCluster = cluster;
                        _selectedDocument = cluster.first;
                      });
                      try {
                        _mapController.move(point, math.max(_mapController.camera.zoom, 16.5));
                      } catch (_) {}
                    },
                    child: _buildMarkerIcon(
                      color: categoryColor,
                      isSelected: isSelected,
                      count: count,
                      firstDoc: firstDoc,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // Thanh công cụ phía trên Bản đồ
        Positioned(
          top: 14,
          left: 14,
          right: 14,
          child: Row(
            children: [
              // Badge thống kê số tài liệu có vị trí GPS
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.place_rounded, size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 6),
                    Text(
                      '${docsWithCoords.length} tài liệu có vị trí GPS',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Nút xem tài liệu chỉ có vị trí chữ nếu có
              if (textDocs.isNotEmpty)
                InkWell(
                  onTap: _showTextOnlyLocationsDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 14, color: Colors.amber),
                        const SizedBox(width: 5),
                        Text(
                          '+${textDocs.length} vị trí chữ',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const Spacer(),

              // Nút quay lại chế độ danh sách
              if (widget.onSwitchToListView != null)
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.cardBackground.withValues(alpha: 0.95),
                    foregroundColor: AppTheme.textPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppTheme.borderSubtle),
                    ),
                  ),
                  onPressed: widget.onSwitchToListView,
                  icon: const Icon(Icons.grid_view_rounded, size: 16, color: AppTheme.primaryColor),
                  label: const Text('Danh sách', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),

        // Cụm nút điều khiển Zoom và Recenter bên phải
        Positioned(
          right: 14,
          top: 70,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMapActionButton(
                icon: Icons.my_location_rounded,
                tooltip: 'Căn chỉnh tất cả vị trí',
                onPressed: _recenterAll,
              ),
              const SizedBox(height: 8),
              _buildMapActionButton(
                icon: Icons.add_rounded,
                tooltip: 'Phóng to',
                onPressed: () {
                  try {
                    _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
                  } catch (_) {}
                },
              ),
              const SizedBox(height: 6),
              _buildMapActionButton(
                icon: Icons.remove_rounded,
                tooltip: 'Thu nhỏ',
                onPressed: () {
                  try {
                    _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
                  } catch (_) {}
                },
              ),
            ],
          ),
        ),

        // Thông báo nếu không có tài liệu nào có GPS
        if (docsWithCoords.isEmpty)
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_off_rounded, size: 36, color: Colors.amber),
                  const SizedBox(height: 10),
                  const Text(
                    'Chưa có tài liệu nào có tọa độ GPS trong bộ lọc hiện tại',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Bạn có thể gán tọa độ GPS khi Thêm mới hoặc Chỉnh sửa tài liệu để quản lý vị trí vật lý trên bản đồ.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.onSwitchToListView != null) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: widget.onSwitchToListView,
                      icon: const Icon(Icons.grid_view_rounded, size: 16),
                      label: const Text('Xem danh sách tài liệu'),
                    ),
                  ],
                ],
              ),
            ),
          ),

        // Card chi tiết tài liệu được chọn tại vị trí pin
        if (_selectedDocument != null)
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: _buildSelectedDocumentCard(_selectedDocument!),
          ),
      ],
    );
  }

  Widget _buildMarkerIcon({
    required Color color,
    required bool isSelected,
    required int count,
    required DocumentModel firstDoc,
  }) {
    return AnimatedScale(
      scale: isSelected ? 1.15 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: isSelected ? 48 : 40,
            height: isSelected ? 48 : 40,
            decoration: BoxDecoration(
              color: isSelected ? color : AppTheme.cardBackground,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : color,
                width: isSelected ? 3.0 : 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isSelected ? color : Colors.black).withValues(alpha: 0.4),
                  blurRadius: isSelected ? 12 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.menu_book_rounded,
                size: isSelected ? 22 : 18,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ),
          if (count > 1)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cardBackground, width: 1.5),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: AppTheme.textPrimary),
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildSelectedDocumentCard(DocumentModel doc) {
    final categoryColor = _parseColor(doc.categoryColorHex, AppTheme.primaryColor);
    final hasMultiple = _selectedCluster.length > 1;

    return Container(
      constraints: const BoxConstraints(maxWidth: 650),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: categoryColor.withValues(alpha: 0.5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Category Badge + Multiple indicator + Close button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: categoryColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  doc.categoryName ?? 'Tài liệu',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: categoryColor,
                  ),
                ),
              ),
              if (hasMultiple) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Cùng vị trí (${_selectedCluster.indexOf(doc) + 1}/${_selectedCluster.length})',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.amber),
                  ),
                ),
              ],
              const Spacer(),
              if (hasMultiple) ...[
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Tài liệu trước',
                  onPressed: () {
                    final currIdx = _selectedCluster.indexOf(doc);
                    final prevIdx = (currIdx - 1 + _selectedCluster.length) % _selectedCluster.length;
                    setState(() => _selectedDocument = _selectedCluster[prevIdx]);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Tài liệu kế tiếp',
                  onPressed: () {
                    final currIdx = _selectedCluster.indexOf(doc);
                    final nextIdx = (currIdx + 1) % _selectedCluster.length;
                    setState(() => _selectedDocument = _selectedCluster[nextIdx]);
                  },
                ),
                const SizedBox(width: 4),
              ],
              InkWell(
                onTap: () => setState(() {
                  _selectedDocument = null;
                  _selectedCluster = [];
                }),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.close_rounded, size: 18, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Tiêu đề tài liệu
          Text(
            doc.title,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 4),

          // Môn học & Chủ sở hữu
          Text(
            'Môn học: ${doc.subject.isNotEmpty ? doc.subject : "Chưa chỉ định"}${doc.ownerName != null ? " • Người đăng: ${doc.ownerName}" : ""}',
            style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 8),

          // Vị trí vật lý chi tiết kèm nút Lọc tài liệu tại đây
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppTheme.scaffoldBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Row(
              children: [
                const Icon(Icons.place_rounded, size: 16, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    doc.formattedLocationAddress ?? doc.displayLocationName,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    final targetLoc = doc.locationName ?? doc.displayLocationName;
                    context.read<DocumentProvider>().setLocationFilter(targetLoc);
                    if (widget.onSwitchToListView != null) {
                      widget.onSwitchToListView!();
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Đang lọc tài liệu tại: $targetLoc'),
                        backgroundColor: AppTheme.primaryColor,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.filter_alt_rounded, size: 12, color: Colors.amber),
                        SizedBox(width: 4),
                        Text(
                          'Lọc tại đây',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tags nếu có
          if (doc.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: doc.tags.take(6).map((t) {
                final isSelected = context.watch<DocumentProvider>().selectedTags.any(
                      (selected) => selected.toLowerCase() == t.toLowerCase(),
                    );
                return InkWell(
                  onTap: () {
                    context.read<DocumentProvider>().toggleTagFilter(t);
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : AppTheme.primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? Icons.check_rounded : Icons.tag_rounded,
                          size: 10,
                          color: isSelected ? Colors.white : AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '#$t',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 12),

          // Hàng nút thao tác: Xem chi tiết & Chỉ đường Google Maps & Mượn sách
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => widget.onDocumentTap?.call(doc),
                  icon: const Icon(Icons.visibility_rounded, size: 16),
                  label: const Text('Xem chi tiết', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              if (doc.googleMapsUrl != null) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amber,
                    side: const BorderSide(color: Colors.amber),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _openDirections(doc),
                  icon: const Icon(Icons.navigation_rounded, size: 16),
                  label: const Text('Chỉ đường', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
              ],
              if (!doc.isOwner && (doc.isBorrowable || doc.isAvailableForBorrow))
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.cyanAccent.withValues(alpha: 0.2),
                    foregroundColor: Colors.cyanAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => BorrowRequestDialog(document: doc),
                    );
                  },
                  child: const Text('Mượn', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
