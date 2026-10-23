// ==============================================================================
// PRESENTATION LAYER: Login Screen (Responsive Mobile & Web)
// - Giao diện Deep Tech Emerald cao cấp với hiệu ứng phát sáng (Emerald Glow)
// - Mobile (< 600px): Thẻ đăng nhập căn giữa gọn gàng
// - Tablet & Desktop Web (>= 600px): Layout 2 cột sang trọng với tính năng nổi bật
// - Giữ nguyên 100% logic xác thực Firebase Google Sign-In & Supabase Token Sync
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/firebase/firebase_service.dart';
import '../../core/responsive/app_breakpoints.dart';
import '../../core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initializationError, this.onRetry});

  final String? initializationError;
  final Future<void> Function()? onRetry;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSigningIn = false;
  String? _errorMessage;

  Future<void> _signIn() async {
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });

    try {
      await FirebaseService.instance.signInWithGoogle();
    } on GoogleSignInException catch (error) {
      if (!mounted) return;
      final description = error.description ?? '';
      final message = error.code == GoogleSignInExceptionCode.canceled
          ? 'Đã hủy đăng nhập Google.'
          : description.contains('No credential available')
          ? 'Credential Manager không tìm thấy credential Google phù hợp. '
                'Hãy kiểm tra Google provider, OAuth Web client ID, SHA-1/SHA-256 '
                'của com.example.eduvault trong Firebase Console và cập nhật Google Play Services.'
          : error.code == GoogleSignInExceptionCode.clientConfigurationError
          ? 'Cấu hình OAuth chưa đầy đủ. '
                'Kiểm tra serverClientId là Web OAuth client ID của Firebase project.'
          : error.code == GoogleSignInExceptionCode.providerConfigurationError
          ? 'Google Sign-In provider chưa được cấu hình đúng.'
          : 'Google Sign-In thất bại (${error.code}): '
                '${description.isEmpty ? 'Không có thông tin chi tiết.' : description}';
      setState(() => _errorMessage = message);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Firebase Authentication thất bại (${error.code}): '
            '${error.message ?? 'Không có thông tin chi tiết.'}';
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  Future<void> _retryInitialization() async {
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });
    try {
      await widget.onRetry?.call();
      if (mounted) setState(() {});
    } on Object catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initializationError =
        FirebaseService.instance.initializationError ?? widget.initializationError;
    final isDesktopOrTablet = !context.isMobile;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.responsive(mobile: 20.0, tablet: 32.0, desktop: 40.0)),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktopOrTablet ? 860 : 420,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.borderSubtle, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      blurRadius: 40,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: isDesktopOrTablet
                      ? _buildWideLayout(initializationError)
                      : _buildNarrowLayout(initializationError),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Layout 2 cột cho Tablet và Desktop Web
  Widget _buildWideLayout(String? initializationError) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cột trái: Giới thiệu ứng dụng & Công nghệ
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.scaffoldBackground,
                    AppTheme.cardBackground,
                  ],
                ),
                border: const Border(
                  right: BorderSide(color: AppTheme.borderSubtle, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: AppTheme.emeraldPillGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withValues(alpha: 0.4),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.folder_special_rounded,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Text(
                            'DocuShare',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: AppTheme.emeraldPillGradient,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'LDC EDITION',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Hệ thống quản lý tài liệu học tập thông minh & bảo mật đa nền tảng.',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: AppTheme.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Điểm nhấn công nghệ
                  Column(
                    children: [
                      _buildFeatureItem(
                        icon: Icons.cloud_done_rounded,
                        title: 'Đồng bộ đám mây',
                        subtitle: 'Firebase Storage & Drift SQLite offline',
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureItem(
                        icon: Icons.security_rounded,
                        title: 'Bảo mật Supabase RLS',
                        subtitle: 'Kiểm soát truy cập theo vai trò Owner, Editor, Viewer',
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureItem(
                        icon: Icons.devices_rounded,
                        title: 'Giao diện Responsive',
                        subtitle: 'Hoạt động mượt mà trên Mobile, Tablet & Chrome Web',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Cột phải: Form Đăng nhập Google
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: _buildLoginForm(initializationError),
            ),
          ),
        ],
      ),
    );
  }

  // Layout 1 cột cho Mobile
  Widget _buildNarrowLayout(String? initializationError) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppTheme.emeraldPillGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.folder_special_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'DocuShare',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'LDC Edition • Document Management',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          _buildLoginForm(initializationError),
        ],
      ),
    );
  }

  // Nội dung form đăng nhập
  Widget _buildLoginForm(String? initializationError) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Đăng nhập tài khoản',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sử dụng tài khoản Google để truy cập kho tài liệu cá nhân và tài liệu được chia sẻ.',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),

        // Nút Google Sign-In được thiết kế nổi bật chuẩn nhận diện
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            onPressed: _isSigningIn || initializationError != null ? null : _signIn,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSigningIn)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppTheme.primaryColor,
                    ),
                  )
                else ...[
                  // Icon Google
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.g_mobiledata_rounded,
                      size: 28,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Đăng nhập với Google',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Cảnh báo lỗi khởi tạo Firebase nếu có
        if (initializationError != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Firebase chưa sẵn sàng',
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  initializationError,
                  style: const TextStyle(color: Colors.orange, fontSize: 11.5),
                  textAlign: TextAlign.left,
                ),
                if (widget.onRetry != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _isSigningIn ? null : _retryInitialization,
                    child: const Text('Thử khởi tạo lại Firebase'),
                  ),
                ],
              ],
            ),
          ),
        ],

        // Cảnh báo lỗi đăng nhập nếu có
        if (_errorMessage != null && initializationError == null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),
        const Text(
          'EduVault tuân thủ chuẩn xác thực an toàn OAuth 2.0 & phân quyền RLS Supabase.',
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
