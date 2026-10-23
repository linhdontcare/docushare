import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/app_stat_card.dart';
import '../../../shared/widgets/section_header.dart';

/// Màn hình Dashboard tổng quan của DocuShare
/// Hỗ trợ responsive layout tối ưu cho cả Android (Mobile) và Web (Desktop)
class DashboardPage extends StatelessWidget {
  final ValueChanged<int>? onNavigateToTab;

  const DashboardPage({
    super.key,
    this.onNavigateToTab,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(
          isMobile ? AppConstants.paddingMedium : AppConstants.paddingLarge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Welcome Banner
            _buildWelcomeBanner(context, isDesktop),
            const SizedBox(height: AppConstants.paddingLarge),

            // Stat Cards Grid (Responsive)
            _buildStatCards(context, isDesktop, isMobile),
            const SizedBox(height: AppConstants.paddingLarge),

            // Quick Actions Bar
            _buildQuickActions(context),
            const SizedBox(height: AppConstants.paddingLarge),

            // Main Content Area: Responsive Multi-column for Web, Single-column for Mobile
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 6,
                    child: _buildRecentDocumentsSection(context),
                  ),
                  const SizedBox(width: AppConstants.paddingLarge),
                  Expanded(
                    flex: 4,
                    child: _buildRecommendationPreviewSection(context),
                  ),
                ],
              )
            else ...[
              _buildRecentDocumentsSection(context),
              const SizedBox(height: AppConstants.paddingLarge),
              _buildRecommendationPreviewSection(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(BuildContext context, bool isDesktop) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        isDesktop ? AppConstants.paddingLarge : AppConstants.paddingMedium,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primaryLight.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars, color: Colors.amber, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      AppStrings.projectScope,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
                ),
                child: Text(
                  isDesktop ? 'Nền tảng: Web / Desktop' : 'Nền tảng: Android / Mobile',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.welcomeTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.welcomeSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards(BuildContext context, bool isDesktop, bool isMobile) {
    final stats = [
      const AppStatCard(
        title: AppStrings.statTotalDocs,
        value: '142',
        icon: Icons.folder_open,
        color: AppColors.primaryLight,
        subtitle: '+12 tài liệu trong tuần',
      ),
      const AppStatCard(
        title: AppStrings.statBorrowing,
        value: '18',
        icon: Icons.assignment_outlined,
        color: AppColors.warning,
        subtitle: '3 tài liệu sắp đến hạn',
      ),
      const AppStatCard(
        title: AppStrings.statShared,
        value: '45',
        icon: Icons.share_outlined,
        color: AppColors.secondary,
        subtitle: '6 nhóm học phần',
      ),
      const AppStatCard(
        title: AppStrings.statRecommendations,
        value: '9',
        icon: Icons.auto_awesome,
        color: AppColors.tertiary,
        subtitle: 'Độ khớp 95%',
      ),
    ];

    if (isDesktop) {
      return Row(
        children: stats
            .map((stat) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: stat,
                  ),
                ))
            .toList(),
      );
    } else {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.35,
        ),
        itemCount: stats.length,
        itemBuilder: (context, index) => stats[index],
      );
    }
  }

  Widget _buildQuickActions(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: AppStrings.quickActions,
              subtitle: 'Lối tắt nhanh cho các tác vụ thường dùng',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.upload_file, size: 18, color: AppColors.primary),
                  label: const Text('Tải lên tài liệu'),
                  onPressed: () => onNavigateToTab?.call(1),
                ),
                ActionChip(
                  avatar: const Icon(Icons.qr_code_scanner, size: 18, color: AppColors.secondary),
                  label: const Text('Quét vị trí kệ sách'),
                  onPressed: () => onNavigateToTab?.call(3),
                ),
                ActionChip(
                  avatar: const Icon(Icons.assignment_add, size: 18, color: AppColors.warning),
                  label: const Text('Tạo phiếu mượn'),
                  onPressed: () => onNavigateToTab?.call(4),
                ),
                ActionChip(
                  avatar: const Icon(Icons.auto_awesome, size: 18, color: AppColors.tertiary),
                  label: const Text('Xem đề xuất AI'),
                  onPressed: () => onNavigateToTab?.call(6),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentDocumentsSection(BuildContext context) {
    final theme = Theme.of(context);

    final recentDocs = [
      {
        'title': 'Giáo trình Cấu trúc Dữ liệu & Giải thuật',
        'type': 'PDF • CNTT',
        'time': 'Vừa cập nhật 10 phút trước',
        'status': 'Sẵn sàng',
        'statusColor': AppColors.success,
      },
      {
        'title': 'Đề thi Mạng máy tính K64 - Học kỳ 2',
        'type': 'PDF • Đề thi',
        'time': '2 giờ trước',
        'status': 'Đang mượn',
        'statusColor': AppColors.warning,
      },
      {
        'title': 'Slide Kiến trúc Phần mềm và Microservices',
        'type': 'PPTX • Chuyên ngành',
        'time': 'Hôm qua',
        'status': 'Sẵn sàng',
        'statusColor': AppColors.success,
      },
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: AppStrings.recentDocuments,
              subtitle: 'Các tài liệu mới được thêm và cập nhật gần đây',
              actionText: 'Xem tất cả',
              onActionTap: () => onNavigateToTab?.call(1),
            ),
            const SizedBox(height: 16),
            ...recentDocs.map((doc) {
              final statusColor = doc['statusColor'] as Color;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                      ),
                      child: const Icon(Icons.description_outlined, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc['title'] as String,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${doc['type']} • ${doc['time']}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                      ),
                      child: Text(
                        doc['status'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationPreviewSection(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: AppStrings.recommendedForYou,
              subtitle: 'Do nhóm trưởng phụ trách thuật toán',
              actionText: 'Khám phá',
              onActionTap: () => onNavigateToTab?.call(6),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Độ phù hợp: 98%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Giáo trình Thiết kế Hệ thống Hướng đối tượng',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Được đề xuất vì bạn đang quan tâm đến môn Kiến trúc Phần mềm.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                border: Border.all(color: AppColors.secondary.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.trending_up, color: AppColors.secondary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Xu hướng sinh viên mượn nhiều',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Đề thi & Lời giải Trí tuệ Nhân tạo 2024',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hơn 85 sinh viên khoa CNTT đã xem tài liệu này tuần qua.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
