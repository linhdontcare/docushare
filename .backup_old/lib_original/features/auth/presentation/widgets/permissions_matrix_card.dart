import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/responsive.dart';
import '../../domain/models/user_permission.dart';
import '../../domain/models/user_role.dart';
import 'role_badge.dart';

/// Card ma trận phân quyền (RBAC - Role-Based Access Control)
class PermissionsMatrixCard extends StatefulWidget {
  final UserRole currentRole;
  final ValueChanged<UserRole>? onSelectRole;

  const PermissionsMatrixCard({
    super.key,
    required this.currentRole,
    this.onSelectRole,
  });

  @override
  State<PermissionsMatrixCard> createState() => _PermissionsMatrixCardState();
}

class _PermissionsMatrixCardState extends State<PermissionsMatrixCard> {
  int _viewMode = 0; // 0: So sánh tất cả vai trò, 1: Chi tiết vai trò hiện tại

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = Responsive.isDesktop(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.security, color: AppColors.secondary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ma trận Phân quyền Hệ thống (RBAC)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Quy định chi tiết các quyền hạn tương ứng theo từng vai trò tài khoản',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Mode Selector
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('Ma trận đối chiếu (Tất cả)'),
                  icon: Icon(Icons.table_chart_outlined, size: 18),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Quyền của bạn'),
                  icon: Icon(Icons.verified_user_outlined, size: 18),
                ),
              ],
              selected: {_viewMode},
              onSelectionChanged: (newVal) {
                setState(() => _viewMode = newVal.first);
              },
            ),
            const SizedBox(height: 16),

            if (_viewMode == 0)
              if (isDesktop)
                _buildDesktopMatrixTable(theme)
              else
                _buildMobileMatrixList(theme)
            else
              _buildCurrentRoleDetailedView(theme),
          ],
        ),
      ),
    );
  }

  /// Bảng đối chiếu hoàn chỉnh dạng Grid/Table trên Web/Desktop
  Widget _buildDesktopMatrixTable(ThemeData theme) {
    final roles = UserRole.values;
    final permissions = UserPermission.values;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          theme.colorScheme.surfaceContainerLow,
        ),
        columnSpacing: 24,
        columns: [
          const DataColumn(
            label: Text(
              'Danh mục quyền hạn',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ...roles.map((role) {
            final isCurrent = role == widget.currentRole;
            return DataColumn(
              label: Row(
                children: [
                  RoleBadge(role: role, showIcon: true),
                  if (isCurrent) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.check_circle, size: 14, color: AppColors.primary),
                  ],
                ],
              ),
            );
          }),
        ],
        rows: permissions.map((perm) {
          return DataRow(
            cells: [
              DataCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      perm.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      perm.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              ...roles.map((role) {
                final hasPerm = role.hasPermission(perm);
                final isCurrent = role == widget.currentRole;

                return DataCell(
                  Container(
                    alignment: Alignment.center,
                    decoration: isCurrent
                        ? BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(4),
                          )
                        : null,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: hasPerm
                        ? Icon(Icons.check_circle, color: role.color, size: 20)
                        : Icon(
                            Icons.remove_circle_outline,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                            size: 18,
                          ),
                  ),
                );
              }),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// Danh sách dạng danh mục trực quan cho thiết bị di động
  Widget _buildMobileMatrixList(ThemeData theme) {
    final permissions = UserPermission.values;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: permissions.length,
      separatorBuilder: (context, index) => const Divider(height: 16),
      itemBuilder: (context, index) {
        final perm = permissions[index];
        final currentUserHas = widget.currentRole.hasPermission(perm);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  currentUserHas ? Icons.check_circle : Icons.remove_circle_outline,
                  color: currentUserHas ? AppColors.success : theme.colorScheme.onSurfaceVariant,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    perm.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: currentUserHas ? null : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 26.0, top: 2, bottom: 6),
              child: Text(
                perm.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 26.0),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: UserRole.values.map((role) {
                  final allowed = role.hasPermission(perm);
                  if (!allowed) return const SizedBox.shrink();

                  return RoleBadge(role: role, showIcon: false);
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Xem chi tiết các quyền mà vai trò hiện tại đang được cấp
  Widget _buildCurrentRoleDetailedView(ThemeData theme) {
    final granted = widget.currentRole.permissions;
    final allPerms = UserPermission.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.currentRole.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
            border: Border.all(
              color: widget.currentRole.color.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(widget.currentRole.icon, color: widget.currentRole.color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tài khoản của bạn đang giữ vai trò "${widget.currentRole.name}". Có ${granted.length}/${allPerms.length} quyền hạn được kích hoạt.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: allPerms.map((perm) {
            final hasPerm = granted.contains(perm);

            return Container(
              width: 320,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasPerm
                    ? theme.colorScheme.surface
                    : theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                border: Border.all(
                  color: hasPerm
                      ? AppColors.success.withValues(alpha: 0.3)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    hasPerm ? Icons.verified : Icons.do_not_disturb_on_outlined,
                    color: hasPerm ? AppColors.success : theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          perm.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: hasPerm ? null : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          perm.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
