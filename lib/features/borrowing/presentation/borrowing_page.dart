import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';

/// Màn hình Quản lý Mượn - Trả Tài liệu (Borrowing Feature)
/// Quản lý quy trình mượn, gia hạn, trả tài liệu và hạn chót
class BorrowingPage extends StatelessWidget {
  const BorrowingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final borrowings = [
      {
        'docTitle': 'Giáo trình Cấu trúc Dữ liệu & Giải thuật',
        'borrower': 'Nguyễn Văn B (MSSV: 2102001)',
        'dueDate': '28/10/2026',
        'daysLeft': 'Còn 6 ngày',
        'status': 'Đang mượn',
        'statusColor': AppColors.info,
      },
      {
        'docTitle': 'Lập trình Thiết bị Di động Nâng cao',
        'borrower': 'Trần Thị C (MSSV: 2102002)',
        'dueDate': '23/10/2026',
        'daysLeft': 'Hết hạn ngày mai',
        'status': 'Sắp đến hạn',
        'statusColor': AppColors.warning,
      },
      {
        'docTitle': 'Kiến trúc Máy tính và Hợp ngữ',
        'borrower': 'Lê Văn D (MSSV: 2102003)',
        'dueDate': '15/10/2026',
        'daysLeft': 'Đã hoàn tất',
        'status': 'Đã trả',
        'statusColor': AppColors.success,
      },
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
                        'Quản lý Mượn - Trả',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Theo dõi trạng thái mượn trả, hạn chót và thông báo nhắc nhở.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Tạo phiếu mượn'),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            ...borrowings.map((b) {
              final statusColor = b['statusColor'] as Color;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.paddingMedium),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                          ),
                          child: Icon(Icons.assignment_outlined, color: statusColor, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b['docTitle'] as String,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                b['borrower'] as String,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Hạn trả: ${b['dueDate']} (${b['daysLeft']})',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Chip(
                          label: Text(
                            b['status'] as String,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: statusColor.withValues(alpha: 0.1),
                        ),
                      ],
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
