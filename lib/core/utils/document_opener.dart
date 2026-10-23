// ==============================================================================
// CORE UTILITY: document_opener.dart
// Đóng gói logic mở và xem trước tệp tài liệu (Web link, Firebase Storage Cloud, hoặc local file)
// Tương thích đa nền tảng: Flutter Web, Android, iOS, Windows, macOS, Linux.
// ==============================================================================

import 'dart:io' show File, Platform;
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../firebase/firebase_service.dart';
import '../../domain/models/document_model.dart';

class DocumentOpener {
  DocumentOpener._();

  /// Mở tài liệu theo dạng Web link, tệp Cloud Storage hoặc tệp cục bộ
  static Future<void> openDocument(BuildContext context, DocumentModel doc) async {
    if (!doc.hasAttachment) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tài liệu không có tệp đính kèm hoặc liên kết.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Kiểm tra quyền truy cập tài liệu: Người dùng phải đăng nhập và là Owner, Editor, Viewer hoặc Borrower
    final currentUser = FirebaseService.instance.currentUser;
    if (currentUser == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng đăng nhập để mở tệp tài liệu.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final hasValidPermission = doc.isOwner ||
        doc.isEditor ||
        doc.isViewer ||
        doc.userPermissionRole == 'borrower';

    if (!hasValidPermission) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bạn không có quyền truy cập hoặc xem tệp tài liệu này.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final savedPath = doc.filePathOrUrl!.trim();

    // 1. Trường hợp Web URL
    if (doc.isWebLink) {
      final uri = Uri.tryParse(savedPath);
      if (uri == null || uri.host.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Liên kết tài liệu không hợp lệ.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      var launched = false;
      final isGoogleDriveLink =
          uri.host == 'drive.google.com' || uri.host.endsWith('.drive.google.com');

      if (!kIsWeb && Platform.isAndroid && isGoogleDriveLink) {
        try {
          final chromeIntent = AndroidIntent(
            action: 'action_view',
            data: uri.toString(),
            package: 'com.android.chrome',
          );
          if (await chromeIntent.canResolveActivity() == true) {
            await chromeIntent.launch();
            launched = true;
          }
        } catch (_) {}
      }

      if (!launched) {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể mở liên kết. Vui lòng kiểm tra quyền truy cập.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // 2. Trường hợp tệp trên Firebase Storage (users/...)
    if (savedPath.startsWith('users/')) {
      // 2.1. Thử mở trực tiếp từ Firebase Storage (hỗ trợ cả Owner và người được chia sẻ quyền Viewer/Editor)
      if (kIsWeb) {
        try {
          final downloadUrl = await FirebaseService.instance.getDownloadUrl(savedPath);
          final uri = Uri.parse(downloadUrl);
          await launchUrl(uri, mode: LaunchMode.platformDefault);
          return;
        } catch (directWebErr) {
          debugPrint('[DocumentOpener] Mở trực tiếp trên Web thất bại ($directWebErr), thử dự phòng proxy...');
        }
      } else {
        // Trên Mobile / Desktop
        try {
          final cloudFile = await FirebaseService.instance.downloadDocumentToTemporaryFile(
            storagePath: savedPath,
            fileName: p.basename(savedPath),
            documentId: doc.id,
          );
          final result = await OpenFilex.open(cloudFile.path);
          if (result.type == ResultType.done) {
            return;
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Không thể mở tệp: ${result.message}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        } catch (directMobileErr) {
          debugPrint('[DocumentOpener] Tải trực tiếp trên Mobile/Desktop thất bại ($directMobileErr), thử dự phòng proxy...');
        }
      }

      // 2.2. Dự phòng: Stream qua Trusted Backend Proxy (auth_claim_server.js tại cổng 5055)
      final user = FirebaseService.instance.currentUser;
      final idToken = await user?.getIdToken();
      final host = (!kIsWeb && Platform.isAndroid) ? '10.0.2.2' : 'localhost';
      final proxyUrl = 'http://$host:5055/api/documents/${doc.id}/file';

      if (kIsWeb) {
        try {
          final uri = Uri.parse('$proxyUrl?token=${idToken ?? ""}');
          await launchUrl(uri, mode: LaunchMode.platformDefault);
          return;
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Không thể mở tài liệu Cloud trên Web: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      // Trên Mobile / Desktop qua Proxy
      try {
        final response = await http.get(
          Uri.parse(proxyUrl),
          headers: {
            if (idToken != null) 'Authorization': 'Bearer $idToken',
          },
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final tempDir = await getTemporaryDirectory();
          final fileName = doc.filePathOrUrl != null ? p.basename(doc.filePathOrUrl!) : 'document_${doc.id}.pdf';
          final file = File('${tempDir.path}/shared_$fileName');
          await file.writeAsBytes(response.bodyBytes);
          final result = await OpenFilex.open(file.path);
          if (result.type != ResultType.done && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Không thể mở tệp: ${result.message}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        } else if (response.statusCode == 403) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Supabase RLS từ chối: Bạn không có quyền xem tệp này.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      } catch (proxyErr) {
        debugPrint('[DocumentOpener] Trusted proxy error: $proxyErr');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể mở tệp tài liệu Cloud. Vui lòng kiểm tra kết nối mạng hoặc phiên đăng nhập.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // 3. Trường hợp tệp cục bộ trên Mobile/Desktop
    if (!kIsWeb) {
      final file = File(savedPath);
      if (!await file.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không tìm thấy tệp trong bộ nhớ ứng dụng.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final result = await OpenFilex.open(savedPath);
      if (result.type != ResultType.done && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể mở tệp: ${result.message}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
}
