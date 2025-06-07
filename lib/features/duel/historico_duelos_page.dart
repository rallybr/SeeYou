import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'executar_duelo_page.dart';

class HistoricoDuelosPage extends StatefulWidget {
  const HistoricoDuelosPage({super.key});

  @override
  State<HistoricoDuelosPage> createState() => _HistoricoDuelosPageState();
}

class _HistoricoDuelosPageState extends State<HistoricoDuelosPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _duels = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDuels();
  }

  Future<void> _fetchDuels() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _supabase
          .from('quiz_duels')
          .select('''
            *,
            challenger:challenger_id(id, username, avatar_url),
            opponent:opponent_id(id, username, avatar_url)
          ''')
          .or('challenger_id.eq.$userId,opponent_id.eq.$userId')
          .order('created_at', ascending: false);

      setState(() {
        _duels = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar duelos: $e';
        _isLoading = false;
      });
    }
  }

  String _getDuelStatus(Map<String, dynamic> duel) {
    final status = duel['status'] as String;
    final userId = _supabase.auth.currentUser?.id;
    final isChallenger = duel['challenger_id'] == userId;

    switch (status) {
      case 'pendente':
        return isChallenger ? 'Aguardando resposta' : 'Desafio recebido';
      case 'em_andamento':
        return 'Em andamento';
      case 'finalizado':
        final winnerId = duel['winner_id'];
        if (winnerId == null) return 'Empate';
        return winnerId == userId ? 'Vitória' : 'Derrota';
      case 'cancelado':
        return 'Cancelado';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Vitória':
        return Colors.green;
      case 'Derrota':
        return Colors.red;
      case 'Empate':
        return Colors.orange;
      case 'Aguardando resposta':
      case 'Desafio recebido':
        return Colors.blue;
      case 'Em andamento':
        return Colors.purple;
      case 'Cancelado':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Duelos'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF7B2FF2), // Roxo topo
              Color(0xFFF357A8), // Rosa meio
              Color(0xFFF2A93B), // Laranja base
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: TextStyle(color: Colors.white)))
                : _duels.isEmpty
                    ? const Center(child: Text('Nenhum duelo encontrado', style: TextStyle(color: Colors.white)))
                    : ListView.builder(
                        itemCount: _duels.length,
                        itemBuilder: (context, index) {
                          final duel = _duels[index];
                          final status = _getDuelStatus(duel);
                          final challenger = duel['challenger'] as Map<String, dynamic>;
                          final opponent = duel['opponent'] as Map<String, dynamic>;
                          final isChallenger = duel['challenger_id'] == _supabase.auth.currentUser?.id;
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundImage: isChallenger
                                    ? opponent['avatar_url'] != null
                                        ? NetworkImage(opponent['avatar_url'])
                                        : null
                                    : challenger['avatar_url'] != null
                                        ? NetworkImage(challenger['avatar_url'])
                                        : null,
                                child: isChallenger
                                    ? opponent['avatar_url'] == null
                                        ? Text(opponent['username'][0].toUpperCase())
                                        : null
                                    : challenger['avatar_url'] == null
                                        ? Text(challenger['username'][0].toUpperCase())
                                        : null,
                              ),
                              title: Text(
                                isChallenger
                                    ? 'Desafio para @${opponent['username']}'
                                    : 'Desafio de @${challenger['username']}',
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Status: $status',
                                    style: TextStyle(
                                      color: _getStatusColor(status),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (duel['winner_id'] != null)
                                    Text(
                                      'Pontuação: ${duel['challenger_score']} x ${duel['target_score']}',
                                    ),
                                  Text(
                                    'Data: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(duel['created_at']))}',
                                  ),
                                ],
                              ),
                              trailing: duel['status'] == 'pendente' &&
                                      duel['opponent_id'] == _supabase.auth.currentUser?.id
                                  ? ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => ExecutarDueloPage(
                                              duelId: duel['id'],
                                            ),
                                          ),
                                        );
                                      },
                                      child: const Text('Responder'),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
      ),
    );
  }
} 