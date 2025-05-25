import 'package:flutter/material.dart';

class AuthController extends ChangeNotifier {
  // Aqui você pode adicionar métodos para login, cadastro, salvar perfil, etc.
  // Exemplo de variáveis para armazenar dados temporários do cadastro:
  String? email;
  String? senha;
  Map<String, dynamic> profileData = {};

  void setEmailSenha(String email, String senha) {
    this.email = email;
    this.senha = senha;
    notifyListeners();
  }

  void setProfileData(Map<String, dynamic> data) {
    profileData = data;
    notifyListeners();
  }

  // Métodos para integração com Supabase serão adicionados aqui depois
} 