import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/responsive.dart';
import '../../data/auth_service.dart';
import '../../domain/models/user_model.dart';
import '../../domain/models/user_role.dart';
import 'change_password_dialog.dart';
import 'edit_profile_dialog.dart';
import 'admin_role_management_view.dart';
import 'permissions_matrix_card.dart';
import 'quick_account_switcher.dart';
import 'role_badge.dart';

/// Giao diện Hồ sơ cá nhân và Trung tâm Quản trị Tài khoản (Profile & Account Center)
class ProfileView extends StatefulWidget {
  final UserModel user;

  const ProfileView({
    super.key,
    required this.user,
  });

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool get _isAdmin => widget.user.role == UserRole.admin;
  int get _tabLength => _isAdmin ? 4 : 3;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLength, vsync: this);
  }

  @override
  void didUpdateWidget(ProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.role != widget.user.role) {
      _tabController.dispose();
      _tabController = TabController(
        length: _tabLength,
        vsync: this,
        initialIndex: 0,
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout, color: AppColors.error),
            SizedBox(width: 8),
            Text('Đăng xuất tài khoản?'),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản ${widget.user.fullName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              AuthService.instance.logout();
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            // 1. Hero Profile Header Card
            _buildHeroHeader(theme, isDesktop),
            const SizedBox(height: AppConstants.paddingLarge),

            // 2. Chuyển đổi tài khoản demo (RBAC Switcher)
            const QuickAccountSwitcher(),
            const SizedBox(height: AppConstants.paddingLarge),

            // 3. User Stats Row
            _buildStatsRow(theme, isDesktop, isMobile),
            const SizedBox(height: AppConstants.paddingLarge),

            // 4. Tab Navigation Header
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              isScrollable: isMobile || _isAdmin,
              tabs: [
                const Tab(
                  icon: Icon(Icons.person_outline),
                  text: 'Thông tin cá nhân',
                ),
                const Tab(
                  icon: Icon(Icons.admin_panel_settings_outlined),
                  text: 'Phân quyền (RBAC)',
                ),
                if (_isAdmin)
                  const Tab(
                    icon: Icon(Icons.manage_accounts_outlined),
                    text: 'Quản trị Phân quyền',
                  ),
                const Tab(
                  icon: Icon(Icons.security_outlined),
                  text: 'Bảo mật & Nhật ký',
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingLarge),

            // 5. Tab Views Container
            AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                if (_isAdmin) {
                  switch (_tabController.index) {
                    case 0:
                      return _buildPersonalInfoTab(theme, isDesktop);
                    case 1:
                      return PermissionsMatrixCard(currentRole: widget.user.role);
                    case 2:
                      return const AdminRoleManagementView();
                    case 3:
                      return _buildSecurityAndActivityTab(theme, isDesktop);
                    default:
                      return const SizedBox.shrink();
                  }
                } else {
                  switch (_tabController.index) {
                    case 0:
                      return _buildPersonalInfoTab(theme, isDesktop);
                    case 1:
                      return PermissionsMatrixCard(currentRole: widget.user.role);
                    case 2:
                      return _buildSecurityAndActivityTab(theme, isDesktop);
                    default:
                      return const SizedBox.shrink();
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Header chứa Avatar, Thông tin chính, Badge vai trò và thao tác
  Widget _buildHeroHeader(ThemeData theme, bool isDesktop) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        side: BorderSide(
          color: widget.user.role.color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 16,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar với viết tắt chữ cái
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: widget.user.role.color.withValues(alpha: 0.15),
                      child: Text(
                        widget.user.initials,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: widget.user.role.color,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Icon(
                          widget.user.role.icon,
                          size: 14,
                          color: widget.user.role.color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.user.fullName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        RoleBadge(role: widget.user.role, isLarge: true),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.user.email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Mã: ${widget.user.code}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.verified, size: 14, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text(
                          'Đã xác thực',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_isAdmin)
                  FilledButton.icon(
                    onPressed: () => _tabController.animateTo(2),
                    icon: const Icon(Icons.manage_accounts, size: 18),
                    label: const Text('Phân quyền người dùng'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => EditProfileDialog(user: widget.user),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Chỉnh sửa'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _showLogoutConfirmDialog,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Đăng xuất'),
                  style: FilledButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Dải 4 thống kê cá nhân
  Widget _buildStatsRow(ThemeData theme, bool isDesktop, bool isMobile) {
    final stats = [
      _StatItem(
        label: 'Tài liệu tải lên',
        value: '${widget.user.uploadedCount}',
        icon: Icons.upload_file,
        color: AppColors.primary,
      ),
      _StatItem(
        label: 'Đang mượn',
        value: '${widget.user.borrowingCount}',
        icon: Icons.assignment_outlined,
        color: AppColors.warning,
      ),
      _StatItem(
        label: 'Tài liệu đã lưu',
        value: '${widget.user.savedCount}',
        icon: Icons.bookmark_outline,
        color: AppColors.secondary,
      ),
      _StatItem(
        label: 'Điểm tín nhiệm',
        value: '${widget.user.reputationScore}/100',
        icon: Icons.shield,
        color: AppColors.success,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = isMobile ? 2 : 4;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isDesktop ? 2.2 : 1.8,
          ),
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final item = stats[index];
            return Container(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, color: item.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.value,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          item.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Tab 1: Chi tiết thông tin cá nhân
  Widget _buildPersonalInfoTab(ThemeData theme, bool isDesktop) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hồ sơ sinh viên / Giảng viên',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Các thông tin định danh và liên hệ chính thức trong trường',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 20,
              children: [
                _buildInfoTile(
                  theme,
                  icon: Icons.apartment,
                  label: 'Khoa / Viện / Đơn vị',
                  value: widget.user.faculty,
                ),
                _buildInfoTile(
                  theme,
                  icon: Icons.school,
                  label: 'Chuyên ngành đào tạo',
                  value: widget.user.major ?? 'Chưa cập nhật',
                ),
                _buildInfoTile(
                  theme,
                  icon: Icons.group,
                  label: 'Khóa / Lớp học',
                  value: widget.user.cohort ?? 'Chưa cập nhật',
                ),
                _buildInfoTile(
                  theme,
                  icon: Icons.phone,
                  label: 'Số điện thoại',
                  value: widget.user.phone ?? 'Chưa cập nhật',
                ),
                _buildInfoTile(
                  theme,
                  icon: Icons.calendar_today,
                  label: 'Ngày gia nhập DocuShare',
                  value:
                      '${widget.user.joinedDate.day}/${widget.user.joinedDate.month}/${widget.user.joinedDate.year}',
                ),
                _buildInfoTile(
                  theme,
                  icon: Icons.check_circle_outline,
                  label: 'Trạng thái tài khoản',
                  value: widget.user.isActive ? 'Đang hoạt động' : 'Tạm khóa',
                  valueColor: widget.user.isActive ? AppColors.success : AppColors.error,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Tiểu sử & Giới thiệu (Bio)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
              ),
              child: Text(
                widget.user.bio ?? 'Chưa có thông tin giới thiệu bản thân.',
                style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return SizedBox(
      width: 260,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tab 3: Cài đặt bảo mật và Nhật ký hoạt động
  Widget _buildSecurityAndActivityTab(ThemeData theme, bool isDesktop) {
    final activities = AuthService.instance.activityLogs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card Cài đặt bảo mật
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cài đặt bảo mật tài khoản',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.password, color: AppColors.primary),
                  title: const Text('Mật khẩu đăng nhập'),
                  subtitle: const Text('Đã cập nhật gần đây'),
                  trailing: OutlinedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const ChangePasswordDialog(),
                      );
                    },
                    child: const Text('Đổi mật khẩu'),
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.security, color: AppColors.secondary),
                  title: const Text('Xác thực 2 yếu tố (2FA)'),
                  subtitle: const Text('Bảo vệ tài khoản bằng mã bảo mật OTP khi đăng nhập'),
                  value: widget.user.isTwoFactorEnabled,
                  onChanged: (val) {
                    AuthService.instance.toggle2FA();
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppConstants.paddingLarge),

        // Card Nhật ký hoạt động (Audit Log)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingLarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Nhật ký hoạt động bảo mật',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${activities.length} sự kiện',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Theo dõi các lần đăng nhập và thay đổi thiết lập tài khoản của bạn',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activities.length,
                  separatorBuilder: (context, index) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final item = activities[index];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLow,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(item.icon, size: 18, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                item.description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (item.device != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Thiết bị: ${item.device} • IP: ${item.ipAddress ?? "N/A"}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          item.timeFormatted,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}
