import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import 'create_borrowing_dialog.dart';

/// Màn hình Quản lý Mượn - Trả Tài liệu (Borrowing Feature)
/// Quản lý quy trình mượn, gia hạn, trả tài liệu và hạn chót
class BorrowingPage extends StatefulWidget {
  const BorrowingPage({super.key});

  @override
  State<BorrowingPage> createState() => _BorrowingPageState();
}

class _BorrowingPageState extends State<BorrowingPage> {
  final List<Map<String, dynamic>> borrowings = [
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
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  onPressed: () async {
                    final result = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (context) => const CreateBorrowingDialog(),
                    );

                    if (!mounted) return;

                    if (result != null) {
                      setState(() {
                        borrowings.insert(0, result);
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tạo phiếu mượn thành công!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
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
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusMedium,
                            ),
                          ),
                          child: Icon(
                            Icons.assignment_outlined,
                            color: statusColor,
                            size: 28,
                          ),
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

                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Chip(
                              label: Text(
                                b['status'] as String,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: statusColor.withValues(
                                alpha: 0.1,
                              ),
                            ),
                            if (b['status'] != 'Đã trả')
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    b['status'] = 'Đã trả';
                                    b['daysLeft'] = 'Đã hoàn tất';
                                    b['statusColor'] = AppColors.success;
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Trả tài liệu thành công!'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.assignment_turned_in),
                                label: const Text('Trả tài liệu'),
                              ),

                            if (b['status'] != 'Đã trả')
                              TextButton.icon(
                                onPressed: () {
                                  final parts = (b['dueDate'] as String).split(
                                    '/',
                                  );
                                  final oldDate = DateTime(
                                    int.parse(parts[2]),
                                    int.parse(parts[1]),
                                    int.parse(parts[0]),
                                  );

                                  final newDate = oldDate.add(
                                    const Duration(days: 7),
                                  );

                                  setState(() {
                                    b['dueDate'] =
                                        '${newDate.day.toString().padLeft(2, '0')}/'
                                        '${newDate.month.toString().padLeft(2, '0')}/'
                                        '${newDate.year}';
                                    b['daysLeft'] = 'Đã gia hạn thêm 7 ngày';
                                    b['status'] = 'Đang mượn';
                                    b['statusColor'] = AppColors.info;
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Gia hạn tài liệu thành công!',
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.update),
                                label: const Text('Gia hạn'),
                              ),
                          ],
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
