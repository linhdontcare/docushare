import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';

/// Màn hình Định vị & Quản lý Kho Lưu trữ (Location Feature)
/// Quản lý vị trí vật lý (Tủ sách, ngăn kệ) và vị trí số (Thư mục đám mây)
class LocationPage extends StatelessWidget {
  const LocationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final locations = [
      {'code': 'KHO-A1', 'name': 'Phòng Đọc 1 - Tủ A (Kệ 1, 2, 3)', 'capacity': '85/100', 'status': 'Còn chỗ'},
      {'code': 'KHO-B2', 'name': 'Khu Tự Học - Tủ B (Tài liệu tham khảo)', 'capacity': '98/100', 'status': 'Gần đầy'},
      {'code': 'KHO-C1', 'name': 'Kho Lưu trữ Báo cáo Đồ án tốt nghiệp', 'capacity': '40/50', 'status': 'Còn chỗ'},
    ];

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vị trí & Kho lưu trữ',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Định vị nhanh tài liệu vật lý theo tủ sách, ngăn kệ và mã QR.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Quét mã vị trí'),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            ...locations.map((loc) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(AppConstants.paddingMedium),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                      ),
                      child: const Icon(Icons.place_outlined, color: AppColors.secondary),
                    ),
                    title: Text(
                      loc['name']!,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text('Mã vị trí: ${loc['code']} • Sức chứa: ${loc['capacity']}'),
                    ),
                    trailing: Chip(
                      label: Text(loc['status']!),
                      backgroundColor: loc['status'] == 'Còn chỗ'
                          ? AppColors.success.withValues(alpha: 0.1)
                          : AppColors.warning.withValues(alpha: 0.1),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
