import 'package:flutter/material.dart';

typedef OnNextStep1 = Future<void> Function(String email, String senha);

class RegisterStep1Page extends StatefulWidget {
  final OnNextStep1 onNext;
  const RegisterStep1Page({Key? key, required this.onNext}) : super(key: key);

  @override
  State<RegisterStep1Page> createState() => _RegisterStep1PageState();
}

class _RegisterStep1PageState extends State<RegisterStep1Page> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  void _handleNext() async {
    setState(() => _loading = true);
    await widget.onNext(_emailController.text, _senhaController.text);
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Step 1: Cadastro', style: TextStyle(fontSize: 20, color: Colors.blue)),
            const Text('Cadastro - Passo 1', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _senhaController,
              decoration: const InputDecoration(labelText: 'Senha'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _handleNext,
                child: _loading ? const CircularProgressIndicator() : const Text('Próximo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 