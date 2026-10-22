import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:docushare/features/auth/data/auth_service.dart';
import 'package:docushare/features/auth/domain/models/user_model.dart';
import 'package:docushare/features/auth/domain/models/user_permission.dart';
import 'package:docushare/features/auth/domain/models/user_role.dart';
import 'package:docushare/features/auth/presentation/auth_page.dart';
import 'package:docushare/features/auth/presentation/widgets/role_badge.dart';

void main() {
  group('Auth Feature - Domain Models & RBAC Permissions', () {
    test('Admin role must have all permissions', () {
      final admin = UserRole.admin;
      for (final perm in UserPermission.values) {
        expect(admin.hasPermission(perm), isTrue);
      }
    });

    test('Librarian role must have document & location management permissions', () {
      final lib = UserRole.librarian;
      expect(lib.hasPermission(UserPermission.manageAllDocuments), isTrue);
      expect(lib.hasPermission(UserPermission.manageStorageLocations), isTrue);
      expect(lib.hasPermission(UserPermission.approveBorrowRequests), isTrue);
      expect(lib.hasPermission(UserPermission.manageUsers), isFalse);
    });

    test('Student role must have borrow and read permissions, but no admin rights', () {
      final student = UserRole.student;
      expect(student.hasPermission(UserPermission.borrowPhysicalDocs), isTrue);
      expect(student.hasPermission(UserPermission.readOnlineDocs), isTrue);
      expect(student.hasPermission(UserPermission.shareDocuments), isTrue);
      expect(student.hasPermission(UserPermission.manageUsers), isFalse);
      expect(student.hasPermission(UserPermission.approveBorrowRequests), isFalse);
    });

    test('UserModel generates correct initials', () {
      final user1 = UserModel(
        id: '1',
        email: 'test@docushare.edu.vn',
        fullName: 'Dương Quốc Vượng',
        role: UserRole.admin,
        code: 'ADMIN-001',
        faculty: 'CNTT',
        joinedDate: DateTime.now(),
      );
      expect(user1.initials, 'DV');

      final user2 = UserModel(
        id: '2',
        email: 'test2@docushare.edu.vn',
        fullName: 'Linh',
        role: UserRole.student,
        code: '2102',
        faculty: 'CNTT',
        joinedDate: DateTime.now(),
      );
      expect(user2.initials, 'LI');
    });
  });

  group('Auth Feature - AuthService Operations', () {
    final authService = AuthService.instance;

    test('Initial user is set and authenticated', () {
      expect(authService.isAuthenticated, isTrue);
      expect(authService.currentUser, isNotNull);
    });

    test('Quick switch role updates current user and role', () async {
      await authService.quickLoginAs(UserRole.librarian);
      expect(authService.currentRole, UserRole.librarian);
      expect(authService.currentUser?.fullName, 'Trần Thị Mai');

      await authService.quickLoginAs(UserRole.student);
      expect(authService.currentRole, UserRole.student);
      expect(authService.currentUser?.fullName, 'Mã Khánh Linh');

      await authService.quickLoginAs(UserRole.admin);
      expect(authService.currentRole, UserRole.admin);
      expect(authService.currentUser?.fullName, 'Dương Quốc Vượng');
    });

    test('Update profile modifies user fields', () async {
      await authService.updateProfile(
        fullName: 'Dương Quốc Vượng (Updated)',
        phone: '0911223344',
      );
      expect(authService.currentUser?.fullName, 'Dương Quốc Vượng (Updated)');
      expect(authService.currentUser?.phone, '0911223344');

      // Revert back
      await authService.updateProfile(
        fullName: 'Dương Quốc Vượng',
        phone: '0988 123 456',
      );
    });

    test('Toggle 2FA updates two-factor authentication state', () {
      final current2FA = authService.currentUser!.isTwoFactorEnabled;
      authService.toggle2FA();
      expect(authService.currentUser!.isTwoFactorEnabled, !current2FA);
      authService.toggle2FA(); // Revert back
    });

    test('Logout clears current user, login restores user', () async {
      await authService.logout();
      expect(authService.isAuthenticated, isFalse);
      expect(authService.currentUser, isNull);

      await authService.login(
        email: 'vuong.admin@docushare.edu.vn',
        password: 'password123',
      );
      expect(authService.isAuthenticated, isTrue);
      expect(authService.currentUser?.role, UserRole.admin);
    });

    test('Admin can change other user role and toggle active status', () async {
      await authService.quickLoginAs(UserRole.admin);
      final success = await authService.changeUserRoleByAdmin(
        targetUserId: 'user_123',
        newRole: UserRole.lecturer,
      );
      expect(success, isTrue);

      final toggleSuccess = await authService.toggleUserStatusByAdmin(
        targetUserId: 'user_123',
        isActive: false,
      );
      expect(toggleSuccess, isTrue);
    });

    test('Non-admin cannot change other user role', () async {
      await authService.quickLoginAs(UserRole.student);
      expect(
        () => authService.changeUserRoleByAdmin(
          targetUserId: 'user_123',
          newRole: UserRole.admin,
        ),
        throwsA(isA<Exception>()),
      );
      // Restore Admin
      await authService.quickLoginAs(UserRole.admin);
    });
  });

  group('Auth Feature - Widget Presentation Tests', () {
    testWidgets('RoleBadge displays role name and icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RoleBadge(role: UserRole.admin, isLarge: true),
          ),
        ),
      );

      expect(find.text('Quản trị viên'), findsOneWidget);
      expect(find.byIcon(Icons.admin_panel_settings), findsOneWidget);
    });

    testWidgets('AuthPage renders profile view when logged in', (tester) async {
      // Ensure logged in
      await AuthService.instance.quickLoginAs(UserRole.admin);

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Should display user name and profile tabs
      expect(find.text('Dương Quốc Vượng'), findsWidgets);
      expect(find.text('Thông tin cá nhân'), findsOneWidget);
      expect(find.text('Phân quyền (RBAC)'), findsOneWidget);
      expect(find.text('Quản trị Phân quyền'), findsWidgets);
      expect(find.text('Bảo mật & Nhật ký'), findsOneWidget);
      expect(find.text('Tài liệu tải lên'), findsOneWidget);
    });

    testWidgets('AuthPage renders login form when logged out', (tester) async {
      await AuthService.instance.logout();

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Should display Login form tabs and demo account chips
      expect(find.text('Đăng nhập'), findsWidgets);
      expect(find.text('Đăng ký mới'), findsOneWidget);
      expect(find.text('Đăng nhập ngay'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Thủ thư'), findsOneWidget);

      // Restore user for other tests
      await AuthService.instance.quickLoginAs(UserRole.admin);
    });
  });
}
