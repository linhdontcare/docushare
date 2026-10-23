import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../firebase_options.dart';

/// Cấu hình khởi tạo Firebase chính thức cho DocuShare
class FirebaseConfig {
  FirebaseConfig._();

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  /// Khởi tạo Firebase kết nối trực tiếp với backend Cloud
  static Future<void> initialize() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        _isInitialized = true;
        return;
      }

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _isInitialized = true;
      debugPrint('✅ [FirebaseConfig] Firebase Core đã kết nối với dự án: ${DefaultFirebaseOptions.currentPlatform.projectId}');
    } catch (e) {
      debugPrint('❌ [FirebaseConfig] Lỗi khởi tạo Firebase: $e');
      rethrow;
    }
  }
}
