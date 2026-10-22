import 'package:flutter/material.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'shared/widgets/responsive_navigation_scaffold.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DocuShareApp());
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
