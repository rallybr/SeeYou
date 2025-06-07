import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChaveamentoCampeonatoPage extends StatefulWidget {
  final String? championshipId;
  const ChaveamentoCampeonatoPage({Key? key, this.championshipId}) : super(key: key);

  @override
  State<ChaveamentoCampeonatoPage> createState() => _ChaveamentoCampeonatoPageState();
}

class _ChaveamentoCampeonatoPageState extends State<ChaveamentoCampeonatoPage> {
  bool _loading = false;
  List<Map<String, dynamic>> _confrontos = [];
  Map<String, String> _teamNames = {};
  List<Map<String, dynamic>> _championships = [];
  String? _selectedChampionshipId;

  @override
  void initState() {
    super.initState();
    _fetchChampionships();
  }

  Future<void> _fetchChampionships() async {
    setState(() => _loading = true);
    final data = await Supabase.instance.client
        .from('quiz_championships')
        .select('id, title');
    setState(() {
      _championships = List<Map<String, dynamic>>.from(data);
      _selectedChampionshipId = widget.championshipId ?? (_championships.isNotEmpty ? _championships.first['id'] : null);
      _loading = false;
    });
    if (_selectedChampionshipId != null) {
      _fetchConfrontos();
    }
  }

  Future<void> _fetchConfrontos() async {
    if (_selectedChampionshipId == null) return;
    setState(() => _loading = true);
    final data = await Supabase.instance.client
        .from('quiz_matches')
        .select('id, team1_id, team2_id, phase, status, round')
        .eq('championship_id', _selectedChampionshipId!)
        .eq('phase', 'eliminatoria')
        .order('round', ascending: true);
    final confrontos = List<Map<String, dynamic>>.from(data);
    
    // Buscar nomes das equipes
    final teamIds = {
      ...confrontos.map((c) => c['team1_id']),
      ...confrontos.map((c) => c['team2_id'])
    }.where((id) => id != null).toSet().toList();
    final teams = await Supabase.instance.client
        .from('quiz_teams')
        .select('id, name')
        .inFilter('id', teamIds);
    final teamNames = <String, String>{};
    for (final t in teams) {
      teamNames[t['id']] = t['name'] ?? '';
    }

    setState(() {
      _confrontos = confrontos;
      _teamNames = teamNames;
      _loading = false;
    });
  }

  Future<Map<String, dynamic>?> _buscarResultadoConfronto(String matchId) async {
    final res = await Supabase.instance.client
        .from('quiz_match_results')
        .select('team1_score, team2_score, winner_team_id')
        .eq('match_id', matchId)
        .maybeSingle();
    return res;
  }

  Widget _buildChaveamento() {
    if (_confrontos.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum confronto da fase eliminatória encontrado.',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      );
    }

    // Organizar confrontos por rodada
    final Map<int, List<Map<String, dynamic>>> confrontosPorRodada = {};
    for (final c in _confrontos) {
      final rodada = c['round'] as int;
      confrontosPorRodada.putIfAbsent(rodada, () => []);
      confrontosPorRodada[rodada]!.add(c);
    }

    // Ordenar rodadas
    final rodadas = confrontosPorRodada.keys.toList()..sort();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rodadas.map((rodada) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Rodada $rodada',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...confrontosPorRodada[rodada]!.map((confronto) {
                  return FutureBuilder<Map<String, dynamic>?>(
                    future: _buscarResultadoConfronto(confronto['id'].toString()),
                    builder: (context, snapshot) {
                      final resultado = snapshot.data;
                      final team1Name = _teamNames[confronto['team1_id']] ?? 'Equipe 1';
                      final team2Name = _teamNames[confronto['team2_id']] ?? 'Equipe 2';
                      final vencedor = resultado?['winner_team_id'];
                      
                      return Container(
                        width: 200,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildEquipeCard(
                              team1Name,
                              resultado?['team1_score'] ?? 0,
                              vencedor == confronto['team1_id'],
                            ),
                            Container(
                              height: 1,
                              color: Colors.grey.withOpacity(0.3),
                            ),
                            _buildEquipeCard(
                              team2Name,
                              resultado?['team2_score'] ?? 0,
                              vencedor == confronto['team2_id'],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }).toList(),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEquipeCard(String nome, int pontos, bool vencedor) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              nome,
              style: TextStyle(
                fontWeight: vencedor ? FontWeight.bold : FontWeight.normal,
                color: vencedor ? Colors.green : Colors.black87,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: vencedor ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              pontos.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: vencedor ? Colors.green : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chaveamento do Campeonato'),
        backgroundColor: const Color(0xFF2D2EFF),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2D2EFF), Color(0xFF7B2FF2), Color(0xFFE94057)],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: DropdownButtonFormField<String>(
                      value: _selectedChampionshipId,
                      decoration: InputDecoration(
                        labelText: 'Selecione o Campeonato',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: _championships
                          .map((c) => DropdownMenuItem<String>(
                                value: c['id'],
                                child: Text(c['title'] ?? 'Sem título'),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedChampionshipId = value;
                        });
                        _fetchConfrontos();
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _buildChaveamento(),
                  ),
                ],
              ),
      ),
    );
  }
} 