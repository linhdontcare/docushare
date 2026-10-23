// ==============================================================================
// PRESENTATION LAYER: Document Card Widget (Deep Tech Emerald)
// Tuân thủ nghiêm ngặt Flutter Box Model: Card, Padding, Margin, Row, Column.
// Áp dụng nhận diện phong cách Deep Tech Emerald:
// - Card Background: Dark Slate (#1E293B) với BorderRadius.circular(16)
// - Primary Accent: Emerald Green (#10B981) cho các Icons, Liên kết & Badges
// - Text Colors: Pure White (#FFFFFF) cho tiêu đề & Muted Slate (#94A3B8) cho mô tả/ngày tháng
// - Tự thích nghi hoàn hảo trên cả ListView 1 cột và GridView đa cột (Responsive)
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/document_model.dart';
import '../providers/document_provider.dart';
import 'borrow_request_dialog.dart';
import 'location_picker_widget.dart';

class DocumentCard extends StatefulWidget {
  final DocumentModel document;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onShare;
  final EdgeInsetsGeometry? margin;

  const DocumentCard({
    super.key,
    required this.document,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onShare,
    this.margin,
  });

  @override
  State<DocumentCard> createState() => _DocumentCardState();
}

class _DocumentCardState extends State<DocumentCard> {
  bool _isHovered = false;

  // Chuyển đổi mã màu hex sang Color object an toàn
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

  @override
  Widget build(BuildContext context) {
    final document = widget.document;
    final categoryColor = _parseColor(document.categoryColorHex, AppTheme.primaryColor);
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(document.createdDate);

    // Box Model: Card với nền Dark Slate #1E293B và bo góc BorderRadius.circular(16)
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Card(
          elevation: 0,
          color: _isHovered
              ? Color.alphaBlend(AppTheme.primaryColor.withValues(alpha: 0.05), AppTheme.cardBackground)
              : AppTheme.cardBackground,
          margin: widget.margin ?? const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: _isHovered
                  ? AppTheme.primaryColor.withValues(alpha: 0.5)
                  : AppTheme.borderSubtle,
              width: 1.2,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Nhóm trên: Header + Tiêu đề + Môn học + Ghi chú
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Hàng trên: Category Badge, Role Badge & Popup Actions Menu
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Badge hiển thị danh mục
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: categoryColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: categoryColor.withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.folder_outlined,
                                    size: 14,
                                    color: categoryColor,
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      document.categoryName ?? 'Chưa phân loại',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: categoryColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Badge vai trò nếu tài liệu được chia sẻ
                          if (!document.isOwner) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: document.isEditor
                                    ? AppTheme.primaryColor.withValues(alpha: 0.15)
                                    : Colors.lightBlueAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: document.isEditor
                                      ? AppTheme.primaryColor.withValues(alpha: 0.4)
                                      : Colors.lightBlueAccent.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    document.isEditor ? Icons.edit_outlined : Icons.visibility_outlined,
                                    size: 12,
                                    color: document.isEditor ? AppTheme.primaryColor : Colors.lightBlueAccent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    document.isEditor ? 'Editor' : 'Viewer',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: document.isEditor ? AppTheme.primaryColor : Colors.lightBlueAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const Spacer(),

                          // Menu tùy chọn theo phân quyền & nghiệp vụ
                          if (document.canEdit ||
                              document.canShare ||
                              document.canDelete ||
                              document.hasPhysicalLocation ||
                              (!document.isOwner && (document.isBorrowable || document.isAvailableForBorrow)))
                            PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_horiz_rounded,
                                color: AppTheme.textSecondary,
                              ),
                              color: AppTheme.cardBackground,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(color: AppTheme.borderSubtle),
                              ),
                              onSelected: (value) {
                                if (value == 'share') {
                                  widget.onShare?.call();
                                } else if (value == 'edit') {
                                  widget.onEdit();
                                } else if (value == 'delete') {
                                  widget.onDelete();
                                } else if (value == 'location' && document.hasPhysicalLocation) {
                                  showLocationDetailDialog(
                                    context,
                                    title: document.title,
                                    physicalLocation: document.formattedLocationAddress ?? document.displayLocationName,
                                    locationName: document.locationName,
                                    building: document.building,
                                    floor: document.floor,
                                    shelf: document.shelf,
                                    latitude: document.latitude,
                                    longitude: document.longitude,
                                    notes: document.locationNotes,
                                  );
                                } else if (value == 'borrow') {
                                  showDialog(
                                    context: context,
                                    builder: (_) => BorrowRequestDialog(document: document),
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                if (document.hasPhysicalLocation)
                                  const PopupMenuItem(
                                    value: 'location',
                                    child: Row(
                                      children: [
                                        Icon(Icons.place_rounded, size: 18, color: Colors.amber),
                                        SizedBox(width: 8),
                                        Text('Vị trí & Bản đồ', style: TextStyle(color: AppTheme.textPrimary)),
                                      ],
                                    ),
                                  ),
                                if (!document.isOwner && (document.isBorrowable || document.isAvailableForBorrow))
                                  const PopupMenuItem(
                                    value: 'borrow',
                                    child: Row(
                                      children: [
                                        Icon(Icons.swap_horiz_rounded, size: 18, color: AppTheme.primaryColor),
                                        SizedBox(width: 8),
                                        Text('Mượn tài liệu', style: TextStyle(color: AppTheme.textPrimary)),
                                      ],
                                    ),
                                  ),
                                if (document.canShare)
                                  const PopupMenuItem(
                                    value: 'share',
                                    child: Row(
                                      children: [
                                        Icon(Icons.share_outlined, size: 18, color: Colors.cyanAccent),
                                        SizedBox(width: 8),
                                        Text('Chia sẻ', style: TextStyle(color: AppTheme.textPrimary)),
                                      ],
                                    ),
                                  ),
                                if (document.canEdit)
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryColor),
                                        SizedBox(width: 8),
                                        Text('Chỉnh sửa', style: TextStyle(color: AppTheme.textPrimary)),
                                      ],
                                    ),
                                  ),
                                if (document.canDelete)
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Xóa tài liệu', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Tiêu đề tài liệu
                      Text(
                        document.title,
                        style: const TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 6),

                      // Môn học liên quan
                      Row(
                        children: [
                          const Icon(
                            Icons.school_outlined,
                            size: 15,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Môn học: ${document.subject}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      // Hiển thị người chia sẻ nếu là tài liệu được chia sẻ
                      if (!document.isOwner && (document.ownerEmail != null || document.ownerName != null)) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_pin_circle_outlined,
                              size: 14,
                              color: Colors.cyanAccent,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'Chia sẻ bởi: ${document.ownerName ?? document.ownerEmail}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.cyanAccent,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Vị trí vật lý lưu trữ (nếu có)
                      if (document.hasPhysicalLocation) ...[
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => showLocationDetailDialog(
                            context,
                            title: document.title,
                            physicalLocation: document.formattedLocationAddress ?? document.displayLocationName,
                            locationName: document.locationName,
                            building: document.building,
                            floor: document.floor,
                            shelf: document.shelf,
                            latitude: document.latitude,
                            longitude: document.longitude,
                            notes: document.locationNotes,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.place_rounded, size: 13, color: Colors.amber),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    document.displayLocationName,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.amber,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (document.hasCoordinates) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.navigation_rounded, size: 11, color: Colors.amber),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],

                      // Danh sách thẻ phân loại (Tags)
                      if (document.tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: document.tags.map((tag) {
                            return InkWell(
                              onTap: () {
                                context.read<DocumentProvider>().setTagFilter(tag);
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  '#$tag',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      // Ghi chú tóm tắt nếu có
                      if (document.notes != null && document.notes!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          document.notes!.trim(),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textSecondary,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),

                  // Nhóm dưới: Divider + File/Link info + Nút Mượn + Ngày tháng
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      const Divider(height: 1, thickness: 0.8, color: AppTheme.borderSubtle),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // Chỉ báo File hoặc Liên kết web
                          if (document.hasAttachment) ...[
                            Icon(
                              document.isWebLink ? Icons.link_rounded : Icons.attach_file_rounded,
                              size: 16,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                document.filePathOrUrl ?? '',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.primaryColor,
                                  decoration: TextDecoration.underline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ] else ...[
                            const Spacer(),
                          ],

                          // Nút Mượn tài liệu nhanh cho người dùng không phải Owner
                          if (!document.isOwner && (document.isBorrowable || document.isAvailableForBorrow)) ...[
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => BorrowRequestDialog(document: document),
                                );
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.6),
                                    width: 0.8,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.swap_horiz_rounded, size: 12, color: AppTheme.primaryColor),
                                    SizedBox(width: 3),
                                    Text(
                                      'Mượn',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(width: 8),

                          // Ngày tháng tạo
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 13,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                formattedDate,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
