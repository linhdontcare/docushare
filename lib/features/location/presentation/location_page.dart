import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import 'create_location_dialog.dart';
import 'edit_location_dialog.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  String _searchQuery = '';
  final List<Map<String, String>> locations = [
    {
      'code': 'KHO-A1',
      'name': 'Phòng Đọc 1 - Tủ A (Kệ 1, 2, 3)',
      'capacity': '85/100',
      'status': 'Còn chỗ',
    },
    {
      'code': 'KHO-B2',
      'name': 'Khu Tự Học - Tủ B (Tài liệu tham khảo)',
      'capacity': '98/100',
      'status': 'Gần đầy',
    },
    {
      'code': 'KHO-C1',
      'name': 'Kho Lưu trữ Báo cáo Đồ án tốt nghiệp',
      'capacity': '40/50',
      'status': 'Còn chỗ',
    },
  ];

  Future<void> _addLocation() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const CreateLocationDialog(),
    );

    if (!mounted || result == null) return;

    final exists = locations.any((loc) => loc['code'] == result['code']);

    if (exists) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mã vị trí đã tồn tại!')));
      return;
    }

    setState(() {
      locations.insert(0, result);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thêm vị trí thành công!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _editLocation(Map<String, String> loc) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => EditLocationDialog(location: loc),
    );

    if (!mounted || result == null) return;

    // Kiểm tra mã vị trí có trùng với vị trí khác không
    final exists = locations.any(
      (item) => !identical(item, loc) && item['code'] == result['code'],
    );

    if (exists) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mã vị trí đã tồn tại!')));
      return;
    }

    setState(() {
      final index = locations.indexOf(loc);

      if (index != -1) {
        locations[index] = result;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cập nhật vị trí thành công!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filteredLocations = locations.where((loc) {
      final keyword = _searchQuery.toLowerCase().trim();

      final name = (loc['name'] ?? '').toLowerCase();
      final code = (loc['code'] ?? '').toLowerCase();

      return name.contains(keyword) || code.contains(keyword);
    }).toList();

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
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

            const SizedBox(height: 16),

            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _addLocation,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm vị trí'),
                ),

                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Chức năng quét mã QR sẽ được phát triển sau.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Quét mã vị trí'),
                ),
              ],
            ),

            const SizedBox(height: AppConstants.paddingLarge),

            TextField(
              decoration: const InputDecoration(
                hintText: 'Tìm theo tên hoặc mã vị trí...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),

            const SizedBox(height: 16),

            if (filteredLocations.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('Không tìm thấy vị trí phù hợp')),
              ),

            ...filteredLocations.map((loc) {
              final status = loc['status'] ?? '';

              final statusColor = status == 'Còn chỗ'
                  ? AppColors.success
                  : AppColors.warning;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(
                      AppConstants.paddingMedium,
                    ),

                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusMedium,
                        ),
                      ),
                      child: const Icon(
                        Icons.place_outlined,
                        color: AppColors.secondary,
                      ),
                    ),

                    title: Text(
                      loc['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),

                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Mã vị trí: ${loc['code']}'
                        ' • Sức chứa: ${loc['capacity']}',
                      ),
                    ),

                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(
                          label: Text(status),
                          backgroundColor: statusColor.withValues(alpha: 0.1),
                        ),

                        const SizedBox(width: 8),

                        IconButton(
                          tooltip: 'Sửa vị trí',
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.blue,
                          ),
                          onPressed: () => _editLocation(loc),
                        ),

                        const SizedBox(width: 4),

                        IconButton(
                          tooltip: 'Xóa vị trí',
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Xác nhận xóa'),
                                content: Text(
                                  'Bạn có chắc muốn xóa vị trí '
                                  '${loc['name']} không?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: const Text('Hủy'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    child: const Text('Xóa'),
                                  ),
                                ],
                              ),
                            );

                            if (!mounted || confirm != true) return;

                            setState(() {
                              locations.remove(loc);
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Xóa vị trí thành công!'),
                              ),
                            );
                          },
                        ),
                      ],
                    ), // Row
                  ), // ListTile
                ), // Card
              ); // Padding
            }), // locations.map
          ],
        ),
      ),
    );
  }
}
