import 'package:flutter/material.dart';
import '../../domain/models/user_role.dart';

/// Huy hiệu hiển thị vai trò người dùng với màu sắc và biểu tượng trực quan
class RoleBadge extends StatelessWidget {
  final UserRole role;
  final bool showIcon;
  final bool isLarge;

  const RoleBadge({
    super.key,
    required this.role,
    this.showIcon = true,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark
        ? role.color.withValues(alpha: 0.22)
        : role.color.withValues(alpha: 0.12);
    final borderColor = role.color.withValues(alpha: 0.4);

    return Tooltip(
      message: role.description,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isLarge ? 12 : 8,
          vertical: isLarge ? 6 : 3,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(isLarge ? 10 : 6),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon) ...[
              Icon(
                role.icon,
                size: isLarge ? 18 : 14,
                color: role.color,
              ),
              SizedBox(width: isLarge ? 8 : 4),
            ],
            Text(
              role.name,
              style: TextStyle(
                color: role.color,
                fontWeight: FontWeight.bold,
                fontSize: isLarge ? 13 : 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
