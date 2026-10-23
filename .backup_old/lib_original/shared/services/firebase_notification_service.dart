import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../features/auth/domain/models/user_role.dart';

/// Handler xử lý tin nhắn FCM chạy ngầm (Background Message Handler)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📩 [FCM Background] Nhận thông báo ngầm: ${message.messageId} - ${message.notification?.title}');
}

/// Dịch vụ quản lý thông báo đẩy Firebase Cloud Messaging (FCM)
class FirebaseNotificationService {
  static final FirebaseNotificationService instance = FirebaseNotificationService._internal();

  FirebaseNotificationService._internal();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Callback khi có thông báo nhận được ở tiền cảnh (Foreground)
  ValueChanged<RemoteMessage>? onForegroundMessage;

  /// Khởi tạo cấu hình quyền và lắng nghe thông báo FCM
  Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        debugPrint('ℹ️ [FCM] Firebase chưa được khởi tạo, bỏ qua thiết lập FCM.');
        return;
      }
      // Đăng ký Background Message Handler (Chỉ chạy trên thiết bị di động, KHÔNG chạy trên Web)
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      }

      // Yêu cầu quyền nhận thông báo từ người dùng
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('🔔 [FCM] Trạng thái cấp quyền thông báo: ${settings.authorizationStatus}');

      // Lấy FCM Device Token (trên Web cần VAPID key nên chỉ lấy khi trên mobile hoặc khi đã có key)
      if (!kIsWeb) {
        try {
          // ignore: deprecated_member_use
          _fcmToken = await _messaging.getToken();
          debugPrint('🔑 [FCM Device Token]: $_fcmToken');
        } catch (e) {
          debugPrint('⚠️ [FCM] Không thể lấy device token: $e');
        }
      }

      // Đăng ký topic chung cho toàn bộ sinh viên, giảng viên
      if (!kIsWeb) {
        await _messaging.subscribeToTopic('docushare_broadcast');
      }

      // Lắng nghe thông báo khi ứng dụng đang mở (Foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📨 [FCM Foreground] Nhận thông báo: ${message.notification?.title} - ${message.notification?.body}');
        onForegroundMessage?.call(message);
      });

      // Lắng nghe khi người dùng bấm vào thông báo từ thanh trạng thái
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('👉 [FCM Opened] Người dùng mở thông báo: ${message.notification?.title}');
      });
    } catch (e) {
      debugPrint('⚠️ [FCM] Lỗi khi khởi tạo Firebase Cloud Messaging: $e');
    }
  }

  /// Đăng ký topic nhận thông báo theo vai trò tài khoản (RBAC Topic Subscriptions)
  Future<void> syncRoleTopics({
    UserRole? oldRole,
    required UserRole newRole,
  }) async {
    if (kIsWeb) return; // Web Client không hỗ trợ subscribeToTopic qua client SDK

    try {
      if (oldRole != null && oldRole != newRole) {
        await _messaging.unsubscribeFromTopic('role_${oldRole.code.toLowerCase()}');
      }
      await _messaging.subscribeToTopic('role_${newRole.code.toLowerCase()}');
      debugPrint('✅ [FCM] Đã đăng ký nhận thông báo cho vai trò: role_${newRole.code.toLowerCase()}');
    } catch (e) {
      debugPrint('⚠️ [FCM] Không thể cập nhật topic vai trò: $e');
    }
  }
}
