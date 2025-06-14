import 'package:flutter_test/flutter_test.dart';
import 'package:seeyou/features/auth/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([AuthService])
import 'auth_test.mocks.dart';

void main() {
  late AuthService authService;
  late MockAuthService mockAuthService;

  setUp(() {
    mockAuthService = MockAuthService();
    authService = mockAuthService;
  });

  group('AuthService Tests', () {
    test('login com credenciais válidas deve retornar usuário', () async {
      // Arrange
      const email = 'test@example.com';
      const password = 'password123';
      final mockUser = User(
        id: '123',
        email: email,
        appMetadata: const {},
        userMetadata: const {},
        aud: '',
        createdAt: DateTime.now().toIso8601String(),
      );

      when(mockAuthService.login(email, password))
          .thenAnswer((_) async => mockUser);

      // Act
      final result = await authService.login(email, password);

      // Assert
      expect(result, isNotNull);
      expect(result?.email, equals(email));
    });

    test('login com credenciais inválidas deve lançar exceção', () async {
      // Arrange
      const email = 'test@example.com';
      const password = 'wrongpassword';

      when(mockAuthService.login(email, password))
          .thenThrow(AuthException('Invalid login credentials'));

      // Act & Assert
      expect(
        () => authService.login(email, password),
        throwsA(isA<AuthException>()),
      );
    });

    test('registro com email válido deve criar usuário', () async {
      // Arrange
      const email = 'new@example.com';
      const password = 'password123';
      final mockUser = User(
        id: '123',
        email: email,
        appMetadata: const {},
        userMetadata: const {},
        aud: '',
        createdAt: DateTime.now().toIso8601String(),
      );

      when(mockAuthService.register(email, password))
          .thenAnswer((_) async => mockUser);

      // Act
      final result = await authService.register(email, password);

      // Assert
      expect(result, isNotNull);
      expect(result?.email, equals(email));
    });

    test('registro com email inválido deve lançar exceção', () async {
      // Arrange
      const email = 'invalid-email';
      const password = 'password123';

      when(mockAuthService.register(email, password))
          .thenThrow(AuthException('Invalid email'));

      // Act & Assert
      expect(
        () => authService.register(email, password),
        throwsA(isA<AuthException>()),
      );
    });

    test('logout deve ser executado com sucesso', () async {
      // Arrange
      when(mockAuthService.logout()).thenAnswer((_) => Future<void>.value());

      // Act & Assert
      await expectLater(authService.logout(), completes);
    });

    test('getCurrentUser deve retornar usuário atual', () async {
      // Arrange
      final mockUser = User(
        id: '123',
        email: 'test@example.com',
        appMetadata: const {},
        userMetadata: const {},
        aud: '',
        createdAt: DateTime.now().toIso8601String(),
      );

      when(mockAuthService.getCurrentUser())
          .thenAnswer((_) async => mockUser);

      // Act
      final result = await authService.getCurrentUser();

      // Assert
      expect(result, isNotNull);
      expect(result?.id, equals('123'));
    });

    test('resetPassword deve ser executado com sucesso', () async {
      // Arrange
      const email = 'test@example.com';
      when(mockAuthService.resetPassword(any))
          .thenAnswer((_) => Future<void>.value());

      // Act & Assert
      await expectLater(authService.resetPassword(email), completes);
    });

    test('updatePassword deve ser executado com sucesso', () async {
      // Arrange
      const newPassword = 'newpassword123';
      when(mockAuthService.updatePassword(any))
          .thenAnswer((_) => Future<void>.value());

      // Act & Assert
      await expectLater(authService.updatePassword(newPassword), completes);
    });
  });
} 