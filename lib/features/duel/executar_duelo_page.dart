import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExecutarDueloPage extends StatefulWidget {
  final String duelId;

  const ExecutarDueloPage({
    super.key,
    required this.duelId,
  });

  @override
  State<ExecutarDueloPage> createState() => _ExecutarDueloPageState();
}

class _ExecutarDueloPageState extends State<ExecutarDueloPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _perguntas = [];
  Map<String, dynamic>? _duel;
  int _perguntaAtual = 0;
  int _pontuacao = 0;
  bool _carregando = true;
  String? _erro;
  bool _respondido = false;
  String? _respostaSelecionada;
  bool _mostrarResultado = false;

  @override
  void initState() {
    super.initState();
    _carregarDuelo();
  }

  Future<void> _carregarDuelo() async {
    try {
      setState(() {
        _carregando = true;
        _erro = null;
      });

      // Busca informações do duelo
      final duel = await _supabase
          .from('quiz_duels')
          .select('*, challenger:challenger_id(id, username), opponent:opponent_id(id, username)')
          .eq('id', widget.duelId)
          .single();

      setState(() {
        _duel = duel;
      });

      // Busca perguntas aleatórias
      final response = await _supabase
          .from('quiz_questions')
          .select()
          .limit(10);

      // Embaralha as perguntas no lado do app
      final perguntasList = List<Map<String, dynamic>>.from(response);
      perguntasList.shuffle();

      setState(() {
        _perguntas = perguntasList;
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _erro = 'Erro ao carregar duelo: $e';
        _carregando = false;
      });
    }
  }

  Future<void> _responderPergunta(String resposta) async {
    if (_respondido) return;

    setState(() {
      _respostaSelecionada = resposta;
      _respondido = true;
    });

    // Verifica se a resposta está correta
    final pergunta = _perguntas[_perguntaAtual];
    if (resposta == pergunta['correct_answer']) {
      setState(() => _pontuacao++);
    }

    // Aguarda 1 segundo antes de passar para a próxima pergunta
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() {
        if (_perguntaAtual < _perguntas.length - 1) {
          _perguntaAtual++;
          _respondido = false;
          _respostaSelecionada = null;
        } else {
          _mostrarResultado = true;
          _salvarResultado();
        }
      });
    }
  }

  Future<void> _salvarResultado() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuário não autenticado');

      // Salva o resultado do duelo
      await _supabase.from('quiz_duel_results').insert({
        'duel_id': widget.duelId,
        'user_id': userId,
        'score': _pontuacao,
        'total_questions': _perguntas.length,
        'completed_at': DateTime.now().toIso8601String(),
      });

      // Verifica se ambos os jogadores já completaram
      final resultados = await _supabase
          .from('quiz_duel_results')
          .select()
          .eq('duel_id', widget.duelId);

      if (resultados.length == 2) {
        // Determina o vencedor
        final jogador1 = resultados[0];
        final jogador2 = resultados[1];
        final vencedorId = jogador1['score'] > jogador2['score']
            ? jogador1['user_id']
            : jogador2['user_id'];

        // Atualiza o status do duelo
        await _supabase
            .from('quiz_duels')
            .update({
              'status': 'finalizado',
              'winner_id': vencedorId,
              'challenger_score': jogador1['score'],
              'target_score': jogador2['score'],
            })
            .eq('id', widget.duelId);

        // Cria notificações para ambos os jogadores
        final perdedorId = vencedorId == jogador1['user_id']
            ? jogador2['user_id']
            : jogador1['user_id'];

        await _supabase.from('notifications').insert([
          {
            'user_id': vencedorId,
            'type': 'quiz_duel_won',
            'title': 'Você Venceu!',
            'message': 'Parabéns! Você venceu o duelo de quiz!',
            'created_at': DateTime.now().toIso8601String(),
            'read': false,
          },
          {
            'user_id': perdedorId,
            'type': 'quiz_duel_lost',
            'title': 'Duelo Finalizado',
            'message': 'O duelo de quiz foi finalizado. Melhor sorte na próxima!',
            'created_at': DateTime.now().toIso8601String(),
            'read': false,
          },
        ]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar resultado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_erro != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _erro!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _carregarDuelo,
                child: const Text('Tentar Novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (_mostrarResultado) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Resultado do Duelo'),
        ),
        body: Center(
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.emoji_events,
                    size: 64,
                    color: Colors.amber,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sua pontuação: $_pontuacao/${_perguntas.length}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Voltar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final pergunta = _perguntas[_perguntaAtual];
    final respostas = [
      (pergunta['correct_answer'] ?? ''),
      ...List<String>.from(pergunta['wrong_answers'] ?? []),
    ]..shuffle();

    return Scaffold(
      appBar: AppBar(
        title: Text('Pergunta ${_perguntaAtual + 1}/${_perguntas.length}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pergunta['question'] ?? '',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    ...respostas.map((resposta) {
                      final isSelected = _respostaSelecionada == resposta;
                      final isCorrect = resposta == (pergunta['correct_answer'] ?? '');
                      Color? backgroundColor;
                      if (_respondido) {
                        if (isCorrect) {
                          backgroundColor = Colors.green.withOpacity(0.2);
                        } else if (isSelected) {
                          backgroundColor = Colors.red.withOpacity(0.2);
                        }
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: _respondido ? null : () => _responderPergunta(resposta),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? Colors.blue : Colors.grey,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(child: Text(resposta ?? '')),
                                if (_respondido && isCorrect)
                                  const Icon(Icons.check_circle, color: Colors.green),
                                if (_respondido && isSelected && !isCorrect)
                                  const Icon(Icons.cancel, color: Colors.red),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Pontuação: $_pontuacao',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
} 