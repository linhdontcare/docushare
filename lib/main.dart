// ==============================================================================
// APPLICATION ENTRY POINT: main.dart
// Cấu hình khởi tạo toàn cục theo chuẩn Cashew Architecture:
// - Đảm bảo WidgetsFlutterBinding được khởi chạy
// - Thiết lập Dependency Injection (DI) bằng MultiProvider phân tầng:
//   * Drift SQLite Database (Singleton)
//   * Domain Repository Implementation
//   * Presentation State Notifiers (DocumentProvider)
// - Cấu hình hệ thống Material 3 AppTheme với chế độ sáng/tối tự động
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/config/supabase_config.dart';
import 'core/firebase/firebase_service.dart';
import 'core/supabase/supabase_service.dart';
import 'data/database/drift_database.dart';
import 'data/repositories/document_repository_impl.dart';
import 'data/repositories/user_repository_impl.dart';
import 'domain/repositories/document_repository.dart';
import 'domain/repositories/user_repository.dart';
import 'presentation/providers/document_provider.dart';
import 'presentation/providers/user_provider.dart';
import 'presentation/screens/auth_gate.dart';

void main() async {
  // 1. Đảm bảo Engine Flutter được liên kết trước khi thực hiện thao tác I/O
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase cần firebase_options.dart hoặc cấu hình native do
  // flutterfire configure tạo ra. Giữ app chạy offline nếu chưa cấu hình.
  try {
    await FirebaseService.instance.initialize();
  } on StateError {
    // Firebase status is shown by the sign-in action; local mode remains usable.
  }

  // Khởi tạo Supabase SDK trực tiếp từ SupabaseConfig với callback accessToken từ Firebase
  try {
    await SupabaseService.instance.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.effectivePublishableKey,
    );
  } catch (e) {
    debugPrint('[main] Lỗi khởi tạo Supabase: $e');
  }

  // 2. Khởi tạo Cơ sở dữ liệu SQLite cục bộ (Drift ORM)
  final database = AppDatabase();

  // 3. Khởi tạo Repository hiện thực (Data Layer)
  final DocumentRepository documentRepository = DocumentRepositoryImpl(
    database,
  );
  final UserRepository userRepository = UserRepositoryImpl(
    supabaseService: SupabaseService.instance,
  );

  runApp(
    MultiProvider(
      providers: [
        // Cung cấp Database Instance trong toàn cây Widget
        Provider<AppDatabase>.value(value: database),

        // Cung cấp Repository Interfaces cho phép dễ dàng Mocking khi kiểm thử
        Provider<DocumentRepository>.value(value: documentRepository),
        Provider<UserRepository>.value(value: userRepository),

        // Cung cấp Business State Notifiers cho Tầng Giao diện UI
        ChangeNotifierProvider<DocumentProvider>(
          create: (_) => DocumentProvider(repository: documentRepository),
        ),
        ChangeNotifierProvider<UserProvider>(
          create: (_) => UserProvider(userRepo: userRepository),
        ),
      ],
      child: const DocuShareApp(),
    ),
  );
}

class DocuShareApp extends StatelessWidget {
  const DocuShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocuShare',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.deepTechEmeraldTheme,
      darkTheme: AppTheme.deepTechEmeraldTheme,
      themeMode: ThemeMode.dark,
      home: const AuthGate(),
    );
  }
}

/// Alias for backwards compatibility with tests
typedef EduVaultApp = DocuShareApp;
