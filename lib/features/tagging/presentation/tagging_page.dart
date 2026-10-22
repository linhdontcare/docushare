import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';

/// Màn hình Phân loại & Gắn thẻ Tag (Tagging Feature)
/// Quản lý hệ thống phân cấp thẻ tag, từ khóa tìm kiếm và metadata tài liệu
class TaggingPage extends StatelessWidget {
  const TaggingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final sampleTags = [
      {'name': '#Flutter', 'count': 42, 'color': AppColors.primary},
      {'name': '#Dart', 'count': 38, 'color': AppColors.info},
      {'name': '#GiaiThuat', 'count': 65, 'color': AppColors.secondary},
      {'name': '#CoSoDuLieu', 'count': 51, 'color': AppColors.tertiary},
      {'name': '#MangMayTinh', 'count': 29, 'color': AppColors.warning},
      {'name': '#TriTueNhanTao', 'count': 34, 'color': AppColors.success},
      {'name': '#DeThiMau', 'count': 88, 'color': AppColors.error},
      {'name': '#GiaoTrinhChuan', 'count': 73, 'color': AppColors.primaryLight},
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
                        'Phân loại & Thẻ Tags',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hệ thống phân cấp từ khóa và nhãn giúp tìm kiếm tài liệu nhanh chóng.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: const Text('Tạo thẻ mới'),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.paddingLarge),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thẻ đang phổ biến (Tag Cloud)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: sampleTags.map((tag) {
                        final color = tag['color'] as Color;
                        return ActionChip(
                          avatar: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.2),
                            child: Icon(Icons.tag, size: 14, color: color),
                          ),
                          label: Text('${tag['name']} (${tag['count']})'),
                          onPressed: () {},
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
