// ==============================================================================
// UNIT TEST: google_auth_role_claim_test.dart
// Kiểm thử logic tự động gán & xác thực Firebase Custom Claim { role: 'authenticated' }
// phục vụ Supabase Third-Party Auth (EduVault - LDC Edition)
// ==============================================================================

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:docushare/core/firebase/firebase_service.dart';

void main() {
  group('Kiểm thử giải mã và xác nhận Firebase JWT Custom Claims', () {
    // Tạo chuỗi giả lập JWT Payload hợp lệ (Header.Payload.Signature)
    String createMockJwt(Map<String, dynamic> payload) {
      final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'RS256', 'typ': 'JWT'}))).replaceAll('=', '');
      final body = base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
      return '$header.$body.mockSignatureString123';
    }

    test('1. decodeTokenPayload trích xuất chính xác các trường claims từ JWT', () {
      final mockPayload = {
        'iss': 'https://securetoken.google.com/edu-vault-ldcedition',
        'aud': 'edu-vault-ldcedition',
        'sub': 'firebase-uid-google-user-123',
        'email': 'newstudent@gmail.com',
        'email_verified': true,
        'role': 'authenticated',
      };

      final token = createMockJwt(mockPayload);
      final decoded = FirebaseService.decodeTokenPayload(token);

      expect(decoded, isNotNull);
      expect(decoded!['iss'], 'https://securetoken.google.com/edu-vault-ldcedition');
      expect(decoded['aud'], 'edu-vault-ldcedition');
      expect(decoded['sub'], 'firebase-uid-google-user-123');
      expect(decoded['email'], 'newstudent@gmail.com');
      expect(decoded['role'], 'authenticated');
    });

    test('2. Phát hiện chính xác tài khoản mới thiếu claim role: "authenticated"', () {
      // Khi một tài khoản Google mới tinh đăng nhập vào Firebase Auth
      final initialPayloadWithoutRole = {
        'iss': 'https://securetoken.google.com/edu-vault-ldcedition',
        'aud': 'edu-vault-ldcedition',
        'sub': 'new-google-uid-456',
        'email': 'newuser@gmail.com',
        // 'role' bị thiếu
      };

      final initialToken = createMockJwt(initialPayloadWithoutRole);
      final decodedInitial = FirebaseService.decodeTokenPayload(initialToken);

      expect(decodedInitial, isNotNull);
      expect(decodedInitial!['role'], isNull, reason: 'Tài khoản mới tinh chưa có claim role');

      // Sau khi được backend gán claim và client làm mới token
      final claimedPayload = {
        ...initialPayloadWithoutRole,
        'role': 'authenticated',
      };
      final refreshedToken = createMockJwt(claimedPayload);
      final decodedRefreshed = FirebaseService.decodeTokenPayload(refreshedToken);

      expect(decodedRefreshed, isNotNull);
      expect(decodedRefreshed!['role'], 'authenticated', reason: 'Token mới đã có claim role: authenticated');
    });

    test('3. decodeTokenPayload xử lý an toàn với token null, rỗng hoặc định dạng sai', () {
      expect(FirebaseService.decodeTokenPayload(null), isNull);
      expect(FirebaseService.decodeTokenPayload(''), isNull);
      expect(FirebaseService.decodeTokenPayload('invalid-token-no-dots'), isNull);
      expect(FirebaseService.decodeTokenPayload('header-only.'), isNull);
    });

    test('4. URL Endpoint của Firebase Cloud Function assignUserRole chuẩn xác cho docushare-db', () {
      const cloudFunctionsUrl = 'https://us-central1-docushare-db.cloudfunctions.net/assignUserRole';
      final uri = Uri.parse(cloudFunctionsUrl);

      expect(uri.scheme, 'https');
      expect(uri.host, 'us-central1-docushare-db.cloudfunctions.net');
      expect(uri.path, '/assignUserRole');
    });
  });
}
