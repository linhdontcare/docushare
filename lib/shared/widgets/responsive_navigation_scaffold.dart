import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/responsive.dart';
import '../../features/auth/data/auth_service.dart';
import '../../features/auth/domain/models/user_role.dart';
import '../../features/auth/presentation/auth_page.dart';
import '../../features/auth/presentation/widgets/role_badge.dart';
import '../../features/borrowing/presentation/borrowing_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/documents/presentation/documents_page.dart';
import '../../features/location/presentation/location_page.dart';
import '../../features/recommendation/presentation/recommendation_page.dart';
import '../../features/sharing/presentation/sharing_page.dart';
import '../../features/tagging/presentation/tagging_page.dart';
import '../models/nav_item.dart';

/// Khung điều hướng thích ứng (Adaptive Scaffold) cho cả Android và Web
class ResponsiveNavigationScaffold extends StatefulWidget {
  final ValueChanged<ThemeMode>? onThemeToggle;
  final ThemeMode currentThemeMode;

  const ResponsiveNavigationScaffold({
    super.key,
    this.onThemeToggle,
    this.currentThemeMode = ThemeMode.system,
  });

  @override
  State<ResponsiveNavigationScaffold> createState() => _ResponsiveNavigationScaffoldState();
}

class _ResponsiveNavigationScaffoldState extends State<ResponsiveNavigationScaffold> {
  int _selectedIndex = 0;

  final List<NavItem> _navItems = const [
    NavItem(
      label: AppStrings.navDashboard,
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
    ),
    NavItem(
      label: AppStrings.navDocuments,
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder,
    ),
    NavItem(
      label: AppStrings.navTagging,
      icon: Icons.tag_outlined,
      selectedIcon: Icons.tag,
    ),
    NavItem(
      label: AppStrings.navLocation,
      icon: Icons.place_outlined,
      selectedIcon: Icons.place,
    ),
    NavItem(
      label: AppStrings.navBorrowing,
      icon: Icons.assignment_outlined,
      selectedIcon: Icons.assignment,
      badge: '3',
    ),
    NavItem(
      label: AppStrings.navSharing,
      icon: Icons.share_outlined,
      selectedIcon: Icons.share,
    ),
    NavItem(
      label: AppStrings.navRecommendation,
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome,
      badge: 'Mới',
    ),
    NavItem(
      label: AppStrings.navAuth,
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
  ];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardPage(onNavigateToTab: _onDestinationSelected),
      const DocumentsPage(),
      const TaggingPage(),
      const LocationPage(),
      const BorrowingPage(),
      const SharingPage(),
      const RecommendationPage(),
      const AuthPage(),
    ];
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        final currentUser = AuthService.instance.currentUser;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.menu_book, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  AppStrings.appName,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _navItems[_selectedIndex].label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode_outlined),
                tooltip: isDark ? 'Chuyển sang chế độ sáng' : 'Chuyển sang chế độ tối',
                onPressed: () {
                  final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
                  widget.onThemeToggle?.call(newMode);
                },
              ),
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Thông báo',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Không có thông báo mới.')),
                  );
                },
              ),
              const SizedBox(width: 8),

              // User Profile Menu Popup trên AppBar
              _buildUserAppBarAction(context, currentUser, isDesktop),
            ],
          ),
          drawer: isDesktop ? null : _buildDrawer(context, currentUser),
          body: Row(
            children: [
              if (isDesktop) _buildNavigationRail(context, currentUser),
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: _pages,
                ),
              ),
            ],
          ),
          bottomNavigationBar: isDesktop ? null : _buildBottomNavigationBar(context),
        );
      },
    );
  }

  Widget _buildUserAppBarAction(BuildContext context, dynamic currentUser, bool isDesktop) {
    final theme = Theme.of(context);

    if (currentUser == null) {
      return Padding(
        padding: const EdgeInsets.only(right: 12.0),
        child: FilledButton.tonalIcon(
          onPressed: () => _onDestinationSelected(7),
          icon: const Icon(Icons.login, size: 16),
          label: const Text('Đăng nhập'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: PopupMenuButton<int>(
        tooltip: 'Tài khoản người dùng',
        offset: const Offset(0, 48),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: currentUser.role.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: currentUser.role.color.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: currentUser.role.color.withValues(alpha: 0.2),
                child: Text(
                  currentUser.initials,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: currentUser.role.color,
                  ),
                ),
              ),
              if (isDesktop) ...[
                const SizedBox(width: 8),
                Text(
                  currentUser.fullName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 6),
                RoleBadge(role: currentUser.role, showIcon: false),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ],
          ),
        ),
        itemBuilder: (ctx) => [
          PopupMenuItem(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentUser.fullName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  currentUser.email,
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                RoleBadge(role: currentUser.role, isLarge: false),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 1,
            child: Row(
              children: [
                Icon(Icons.badge_outlined, size: 18),
                SizedBox(width: 10),
                Text('Hồ sơ & Phân quyền'),
              ],
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            enabled: false,
            child: Text(
              'Đổi vai trò Demo (RBAC):',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          ...UserRole.values.map(
            (r) => PopupMenuItem(
              value: 100 + r.index,
              child: Row(
                children: [
                  Icon(r.icon, size: 16, color: r.color),
                  const SizedBox(width: 8),
                  Text(r.name),
                  if (r == currentUser.role) ...[
                    const Spacer(),
                    const Icon(Icons.check, size: 16, color: AppColors.success),
                  ],
                ],
              ),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 2,
            child: Row(
              children: [
                Icon(Icons.logout, size: 18, color: AppColors.error),
                SizedBox(width: 10),
                Text('Đăng xuất', style: TextStyle(color: AppColors.error)),
              ],
            ),
          ),
        ],
        onSelected: (val) {
          if (val == 1) {
            _onDestinationSelected(7);
          } else if (val == 2) {
            AuthService.instance.logout();
            _onDestinationSelected(7);
          } else if (val >= 100) {
            final roleIndex = val - 100;
            final selectedRole = UserRole.values[roleIndex];
            AuthService.instance.quickLoginAs(selectedRole);
          }
        },
      ),
    );
  }

  Widget _buildNavigationRail(BuildContext context, dynamic currentUser) {
    final theme = Theme.of(context);

    return NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onDestinationSelected,
      extended: MediaQuery.sizeOf(context).width > 1200,
      minExtendedWidth: 200,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'DocuShare v1.0',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: currentUser != null
                ? InkWell(
                    onTap: () => _onDestinationSelected(7),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: currentUser.role.color.withValues(alpha: 0.2),
                            child: Text(
                              currentUser.initials,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: currentUser.role.color,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          RoleBadge(role: currentUser.role, showIcon: false),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
      destinations: _navItems.map((item) {
        return NavigationRailDestination(
          icon: item.badge != null
              ? Badge(label: Text(item.badge!), child: Icon(item.icon))
              : Icon(item.icon),
          selectedIcon: item.badge != null
              ? Badge(label: Text(item.badge!), child: Icon(item.selectedIcon))
              : Icon(item.selectedIcon),
          label: Text(item.label),
        );
      }).toList(),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    final mobileTabs = [0, 1, 4, 7];
    final currentTabInMobile = mobileTabs.indexOf(_selectedIndex);

    return NavigationBar(
      selectedIndex: currentTabInMobile >= 0 ? currentTabInMobile : 0,
      onDestinationSelected: (idx) {
        _onDestinationSelected(mobileTabs[idx]);
      },
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: AppStrings.navDashboard,
        ),
        const NavigationDestination(
          icon: Icon(Icons.folder_outlined),
          selectedIcon: Icon(Icons.folder),
          label: AppStrings.navDocuments,
        ),
        NavigationDestination(
          icon: Badge(
            label: Text(_navItems[4].badge ?? ''),
            child: const Icon(Icons.assignment_outlined),
          ),
          selectedIcon: Badge(
            label: Text(_navItems[4].badge ?? ''),
            child: const Icon(Icons.assignment),
          ),
          label: AppStrings.navBorrowing,
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: AppStrings.navAuth,
        ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context, dynamic currentUser) {
    final theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header hiển thị thông tin người dùng đang đăng nhập
            if (currentUser != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: currentUser.role.color.withValues(alpha: 0.08),
                  border: Border(
                    bottom: BorderSide(
                      color: currentUser.role.color.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: currentUser.role.color.withValues(alpha: 0.2),
                      child: Text(
                        currentUser.initials,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: currentUser.role.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentUser.fullName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            currentUser.email,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          RoleBadge(role: currentUser.role),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.menu_book, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.appName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Menu các chức năng',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const Divider(height: 1),

            Expanded(
              child: ListView.builder(
                itemCount: _navItems.length,
                itemBuilder: (context, index) {
                  final item = _navItems[index];
                  final isSelected = _selectedIndex == index;

                  return ListTile(
                    leading: Icon(
                      isSelected ? item.selectedIcon : item.icon,
                      color: isSelected ? AppColors.primary : null,
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.primary : null,
                      ),
                    ),
                    trailing: item.badge != null
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              item.badge!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        : null,
                    selected: isSelected,
                    onTap: () {
                      _onDestinationSelected(index);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
