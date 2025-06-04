import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConfrontosCampeonatoPage extends StatefulWidget {
  final String championshipId;
  const ConfrontosCampeonatoPage({Key? key, required this.championshipId}) : super(key: key);

  @override
  State<ConfrontosCampeonatoPage> createState() => _ConfrontosCampeonatoPageState();
}

class _ConfrontosCampeonatoPageState extends State<ConfrontosCampeonatoPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _confrontos = [];
  Map<String, String> _teamNames = {};
  Map<String, String> _groupNames = {};

  @override
  void initState() {
    super.initState();
    _fetchConfrontos();
  }

  Future<void> _fetchConfrontos() async {
    setState(() => _loading = true);
    final data = await Supabase.instance.client
        .from('quiz_matches')
        .select('id, team1_id, team2_id, group_id, phase, status, round')
        .eq('championship_id', widget.championshipId)
        .order('group_id', ascending: true)
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
    // Buscar nomes dos grupos
    final groupIds = confrontos.map((c) => c['group_id']).where((id) => id != null).toSet().toList();
    final groups = await Supabase.instance.client
        .from('quiz_groups')
        .select('id, name')
        .inFilter('id', groupIds);
    final groupNames = <String, String>{};
    for (final g in groups) {
      groupNames[g['id']] = g['name'] ?? '';
    }
    setState(() {
      _confrontos = confrontos;
      _teamNames = teamNames;
      _groupNames = groupNames;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    // Agrupar confrontos por grupo e rodada
    final Map<String, Map<int, List<Map<String, dynamic>>>> gruposRodadas = {};
    for (final c in _confrontos) {
      final groupId = c['group_id'] ?? '';
      final rodada = (c['round'] ?? 1) as int;
      gruposRodadas.putIfAbsent(groupId, () => {});
      gruposRodadas[groupId]!.putIfAbsent(rodada, () => []);
      gruposRodadas[groupId]![rodada]!.add(c);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confrontos do Campeonato'),
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final groupId in gruposRodadas.keys)
              for (final rodada in gruposRodadas[groupId]!.keys)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 18),
                    Text(
                      '${_groupNames[groupId] ?? 'Grupo'} - Rodada $rodada',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black26, blurRadius: 2)]),
                    ),
                    const SizedBox(height: 10),
                    ...gruposRodadas[groupId]![rodada]!.map((c) {
                      final team1Name = _teamNames[c['team1_id']] ?? 'Equipe 1';
                      final team2Name = _teamNames[c['team2_id']] ?? 'Equipe 2';
                      return FutureBuilder<Map<String, dynamic>?>(
                        future: _buscarResultadoConfronto(c['id'].toString()),
                        builder: (context, snapshot) {
                          final resultado = snapshot.data;
                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 6,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            color: Colors.white.withOpacity(0.92),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                              child: Row(
                                children: [
                                  const Icon(Icons.sports_kabaddi, color: Color(0xFF2D2EFF), size: 28),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      '$team1Name  vs  $team2Name',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                                    ),
                                  ),
                                  if (resultado != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.green[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${resultado['team1_score'] ?? 0} : ${resultado['team2_score'] ?? 0}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
                                      ),
                                    )
                                  else
                                    const Text('Pendente', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ],
                ),
          ],
        ),
      ),
    );
  }
} 