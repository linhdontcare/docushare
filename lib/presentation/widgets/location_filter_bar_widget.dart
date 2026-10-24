// ==============================================================================
// PRESENTATION WIDGET: location_filter_bar_widget.dart
// Thanh cuộn lọc và phân loại tài liệu theo Vị trí vật lý (Location Classification)
// Hỗ trợ chọn nhanh các cơ sở thư viện, tòa nhà (vd: Thư viện Tạ Quang Bửu)
// Kèm badge hiển thị số lượng tài liệu thực tế tại từng địa điểm.
// ==============================================================================

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class LocationFilterBarWidget extends StatelessWidget {
  final List<String> locations;
  final String? selectedLocation;
  final ValueChanged<String?> onLocationSelected;
  final int Function(String location)? countDocumentsAtLocation;

  const LocationFilterBarWidget({
    super.key,
    required this.locations,
    required this.selectedLocation,
    required this.onLocationSelected,
    this.countDocumentsAtLocation,
  });

  @override
  Widget build(BuildContext context) {
    final isAllSelected = selectedLocation == null || selectedLocation!.isEmpty;

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: locations.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            // Chip "Tất cả vị trí"
            return ChoiceChip(
              avatar: Icon(
                isAllSelected ? Icons.check_circle_rounded : Icons.map_outlined,
                size: 14,
                color: isAllSelected ? Colors.black : AppTheme.textSecondary,
              ),
              label: const Text('Tất cả vị trí', style: TextStyle(fontSize: 11.5)),
              selected: isAllSelected,
              onSelected: (_) => onLocationSelected(null),
              selectedColor: Colors.amber,
              backgroundColor: AppTheme.cardBackground,
              labelStyle: TextStyle(
                color: isAllSelected ? Colors.black : AppTheme.textSecondary,
                fontWeight: isAllSelected ? FontWeight.bold : FontWeight.w500,
              ),
              side: BorderSide(
                color: isAllSelected ? Colors.amber : AppTheme.borderSubtle,
                width: isAllSelected ? 1.5 : 1,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            );
          }

          final loc = locations[index - 1];
          final isSelected = selectedLocation != null &&
              selectedLocation!.trim().toLowerCase() == loc.trim().toLowerCase();
          final count = countDocumentsAtLocation?.call(loc) ?? 0;

          // Rút gọn tên hiển thị nếu quá dài
          String displayLoc = loc;
          if (displayLoc.contains('(') && displayLoc.contains(')')) {
            // Giữ nguyên hoặc hiển thị gọn gàng
          }

          return ChoiceChip(
            avatar: Icon(
              isSelected ? Icons.check_circle_rounded : Icons.place_rounded,
              size: 14,
              color: isSelected ? Colors.black : Colors.amber,
            ),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayLoc,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isSelected ? Colors.black : AppTheme.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black26 : Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.black : Colors.amber,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            selected: isSelected,
            onSelected: (_) {
              if (isSelected) {
                onLocationSelected(null);
              } else {
                onLocationSelected(loc);
              }
            },
            selectedColor: Colors.amber,
            backgroundColor: isSelected
                ? Colors.amber.withValues(alpha: 0.2)
                : AppTheme.cardBackground,
            side: BorderSide(
              color: isSelected ? Colors.amber : AppTheme.borderSubtle,
              width: isSelected ? 1.5 : 1,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          );
        },
      ),
    );
  }
}
