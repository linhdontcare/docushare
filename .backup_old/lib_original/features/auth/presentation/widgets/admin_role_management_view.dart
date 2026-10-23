import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/auth_service.dart';
import '../../domain/models/user_model.dart';
import '../../domain/models/user_role.dart';
import 'role_badge.dart';

/// Giao diện Quản trị Phân quyền & Người dùng dành riêng cho tài khoản Quản trị viên (Admin)
class AdminRoleManagementView extends StatefulWidget {
  const AdminRoleManagementView({super.key});

  @override
  State<AdminRoleManagementView> createState() => _AdminRoleManagementViewState();
}

class _AdminRoleManagementViewState extends State<AdminRoleManagementView> {
  final TextEditingController _searchController = TextEditingController();
  UserRole? _filterRole;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAssignRoleDialog(UserModel targetUser) {
    UserRole selectedRole = targetUser.role;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);

          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.manage_accounts, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Phân quyền tài khoản',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thông tin người dùng
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: targetUser.role.color.withValues(alpha: 0.2),
                            child: Text(
                              targetUser.initials,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: targetUser.role.color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  targetUser.fullName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  targetUser.email,
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          RoleBadge(role: targetUser.role),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Chọn vai trò mới cần gán:',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // Danh sách 4 vai trò
                    ...UserRole.values.map((role) {
                      final isCurrent = targetUser.role == role;
                      final isChosen = selectedRole == role;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => setDialogState(() => selectedRole = role),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isChosen ? role.color.withValues(alpha: 0.12) : null,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isChosen ? role.color : theme.colorScheme.outlineVariant,
                                width: isChosen ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(role.icon, color: role.color, size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            role.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isChosen ? role.color : null,
                                            ),
                                          ),
                                          if (isCurrent) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.surfaceContainerHighest,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'Hiện tại',
                                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        role.description,
                                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  isChosen ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                  color: isChosen ? role.color : theme.colorScheme.outlineVariant,
                                  size: 20,
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
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Xác nhận phân quyền'),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  try {
                    await AuthService.instance.changeUserRoleByAdmin(
                      targetUserId: targetUser.id,
                      newRole: selectedRole,
                    );
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.success,
                        content: Text(
                          'Đã phân quyền thành công: ${targetUser.fullName} -> ${selectedRole.name}',
                        ),
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.error,
                        content: Text('Lỗi phân quyền: $e'),
                      ),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showToggleActiveDialog(UserModel targetUser) {
    final willActive = !targetUser.isActive;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              willActive ? Icons.lock_open : Icons.lock,
              color: willActive ? AppColors.success : AppColors.error,
            ),
            const SizedBox(width: 8),
            Text(willActive ? 'Mở khóa tài khoản?' : 'Khóa tài khoản?'),
          ],
        ),
        content: Text(
          willActive
              ? 'Mở khóa để tài khoản ${targetUser.fullName} có thể tiếp tục đăng nhập và sử dụng hệ thống?'
              : 'Tài khoản ${targetUser.fullName} sẽ bị chặn đăng nhập vào hệ thống. Bạn có chắc chắn muốn khóa?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: willActive ? AppColors.success : AppColors.error,
            ),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              try {
                await AuthService.instance.toggleUserStatusByAdmin(
                  targetUserId: targetUser.id,
                  isActive: willActive,
                );
                messenger.showSnackBar(
                  SnackBar(
                    backgroundColor: willActive ? AppColors.success : AppColors.error,
                    content: Text(
                      willActive
                          ? 'Đã mở khóa tài khoản: ${targetUser.fullName}'
                          : 'Đã khóa tài khoản: ${targetUser.fullName}',
                    ),
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.error,
                    content: Text('Lỗi cập nhật trạng thái: $e'),
                  ),
                );
              }
            },
            child: Text(willActive ? 'Mở khóa' : 'Khóa tài khoản'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<List<UserModel>>(
      stream: AuthService.instance.getAllUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final users = snapshot.data ?? [];

        // Lọc người dùng
        final filteredUsers = users.where((u) {
          final matchesRole = _filterRole == null || u.role == _filterRole;
          final matchesQuery = _searchQuery.isEmpty ||
              u.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              u.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              u.code.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              u.faculty.toLowerCase().contains(_searchQuery.toLowerCase());
          return matchesRole && matchesQuery;
        }).toList();

        // Thống kê số lượng
        final adminCount = users.where((u) => u.role == UserRole.admin).length;
        final librarianCount = users.where((u) => u.role == UserRole.librarian).length;
        final lecturerCount = users.where((u) => u.role == UserRole.lecturer).length;
        final studentCount = users.where((u) => u.role == UserRole.student).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Banner Tiêu đề Quản trị Phân quyền
            Card(
              color: AppColors.error.withValues(alpha: 0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.paddingLarge),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.admin_panel_settings, color: AppColors.error, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Trung tâm Quản trị Phân quyền (RBAC Admin)',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.error,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'TOÀN QUYỀN HỆ THỐNG',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bạn có quyền gán vai trò (Thủ thư, Giảng viên, Sinh viên, Admin) và quản lý tài khoản người dùng trực tiếp trên cơ sở dữ liệu Cloud Firestore.',
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
            ),
            const SizedBox(height: 16),

            // 2. Thống kê số lượng người dùng theo từng vai trò
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildStatPill('Tổng tài khoản', users.length, Colors.blueGrey, Icons.people),
                _buildStatPill('Quản trị viên', adminCount, AppColors.error, Icons.admin_panel_settings),
                _buildStatPill('Thủ thư', librarianCount, AppColors.primary, Icons.local_library),
                _buildStatPill('Giảng viên', lecturerCount, AppColors.tertiary, Icons.school),
                _buildStatPill('Sinh viên', studentCount, AppColors.secondary, Icons.person_pin),
              ],
            ),
            const SizedBox(height: 20),

            // 3. Thanh tìm kiếm và bộ lọc vai trò
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.paddingMedium),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm người dùng theo tên, email, mã số...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: Text('Tất cả (${users.length})'),
                          selected: _filterRole == null,
                          onSelected: (_) => setState(() => _filterRole = null),
                        ),
                        ...UserRole.values.map((role) {
                          final count = users.where((u) => u.role == role).length;
                          return FilterChip(
                            avatar: Icon(role.icon, size: 16, color: role.color),
                            label: Text('${role.name} ($count)'),
                            selected: _filterRole == role,
                            onSelected: (val) => setState(() => _filterRole = val ? role : null),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 4. Danh sách người dùng
            if (filteredUsers.isEmpty)
              Card(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.search_off, size: 48, color: theme.colorScheme.outline),
                      const SizedBox(height: 12),
                      const Text(
                        'Không tìm thấy người dùng phù hợp',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Thử tìm với từ khóa khác hoặc xóa bộ lọc vai trò.',
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredUsers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final u = filteredUsers[index];
                  final isCurrentAdmin = u.id == AuthService.instance.currentUser?.id;

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                      side: BorderSide(
                        color: u.role.color.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Row(
                        children: [
                          // Avatar
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: u.role.color.withValues(alpha: 0.15),
                            child: Text(
                              u.initials,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: u.role.color,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Thông tin cá nhân
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        u.fullName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isCurrentAdmin) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.error.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Chính bạn',
                                          style: TextStyle(
                                            color: AppColors.error,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  u.email,
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Mã: ${u.code}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Text(
                                      '• ${u.faculty}',
                                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                    ),
                                    if (!u.isActive)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.error.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'ĐÃ KHÓA',
                                          style: TextStyle(
                                            color: AppColors.error,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),
                          RoleBadge(role: u.role),
                          const SizedBox(width: 8),

                          // Nút Phân quyền
                          FilledButton.tonalIcon(
                            icon: const Icon(Icons.manage_accounts, size: 16),
                            label: const Text('Phân quyền'),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onPressed: () => _showAssignRoleDialog(u),
                          ),

                          // Menu tùy chọn thêm (Khóa / Mở khóa)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20),
                            onSelected: (val) {
                              if (val == 'toggle_active') {
                                _showToggleActiveDialog(u);
                              }
                            },
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                value: 'toggle_active',
                                child: Row(
                                  children: [
                                    Icon(
                                      u.isActive ? Icons.lock_outline : Icons.lock_open,
                                      size: 18,
                                      color: u.isActive ? AppColors.error : AppColors.success,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(u.isActive ? 'Khóa tài khoản' : 'Mở khóa tài khoản'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildStatPill(String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
          Text(
            count.toString(),
            style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
