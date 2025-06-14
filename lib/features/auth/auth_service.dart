import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<User?> login(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response.user;
    } catch (e) {
      throw AuthException('Credenciais inválidas');
    }
  }

  Future<User?> register(String email, String password) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      return response.user;
    } catch (e) {
      throw AuthException('Erro ao criar usuário: ${e.toString()}');
    }
  }

  Future<void> logout() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw AuthException('Erro ao fazer logout: ${e.toString()}');
    }
  }

  Future<User?> getCurrentUser() async {
    return _client.auth.currentUser;
  }

  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw AuthException('Erro ao resetar senha: ${e.toString()}');
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      throw AuthException('Erro ao atualizar senha: ${e.toString()}');
    }
  }
} 