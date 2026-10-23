// ==============================================================================
// PRESENTATION LAYER: Adaptive Navigation Shell
// Điều hướng tự thích nghi theo 3 kích thước:
// - Mobile (< 600px): BottomNavigationBar hoặc thanh tab nhỏ gọn
// - Tablet (600 - 1024px): NavigationRail biểu tượng tinh gọn
// - Desktop Web (>= 1024px): Sidebar mở rộng với đầy đủ thông tin, avatar và thao tác
// ==============================================================================

import 'package:flutter/material.dart';

import '../../core/responsive/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';

class AdaptiveNavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badgeCount;

  const AdaptiveNavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badgeCount = 0,
  });
}

class AdaptiveNavigationShell extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AdaptiveNavigationItem> destinations;
  final Widget body;
  final VoidCallback? onAddDocument;
  final VoidCallback? onSignOut;
  final VoidCallback? onShowAbout;
  final VoidCallback? onCheckSupabase;
  final String? userName;
  final String? userEmail;
  final String? userPhotoUrl;
  final bool isSupabaseConnected;

  const AdaptiveNavigationShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
    this.onAddDocument,
    this.onSignOut,
    this.onShowAbout,
    this.onCheckSupabase,
    this.userName,
    this.userEmail,
    this.userPhotoUrl,
    this.isSupabaseConnected = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenType = context.screenType;

    switch (screenType) {
      case ScreenType.desktop:
        return _buildDesktopLayout(context);
      case ScreenType.tablet:
        return _buildTabletLayout(context);
      case ScreenType.mobile:
        return _buildMobileLayout(context);
    }
  }

  // ============================================================================
  // DESKTOP WEB LAYOUT: Full Expanded Sidebar (>= 1024px)
  // ============================================================================
  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: Row(
        children: [
          // Sidebar cố định với phong cách Deep Tech Emerald — LDC Edition
          Container(
            width: 275,
            decoration: const BoxDecoration(
              color: AppTheme.cardBackground,
              border: Border(
                right: BorderSide(color: AppTheme.borderSubtle, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Brand Logo Header & LDC Edition Branding
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              gradient: AppTheme.emeraldPillGradient,
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.folder_special_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 2,
                                  children: [
                                    const Text(
                                      'DocuShare',
                                      style: TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textPrimary,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5.5,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF059669),
                                            Color(0xFF10B981),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF10B981)
                                                .withValues(alpha: 0.3),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: const Text(
                                        'LDC EDITION',
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 1),
                                const Text(
                                  'Smart Document Workspace',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // 2. Slogan Box tinh tế
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.scaffoldBackground.withValues(
                            alpha: 0.6,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.primaryColor.withValues(
                              alpha: 0.16,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your knowledge, organized.',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 1.5),
                            Text(
                              'Manage · Discover · Share',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: AppTheme.textSecondary.withValues(
                                  alpha: 0.8,
                                ),
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Nút tạo tài liệu nổi bật
                if (onAddDocument != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        onPressed: onAddDocument,
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text(
                          'Thêm tài liệu mới',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  child: Text(
                    'KHÔNG GIAN LÀM VIỆC',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),

                // 3. Navigation items
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    itemCount: destinations.length,
                    itemBuilder: (context, index) {
                      final item = destinations[index];
                      final isSelected = selectedIndex == index;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            hoverColor: AppTheme.primaryColor.withValues(
                              alpha: 0.08,
                            ),
                            onTap: () => onDestinationSelected(index),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10.5,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primaryColor.withValues(
                                        alpha: 0.15,
                                      )
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primaryColor.withValues(
                                          alpha: 0.4,
                                        )
                                      : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (isSelected)
                                    Container(
                                      width: 3.5,
                                      height: 16,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor,
                                        borderRadius: BorderRadius.circular(2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.primaryColor
                                                .withValues(alpha: 0.6),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  Icon(
                                    isSelected ? item.selectedIcon : item.icon,
                                    size: 19,
                                    color: isSelected
                                        ? AppTheme.primaryColor
                                        : AppTheme.textSecondary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item.label,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                            : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                  if (item.badgeCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7.5,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : AppTheme.borderSubtle,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${item.badgeCount}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Colors.white
                                              : AppTheme.textSecondary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 4. Status card (Supabase RLS)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.scaffoldBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSupabaseConnected
                                ? AppTheme.primaryColor
                                : Colors.orange,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (isSupabaseConnected
                                            ? AppTheme.primaryColor
                                            : Colors.orange)
                                        .withValues(alpha: 0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isSupabaseConnected
                                ? 'Supabase RLS: Đang kết nối'
                                : 'Chế độ Offline cục bộ',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (onCheckSupabase != null)
                          IconButton(
                            icon: const Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                            ),
                            color: AppTheme.primaryColor,
                            tooltip: 'Kiểm tra trạng thái bảo mật',
                            onPressed: onCheckSupabase,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  ),
                ),

                const Divider(color: AppTheme.borderSubtle, height: 1),

                // 5. User profile & Actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: AppTheme.primaryColor.withValues(
                          alpha: 0.2,
                        ),
                        backgroundImage: userPhotoUrl != null
                            ? NetworkImage(userPhotoUrl!)
                            : null,
                        child: userPhotoUrl == null
                            ? const Icon(
                                Icons.person_rounded,
                                size: 19,
                                color: AppTheme.primaryColor,
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName ?? 'Người dùng',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              userEmail ?? 'EduVault User',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (onShowAbout != null)
                        IconButton(
                          icon: const Icon(
                            Icons.help_outline_rounded,
                            size: 18,
                          ),
                          color: AppTheme.textSecondary,
                          tooltip: 'Thông tin ứng dụng',
                          onPressed: onShowAbout,
                        ),
                      if (onSignOut != null)
                        IconButton(
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          color: Colors.redAccent,
                          tooltip: 'Đăng xuất',
                          onPressed: onSignOut,
                        ),
                    ],
                  ),
                ),

                // 6. Footer: LDC EDITION & Built with Flutter
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'LDC EDITION · v1.0',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Built with Flutter',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: AppTheme.textSecondary.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Vùng nội dung chính của màn hình
          Expanded(child: body),
        ],
      ),
    );
  }

  // ============================================================================
  // TABLET LAYOUT: NavigationRail (600px - 1024px)
  // ============================================================================
  Widget _buildTabletLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: AppTheme.cardBackground,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            labelType: NavigationRailLabelType.selected,
            leading: Column(
              children: [
                const SizedBox(height: 12),
                Tooltip(
                  message: 'DocuShare',
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppTheme.emeraldPillGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.folder_special_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                if (onAddDocument != null) ...[
                  const SizedBox(height: 16),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_rounded),
                    tooltip: 'Thêm tài liệu',
                    onPressed: onAddDocument,
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onCheckSupabase != null)
                        IconButton(
                          icon: const Icon(Icons.shield_outlined),
                          color: isSupabaseConnected
                              ? AppTheme.primaryColor
                              : Colors.orange,
                          tooltip: 'Trạng thái Supabase RLS',
                          onPressed: onCheckSupabase,
                        ),
                      if (onShowAbout != null)
                        IconButton(
                          icon: const Icon(Icons.info_outline_rounded),
                          color: AppTheme.textSecondary,
                          tooltip: 'Giới thiệu',
                          onPressed: onShowAbout,
                        ),
                      if (onSignOut != null)
                        IconButton(
                          icon: const Icon(Icons.logout_rounded),
                          color: Colors.redAccent,
                          tooltip: 'Đăng xuất',
                          onPressed: onSignOut,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            destinations: destinations.map((d) {
              return NavigationRailDestination(
                icon: Badge(
                  isLabelVisible: d.badgeCount > 0,
                  label: Text('${d.badgeCount}'),
                  backgroundColor: AppTheme.primaryColor,
                  child: Icon(d.icon, color: AppTheme.textSecondary),
                ),
                selectedIcon: Badge(
                  isLabelVisible: d.badgeCount > 0,
                  label: Text('${d.badgeCount}'),
                  backgroundColor: AppTheme.primaryColor,
                  child: Icon(d.selectedIcon, color: AppTheme.primaryColor),
                ),
                label: Text(
                  d.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              );
            }).toList(),
          ),
          const VerticalDivider(
            width: 1,
            thickness: 1,
            color: AppTheme.borderSubtle,
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  // ============================================================================
  // MOBILE LAYOUT: BottomNavigationBar (< 600px)
  // ============================================================================
  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: body,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.cardBackground,
          border: Border(
            top: BorderSide(color: AppTheme.borderSubtle, width: 1),
          ),
        ),
        child: NavigationBar(
          backgroundColor: AppTheme.cardBackground,
          indicatorColor: AppTheme.primaryColor.withValues(alpha: 0.18),
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: destinations.map((d) {
            return NavigationDestination(
              icon: Badge(
                isLabelVisible: d.badgeCount > 0,
                label: Text('${d.badgeCount}'),
                backgroundColor: AppTheme.primaryColor,
                child: Icon(d.icon, color: AppTheme.textSecondary),
              ),
              selectedIcon: Badge(
                isLabelVisible: d.badgeCount > 0,
                label: Text('${d.badgeCount}'),
                backgroundColor: AppTheme.primaryColor,
                child: Icon(d.selectedIcon, color: AppTheme.primaryColor),
              ),
              label: d.label,
            );
          }).toList(),
        ),
      ),
    );
  }
}
