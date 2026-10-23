import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/auth_service.dart';
import '../../domain/models/user_role.dart';
import 'role_badge.dart';

/// Thanh công cụ chuyển đổi nhanh tài khoản demo để kiểm thử phân quyền RBAC
class QuickAccountSwitcher extends StatelessWidget {
  final bool isCompact;

  const QuickAccountSwitcher({
    super.key,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentRole = AuthService.instance.currentRole;

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.swap_horizontal_circle_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Chuyển đổi vai trò Demo (Kiểm thử RBAC):',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: UserRole.values.map((role) {
              final isSelected = currentRole == role;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    await AuthService.instance.quickLoginAs(role);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 2),
                          content: Text('Đã chuyển sang vai trò: ${role.name}'),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? role.color.withValues(alpha: 0.15) : theme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? role.color : theme.colorScheme.outlineVariant,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RoleBadge(role: role, showIcon: true),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.check, size: 16, color: role.color),
                      ],
                    ],
                  ),
                ),
              ),
            );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
