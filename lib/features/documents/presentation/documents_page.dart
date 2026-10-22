import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';

/// Màn hình Quản lý Tài liệu (Documents Feature)
/// Công nghệ dự kiến: Supabase Database (metadata) & Supabase Storage (file đính kèm)
class DocumentsPage extends StatelessWidget {
  const DocumentsPage({super.key});

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
                        'Quản lý Tài liệu',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kho lưu trữ giáo trình, đề thi, bài giảng và tài liệu nghiên cứu.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tính năng tải lên tài liệu sẽ kết nối Supabase Storage.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Tải lên'),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            // Search and filter bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm theo tên tài liệu, tác giả, mã học phần...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.tune),
                        onPressed: () {},
                        tooltip: 'Bộ lọc nâng cao',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Tất cả'),
                  selected: true,
                  onSelected: (_) {},
                ),
                FilterChip(
                  label: const Text('Giáo trình (PDF)'),
                  selected: false,
                  onSelected: (_) {},
                ),
                FilterChip(
                  label: const Text('Đề thi & Đáp án'),
                  selected: false,
                  onSelected: (_) {},
                ),
                FilterChip(
                  label: const Text('Slide bài giảng'),
                  selected: false,
                  onSelected: (_) {},
                ),
                FilterChip(
                  label: const Text('Báo cáo đồ án'),
                  selected: false,
                  onSelected: (_) {},
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            // Sample Document List Cards
            _buildSampleDocCard(
              context,
              title: 'Giáo trình Cấu trúc Dữ liệu & Giải thuật',
              author: 'Khoa CNTT - ĐH Quốc Gia',
              type: 'PDF • 4.8 MB',
              category: 'Cơ sở ngành',
              status: 'Có sẵn',
              statusColor: AppColors.success,
              icon: Icons.menu_book,
            ),
            const SizedBox(height: 12),
            _buildSampleDocCard(
              context,
              title: 'Đề thi & Lời giải Kiến trúc Máy tính 2024',
              author: 'Bộ môn Kỹ thuật Máy tính',
              type: 'PDF • 2.1 MB',
              category: 'Đề thi',
              status: 'Đang mượn',
              statusColor: AppColors.warning,
              icon: Icons.quiz_outlined,
            ),
            const SizedBox(height: 12),
            _buildSampleDocCard(
              context,
              title: 'Slide Bài giảng Lập trình Thiết bị Di động (Flutter)',
              author: 'ThS. Nguyễn Văn A',
              type: 'ZIP/PPTX • 18.5 MB',
              category: 'Chuyên ngành',
              status: 'Có sẵn',
              statusColor: AppColors.success,
              icon: Icons.slideshow_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSampleDocCard(
    BuildContext context, {
    required String title,
    required String author,
    required String type,
    required String category,
    required String status,
    required Color statusColor,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              ),
              child: Icon(icon, color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$author • $type',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                        ),
                        child: Text(
                          category,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                        ),
                        child: Text(
                          status,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {},
              tooltip: 'Tùy chọn',
            ),
          ],
        ),
      ),
    );
  }
}
