import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/auth_service.dart';
import '../../domain/models/user_role.dart';
import 'forgot_password_dialog.dart';

/// Form đăng nhập vào hệ thống DocuShare
class LoginForm extends StatefulWidget {
  final VoidCallback? onNavigateToRegister;

  const LoginForm({
    super.key,
    this.onNavigateToRegister,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'admin@docushare.edu.vn');
  final _passwordController = TextEditingController(text: 'Password123!');

  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await AuthService.instance.login(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Đăng nhập thành công!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Đăng nhập thất bại: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);

    try {
      await AuthService.instance.loginWithGoogle();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Đăng nhập Google thành công!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Đăng nhập Google thất bại: ${e.toString()}'),
          ),
        );
      }
    }
  }

  void _quickFill(String email) {
    _emailController.text = email;
    _passwordController.text = 'Password123!';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        content: Text('Đã chọn tài khoản: $email'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email tài khoản (*)',
              hintText: 'ten@docushare.edu.vn',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng nhập email';
              }
              if (!value.contains('@')) {
                return 'Email không hợp lệ';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Mật khẩu (*)',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Vui lòng nhập mật khẩu';
              }
              if (value.length < 6) {
                return 'Mật khẩu tối thiểu 6 ký tự';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (val) => setState(() => _rememberMe = val ?? true),
                  ),
                  const Text('Ghi nhớ đăng nhập', style: TextStyle(fontSize: 13)),
                ],
              ),
              TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => ForgotPasswordDialog(
                      initialEmail: _emailController.text.trim(),
                    ),
                  );
                },
                child: const Text('Quên mật khẩu?'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Đăng nhập ngay',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(height: 12),

          // Nút Đăng nhập bằng Google
          OutlinedButton(
            onPressed: (_isLoading || _isGoogleLoading) ? null : _handleGoogleSignIn,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              ),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
              ),
              backgroundColor: theme.colorScheme.surface,
            ),
            child: _isGoogleLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildGoogleLogo(),
                      const SizedBox(width: 10),
                      Text(
                        'Đăng nhập với Google',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Hoặc chọn tài khoản mẫu (Demo)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 14),

          // 4 Tài khoản Demo bấm 1 chạm điền email
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildDemoAccountChip(
                name: 'Admin',
                role: UserRole.admin,
                email: 'admin@docushare.edu.vn',
              ),
              _buildDemoAccountChip(
                name: 'Thủ thư',
                role: UserRole.librarian,
                email: 'librarian@docushare.edu.vn',
              ),
              _buildDemoAccountChip(
                name: 'Giảng viên',
                role: UserRole.lecturer,
                email: 'lecturer@docushare.edu.vn',
              ),
              _buildDemoAccountChip(
                name: 'Sinh viên',
                role: UserRole.student,
                email: 'student@docushare.edu.vn',
              ),
            ],
          ),

          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Chưa có tài khoản DocuShare?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              TextButton(
                onPressed: widget.onNavigateToRegister,
                child: const Text('Đăng ký ngay'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDemoAccountChip({
    required String name,
    required UserRole role,
    required String email,
  }) {
    final isMatching = _emailController.text == email;

    return ActionChip(
      avatar: Icon(role.icon, size: 16, color: role.color),
      label: Text(name, style: const TextStyle(fontSize: 12)),
      backgroundColor: isMatching ? role.color.withValues(alpha: 0.15) : null,
      side: BorderSide(
        color: isMatching ? role.color : Theme.of(context).colorScheme.outlineVariant,
      ),
      onPressed: () => _quickFill(email),
    );
  }

  Widget _buildGoogleLogo() {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            foreground: Paint()
              ..shader = const LinearGradient(
                colors: [
                  Color(0xFF4285F4),
                  Color(0xFFEA4335),
                  Color(0xFFFBBC05),
                  Color(0xFF34A853),
                ],
              ).createShader(const Rect.fromLTWH(0, 0, 20, 20)),
          ),
        ),
      ),
    );
  }
}
