import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../controller/auth_controller.dart';
import 'register_step1_page.dart';
import 'register_step2_page.dart';
import 'register_step3_page.dart';

class RegisterFlowPage extends StatefulWidget {
  const RegisterFlowPage({Key? key}) : super(key: key);

  @override
  State<RegisterFlowPage> createState() => _RegisterFlowPageState();
}

class _RegisterFlowPageState extends State<RegisterFlowPage> {
  int _currentStep = 0;
  final AuthController _controller = AuthController();
  final _formData = <String, dynamic>{};
  String? _error;
  String? _email;
  String? _senha;

  void _nextStep() => setState(() => _currentStep++);
  void _prevStep() => setState(() => _currentStep--);

  Future<void> _onStep1(String email, String senha) async {
    setState(() => _error = null);
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: senha,
      );
      if (response.user == null) {
        setState(() => _error = 'Erro ao criar usuário.');
        return;
      }
      _formData['email'] = email;
      _formData['senha'] = senha;
      _email = email;
      _senha = senha;
      _nextStep(); // Vai para tela de confirmação de e-mail
    } catch (e) {
      setState(() => _error = 'Erro: ${e.toString()}');
    }
  }

  Future<void> _onEmailConfirmed() async {
    setState(() => _error = null);
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _email!,
        password: _senha!,
      );
      if (response.user == null) {
        setState(() => _error = 'Usuário ainda não confirmou o e-mail.');
        return;
      }
      _nextStep(); // Vai para preenchimento do perfil
    } catch (e) {
      setState(() => _error = 'Erro ao autenticar: ${e.toString()}');
    }
  }

  void _onStep2(Map<String, dynamic> profileData) async {
    // Buscar nome do estado
    String? estadoNome;
    if (profileData['estado_id'] != null) {
      final estado = await Supabase.instance.client
          .from('estados')
          .select('nome')
          .eq('id', profileData['estado_id'])
          .maybeSingle();
      estadoNome = estado != null ? estado['nome'] as String? : null;
    }
    setState(() {
      profileData.forEach((key, value) {
        if (key == 'avatar_url') {
          if (value != null) {
            _formData['avatar_url'] = value;
          }
        } else {
          _formData[key] = value;
        }
      });
      if (estadoNome != null) {
        _formData['estado_nome'] = estadoNome;
      }
      // Só avança o passo se não for apenas atualização do avatar_url
      if (profileData.length > 1 || !profileData.containsKey('avatar_url')) {
        _nextStep();
      }
    });
  }

  Future<void> _onFinish() async {
    setState(() => _error = null);
    print('DEBUG: avatar_url no _onFinish: [32m[1m' + (_formData['avatar_url']?.toString() ?? 'NULL') + '\u001b[0m');
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _error = 'Usuário não autenticado.');
        return;
      }
      final profile = {
        'id': user.id,
        'full_name': _formData['full_name'],
        'username': _formData['username'],
        'avatar_url': _formData['avatar_url'],
        'bio': _formData['bio'],
        'website': _formData['website'],
        'estado_id': _formData['estado_id'],
        'data_nasc': _formData['data_nasc'],
      };
      await Supabase.instance.client.from('profiles').upsert(profile);
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/feed', (route) => false);
      }
    } catch (e) {
      setState(() => _error = 'Erro ao salvar perfil: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6A85F1),
              Color(0xFFFBC2EB),
              Color(0xFFF9F586),
              Color(0xFFF68084),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Card(
                color: Colors.white.withOpacity(0.95),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_error != null) ...[
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 8),
                      ],
                      if (_currentStep == 0)
                        RegisterStep1Page(
                          onNext: _onStep1,
                        )
                      else if (_currentStep == 1)
                        _EmailConfirmationStep(
                          email: _email!,
                          onContinue: _onEmailConfirmed,
                        )
                      else if (_currentStep == 2)
                        RegisterStep2Page(
                          onNext: _onStep2,
                          onBack: _prevStep,
                        )
                      else
                        RegisterStep3Page(
                          profileData: _formData,
                          onFinish: _onFinish,
                          onBack: _prevStep,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmailConfirmationStep extends StatelessWidget {
  final String email;
  final VoidCallback onContinue;
  const _EmailConfirmationStep({required this.email, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Confirme seu e-mail', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
        const SizedBox(height: 16),
        Text('Enviamos um link de confirmação para o e-mail:', textAlign: TextAlign.center),
        Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        const Text('Clique no link recebido para ativar sua conta. Após confirmar, clique no botão abaixo.'),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onContinue,
            child: const Text('Já confirmei, continuar'),
          ),
        ),
      ],
    );
  }
} 