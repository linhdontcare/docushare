import 'package:flutter/material.dart';
import 'core/config/firebase_config.dart';
import 'core/config/supabase_config.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'shared/services/firebase_notification_service.dart';
import 'shared/widgets/responsive_navigation_scaffold.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase chính thức kết nối dự án thực tế
  try {
    await FirebaseConfig.initialize();
  } catch (e) {
    debugPrint('⚠️ [Firebase] Lỗi khởi tạo Firebase Core: $e');
  }

  // Khởi tạo Supabase (Database + Storage cho module Documents/Tagging)
  await SupabaseConfig.initialize();

  // Hiển thị ngay giao diện ứng dụng DocuShare
  runApp(const DocuShareApp());

  // Khởi tạo dịch vụ thông báo đẩy FCM (chạy nền, không chặn giao diện)
  FirebaseNotificationService.instance.initialize().catchError((e) {
    debugPrint('⚠️ [FCM] Lỗi khởi tạo FCM: $e');
  });
}

/// Ứng dụng DocuShare - Hệ thống Quản lý Tài liệu Đa nền tảng
class DocuShareApp extends StatefulWidget {
  const DocuShareApp({super.key});

  @override
  State<DocuShareApp> createState() => _DocuShareAppState();
}

class _DocuShareAppState extends State<DocuShareApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _handleThemeToggle(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: ResponsiveNavigationScaffold(
        currentThemeMode: _themeMode,
        onThemeToggle: _handleThemeToggle,
      ),
    );
  }
}
