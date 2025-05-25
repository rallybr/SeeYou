import 'package:flutter/material.dart';

typedef OnFinishStep = Future<void> Function();
typedef OnBackStep = void Function();

class RegisterStep3Page extends StatelessWidget {
  final Map<String, dynamic> profileData;
  final OnFinishStep onFinish;
  final OnBackStep onBack;
  const RegisterStep3Page({Key? key, required this.profileData, required this.onFinish, required this.onBack}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String dataNasc = '';
    if (profileData['data_nasc'] != null && profileData['data_nasc'].toString().isNotEmpty) {
      final parts = profileData['data_nasc'].toString().split('-');
      if (parts.length == 3) {
        dataNasc = '${parts[2].padLeft(2, '0')}/${parts[1].padLeft(2, '0')}/${parts[0]}';
      } else {
        dataNasc = profileData['data_nasc'].toString();
      }
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (profileData['avatar_url'] != null && profileData['avatar_url'].toString().isNotEmpty)
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundImage: NetworkImage(profileData['avatar_url']),
                  backgroundColor: Colors.grey[300],
                ),
              ),
            const SizedBox(height: 16),
            const Text('Step 3: Confirmação', style: TextStyle(fontSize: 20, color: Colors.purple)),
            const Text('Cadastro - Passo 3', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Confira seus dados:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildInfo('Nome', profileData['full_name'] ?? ''),
            _buildInfo('Username', profileData['username'] ?? ''),
            _buildInfo('Bio', profileData['bio'] ?? ''),
            _buildInfo('Website', profileData['website'] ?? ''),
            _buildInfo('Estado', profileData['estado_nome'] ?? profileData['estado_id']?.toString() ?? ''),
            _buildInfo('Data de nascimento', dataNasc),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onBack,
                    child: const Text('Voltar'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onFinish,
                    child: const Text('Concluir cadastro'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
} 