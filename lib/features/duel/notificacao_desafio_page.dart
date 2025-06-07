import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificacaoDesafioPage extends StatefulWidget {
  final Map<String, dynamic> desafio;
  final Map<String, dynamic> desafiante;

  const NotificacaoDesafioPage({
    super.key,
    required this.desafio,
    required this.desafiante,
  });

  @override
  State<NotificacaoDesafioPage> createState() => _NotificacaoDesafioPageState();
}

class _NotificacaoDesafioPageState extends State<NotificacaoDesafioPage> {
  final _supabase = Supabase.instance.client;
  bool _carregando = false;

  Future<void> _responderDesafio(bool aceitar) async {
    try {
      setState(() => _carregando = true);

      if (aceitar) {
        // Atualiza o status do desafio para aceito
        await _supabase
            .from('quiz_duels')
            .update({'status': 'aceito'})
            .eq('id', widget.desafio['id']);

        // Cria notificação para o desafiante
        await _supabase.from('notifications').insert({
          'user_id': widget.desafio['challenger_id'],
          'type': 'quiz_duel_accepted',
          'title': 'Desafio Aceito',
          'message': 'Seu desafio foi aceito!',
          'created_at': DateTime.now().toIso8601String(),
          'read': false,
        });

        if (mounted) {
          Navigator.pop(context, true); // Retorna true para indicar que foi aceito
        }
      } else {
        // Atualiza o status do desafio para recusado
        await _supabase
            .from('quiz_duels')
            .update({'status': 'recusado'})
            .eq('id', widget.desafio['id']);

        // Cria notificação para o desafiante
        await _supabase.from('notifications').insert({
          'user_id': widget.desafio['challenger_id'],
          'type': 'quiz_duel_rejected',
          'title': 'Desafio Recusado',
          'message': 'Seu desafio foi recusado',
          'created_at': DateTime.now().toIso8601String(),
          'read': false,
        });

        if (mounted) {
          Navigator.pop(context, false); // Retorna false para indicar que foi recusado
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao responder desafio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Desafio'),
        backgroundColor: const Color(0xFF2D2EFF),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2D2EFF), Color(0xFF1A1B4B)],
          ),
        ),
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: widget.desafiante['avatar_url'] != null
                        ? NetworkImage(widget.desafiante['avatar_url'])
                        : null,
                    child: widget.desafiante['avatar_url'] == null
                        ? const Icon(Icons.person, size: 40)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.desafiante['username'] ?? 'Usuário',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'te desafiou para um duelo de quiz!',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_carregando)
                    const CircularProgressIndicator()
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () => _responderDesafio(false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Recusar'),
                        ),
                        ElevatedButton(
                          onPressed: () => _responderDesafio(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text('Aceitar'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 