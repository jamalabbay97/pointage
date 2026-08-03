import 'package:chez_le_pointage/core/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserModel Unit Tests', () {
    test('Correctly parses admin user from JSON', () {
      final json = {
        'email': 'admin@pointage.com',
        'displayName': 'Admin User',
        'role': 'admin',
        'status': 'active',
        'department': 'Management',
      };

      final user = UserModel.fromJson(json, 'admin_uid_123');

      expect(user.uid, equals('admin_uid_123'));
      expect(user.email, equals('admin@pointage.com'));
      expect(user.isAdmin, isTrue);
      expect(user.isManager, isFalse);
      expect(user.isAdminOrManager, isTrue);
      expect(user.isActive, isTrue);
    });

    test('Correctly identifies employee user', () {
      final json = {
        'email': 'john@pointage.com',
        'displayName': 'John Doe',
        'role': 'employee',
        'status': 'disabled',
        'department': 'Support',
      };

      final user = UserModel.fromJson(json, 'user_uid_456');

      expect(user.isAdmin, isFalse);
      expect(user.isAdminOrManager, isFalse);
      expect(user.isActive, isFalse);
    });

    test('Normalizes Firestore role and status casing', () {
      final json = {
        'email': 'admin@pointage.com',
        'displayName': 'Admin User',
        'role': 'Admin',
        'status': ' Active ',
        'department': 'Management',
      };

      final user = UserModel.fromJson(json, 'admin_uid_123');

      expect(user.role, equals('admin'));
      expect(user.status, equals('active'));
      expect(user.isAdmin, isTrue);
      expect(user.isActive, isTrue);
    });

    test('Falls back when Firestore role and status are invalid', () {
      final json = {
        'email': 'admin@pointage.com',
        'displayName': 'Admin User',
        'role': null,
        'status': 42,
        'department': '',
      };

      final user = UserModel.fromJson(json, 'admin_uid_123');

      expect(user.role, equals('employee'));
      expect(user.status, equals('active'));
      expect(user.department, equals('General'));
    });

    test('Serializes to JSON correctly', () {
      const user = UserModel(
        uid: 'u1',
        email: 'test@example.com',
        displayName: 'Test User',
        role: 'manager',
        department: 'HR',
      );

      final json = user.toJson();

      expect(json['uid'], equals('u1'));
      expect(json['role'], equals('manager'));
      expect(json['department'], equals('HR'));
    });
  });
}
