import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../data/auth_service.dart';
import 'widgets/login_form.dart';
import 'widgets/profile_view.dart';
import 'widgets/register_form.dart';

/// Màn hình Quản lý Tài khoản, Xác thực & Phân quyền (Auth Feature)
/// Phụ trách: Dương Quốc Vượng
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
  late final TabController _authTabController;

  @override
  void initState() {
    super.initState();
    _authTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _authTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        final currentUser = AuthService.instance.currentUser;

        // Nếu người dùng đã đăng nhập -> Hiển thị Trung tâm Hồ sơ & Phân quyền
        if (currentUser != null) {
          return ProfileView(user: currentUser);
        }

        // Nếu người dùng chưa đăng nhập -> Hiển thị Form Đăng nhập / Đăng ký
        return _buildUnauthenticatedView(context);
      },
    );
  }

  Widget _buildUnauthenticatedView(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.paddingLarge),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand Logo & Heading
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_person_outlined,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.appName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Xác thực tài khoản & Phân quyền truy cập',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tab bar Đăng nhập / Đăng ký
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                      ),
                      child: TabBar(
                        controller: _authTabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        indicator: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                        tabs: const [
                          Tab(text: 'Đăng nhập'),
                          Tab(text: 'Đăng ký mới'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tab contents
                    AnimatedBuilder(
                      animation: _authTabController,
                      builder: (context, _) {
                        if (_authTabController.index == 0) {
                          return LoginForm(
                            onNavigateToRegister: () => _authTabController.animateTo(1),
                          );
                        } else {
                          return RegisterForm(
                            onNavigateToLogin: () => _authTabController.animateTo(0),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
