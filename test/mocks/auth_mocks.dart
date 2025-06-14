import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:seeyou/features/auth/auth_service.dart';

@GenerateMocks([AuthService])
class MockAuthService extends Mock implements AuthService {
  @override
  Future<User?> login(String email, String password) async {
    return User(
      id: 'test-user-id',
      appMetadata: const {},
      userMetadata: const {},
      aud: '',
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  @override
  Future<User?> register(String email, String password) async {
    return User(
      id: 'test-user-id',
      appMetadata: const {},
      userMetadata: const {},
      aud: '',
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<User?> getCurrentUser() async {
    return User(
      id: 'test-user-id',
      appMetadata: const {},
      userMetadata: const {},
      aud: '',
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  @override
  Future<void> resetPassword(String email) async {}

  @override
  Future<void> updatePassword(String newPassword) async {}
} 