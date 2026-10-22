import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../data/auth_service.dart';
import '../../domain/models/user_role.dart';

/// Form đăng ký tài khoản sinh viên / giảng viên mới
class RegisterForm extends StatefulWidget {
  final VoidCallback? onNavigateToLogin;

  const RegisterForm({
    super.key,
    this.onNavigateToLogin,
  });

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _facultyController = TextEditingController(text: 'Khoa Công nghệ Thông tin');
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  UserRole _selectedRole = UserRole.student;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    _facultyController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đồng ý với Điều khoản sử dụng để tiếp tục.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService.instance.register(
        fullName: _fullNameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        role: _selectedRole,
        code: _codeController.text,
        faculty: _facultyController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Đăng ký tài khoản thành công!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Lỗi đăng ký: ${e.toString()}'),
          ),
        );
      }
    }
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
            controller: _fullNameController,
            decoration: const InputDecoration(
              labelText: 'Họ và tên (*)',
              hintText: 'Ví dụ: Nguyễn Văn A',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Vui lòng nhập họ và tên' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email trường / Email cá nhân (*)',
              hintText: 'sinhvien@docushare.edu.vn',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
              if (!v.contains('@')) return 'Email không hợp lệ';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Chọn Vai trò đăng ký
          DropdownButtonFormField<UserRole>(
            initialValue: _selectedRole,
            decoration: const InputDecoration(
              labelText: 'Đăng ký với vai trò (*)',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            items: [
              UserRole.student,
              UserRole.lecturer,
              UserRole.librarian,
            ].map((role) {
              return DropdownMenuItem(
                value: role,
                child: Row(
                  children: [
                    Icon(role.icon, size: 18, color: role.color),
                    const SizedBox(width: 8),
                    Text(role.name),
                  ],
                ),
              );
            }).toList(),
            onChanged: (role) {
              if (role != null) setState(() => _selectedRole = role);
            },
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: _selectedRole == UserRole.student
                        ? 'Mã Sinh viên (*)'
                        : 'Mã Giảng viên / CB (*)',
                    hintText: _selectedRole == UserRole.student ? '21020001' : 'GV-001',
                    prefixIcon: const Icon(Icons.pin_outlined),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Không được để trống mã' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _facultyController,
                  decoration: const InputDecoration(
                    labelText: 'Khoa / Đơn vị (*)',
                    prefixIcon: Icon(Icons.apartment_outlined),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Vui lòng nhập đơn vị' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

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
            validator: (v) {
              if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
              if (v.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
              return null;
            },
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: 'Xác nhận lại mật khẩu (*)',
              prefixIcon: const Icon(Icons.check_circle_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Vui lòng xác nhận mật khẩu';
              if (v != _passwordController.text) return 'Mật khẩu xác nhận không khớp';
              return null;
            },
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Checkbox(
                value: _agreedToTerms,
                onChanged: (v) => setState(() => _agreedToTerms = v ?? true),
              ),
              Expanded(
                child: Text(
                  'Tôi cam kết tuân thủ quy chế mượn trả & bảo mật dữ liệu DocuShare.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          FilledButton(
            onPressed: _isLoading ? null : _handleRegister,
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
                    'Đăng ký tài khoản',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Đã có tài khoản DocuShare?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              TextButton(
                onPressed: widget.onNavigateToLogin,
                child: const Text('Đăng nhập'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
