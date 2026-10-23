import 'package:flutter_test/flutter_test.dart';
import 'package:docushare/domain/models/user_profile_model.dart';

void main() {
  group('UserProfileModel Domain Entity Tests', () {
    test('Khởi tạo và serialization toJson/fromJson chính xác', () {
      final now = DateTime.utc(2026, 10, 12, 12, 0, 0);
      final model = UserProfileModel(
        id: '99999999-9999-9999-9999-999999999999',
        firebaseUid: 'firebase_test_uid_123',
        email: 'sinhvien@eduvault.edu.vn',
        displayName: 'Nguyễn Văn A',
        photoUrl: 'https://example.com/avatar.png',
        createdAt: now,
        updatedAt: now,
      );

      final json = model.toJson();
      expect(json['id'], '99999999-9999-9999-9999-999999999999');
      expect(json['firebase_uid'], 'firebase_test_uid_123');
      expect(json['email'], 'sinhvien@eduvault.edu.vn');
      expect(json['display_name'], 'Nguyễn Văn A');
      expect(json['photo_url'], 'https://example.com/avatar.png');

      final fromJson = UserProfileModel.fromJson(json);
      expect(fromJson.id, model.id);
      expect(fromJson.firebaseUid, model.firebaseUid);
      expect(fromJson.email, model.email);
      expect(fromJson.displayName, model.displayName);
      expect(fromJson.photoUrl, model.photoUrl);
      expect(fromJson.createdAt, now);
      expect(fromJson.updatedAt, now);
    });

    test('Xử lý an toàn khi payload JSON thiếu các trường tùy chọn', () {
      final json = {
        'id': 'abc-uuid',
        'firebase_uid': 'uid_456',
        'email': 'user@example.com',
      };

      final model = UserProfileModel.fromJson(json);
      expect(model.id, 'abc-uuid');
      expect(model.firebaseUid, 'uid_456');
      expect(model.email, 'user@example.com');
      expect(model.displayName, isNull);
      expect(model.photoUrl, isNull);
      expect(model.createdAt, isNull);
      expect(model.updatedAt, isNull);
    });

    test('Kiểm tra hàm so sánh bằng và sao chép copyWith', () {
      final model1 = UserProfileModel(
        id: 'id1',
        firebaseUid: 'f1',
        email: 'test@eduvault.vn',
      );
      final model2 = UserProfileModel(
        id: 'id1',
        firebaseUid: 'f1',
        email: 'test@eduvault.vn',
      );

      expect(model1, equals(model2));

      final updated = model1.copyWith(displayName: 'Mới Cập Nhật');
      expect(updated.displayName, 'Mới Cập Nhật');
      expect(updated.email, model1.email);
    });
  });
}
