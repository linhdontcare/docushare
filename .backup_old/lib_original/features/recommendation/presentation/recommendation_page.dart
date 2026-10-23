import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';

/// Màn hình Hệ thống Đề xuất Tài liệu Thông minh (Recommendation Feature)
/// Phụ trách bởi: Nhóm trưởng (Team Lead)
/// Chức năng: Gợi ý tài liệu dựa trên lịch sử mượn, chuyên ngành và từ khóa tương đồng
class RecommendationPage extends StatefulWidget {
  const RecommendationPage({super.key});

  @override
  State<RecommendationPage> createState() => _RecommendationPageState();
}

class _RecommendationPageState extends State<RecommendationPage> {
  int _selectedFilterIndex = 0;

  final List<String> _filters = [
    'Tất cả đề xuất',
    'Phù hợp kỳ này',
    'Thịnh hành trong tuần',
    'Cùng chuyên ngành',
  ];

  final List<Map<String, dynamic>> _recommendations = [
    {
      'title': 'Giáo trình Thiết kế Hệ thống Hướng đối tượng',
      'author': 'PGS.TS. Trần Đình B',
      'matchRate': '98% phù hợp',
      'reason': 'Dựa trên môn học kỳ 1 năm 3 & lịch sử tìm kiếm',
      'tags': ['#OOP', '#UML', '#DesignPatterns'],
      'rating': 4.9,
      'reads': '1.2k lượt đọc',
    },
    {
      'title': 'Bộ sưu tập Đề thi Cuối kỳ Trí tuệ Nhân tạo',
      'author': 'CLB Học thuật Khoa CNTT',
      'matchRate': '94% phù hợp',
      'reason': 'Sinh viên cùng ngành mượn nhiều nhất tuần qua',
      'tags': ['#AI', '#MachineLearning', '#Python'],
      'rating': 4.8,
      'reads': '980 lượt đọc',
    },
    {
      'title': 'Cẩm nang Xây dựng Ứng dụng Di động với Flutter & Clean Architecture',
      'author': 'Senior Flutter Dev Community',
      'matchRate': '91% phù hợp',
      'reason': 'Tài liệu liên quan đến đồ án TH2',
      'tags': ['#Flutter', '#Dart', '#CleanArchitecture'],
      'rating': 5.0,
      'reads': '2.4k lượt đọc',
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
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            'Gợi ý Tài liệu Thông minh',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                            ),
                            child: const Text(
                              'Module Trưởng nhóm',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Thuật toán đề xuất cá nhân hóa dựa trên lịch sử mượn, chuyên ngành và từ khóa.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đang làm mới danh sách gợi ý cá nhân hóa...'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Làm mới'),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingLarge),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_filters.length, (index) {
                  final isSelected = _selectedFilterIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(_filters[index]),
                      onSelected: (_) {
                        setState(() {
                          _selectedFilterIndex = index;
                        });
                      },
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: AppConstants.paddingLarge),

            // Recommendation List
            ..._recommendations.map((item) {
              final tags = item['tags'] as List<String>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.paddingLarge),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                              ),
                              child: const Icon(
                                Icons.auto_awesome,
                                color: AppColors.primary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.success.withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(AppConstants.radiusSmall),
                                        ),
                                        child: Text(
                                          item['matchRate'] as String,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.success,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.star, size: 16, color: Colors.amber.shade700),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${item['rating']}',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '• ${item['reads']}',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item['title'] as String,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item['author'] as String,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item['reason'] as String,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                children: tags.map((t) {
                                  return Chip(
                                    label: Text(t),
                                    padding: EdgeInsets.zero,
                                    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                                    visualDensity: VisualDensity.compact,
                                  );
                                }).toList(),
                              ),
                            ),
                            FilledButton(
                              onPressed: () {},
                              child: const Text('Xem chi tiết'),
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
