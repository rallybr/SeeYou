import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chaveamento_campeonato_page.dart';

class ConfrontosCampeonatoPage extends StatefulWidget {
  final String? championshipId;
  const ConfrontosCampeonatoPage({Key? key, this.championshipId}) : super(key: key);

  @override
  State<ConfrontosCampeonatoPage> createState() => _ConfrontosCampeonatoPageState();
}

class _ConfrontosCampeonatoPageState extends State<ConfrontosCampeonatoPage> {
  bool _loading = false;
  List<Map<String, dynamic>> _confrontos = [];
  Map<String, String> _teamNames = {};
  Map<String, String> _groupNames = {};
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
      // Se veio do Drawer com championshipId já selecionado, seta
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
        .select('id, team1_id, team2_id, group_id, phase, status, round')
        .eq('championship_id', _selectedChampionshipId!)
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confrontos do Campeonato'),
        backgroundColor: const Color(0xFF2D2EFF),
        actions: [
          if (_confrontos.any((c) => c['phase'] == 'eliminatoria'))
            IconButton(
              icon: const Icon(Icons.account_tree),
              tooltip: 'Ver Chaveamento',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChaveamentoCampeonatoPage(
                      championshipId: _selectedChampionshipId,
                    ),
                  ),
                );
              },
            ),
        ],
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
                  const SizedBox(height: 8),
                  if (_selectedChampionshipId == null)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Selecione um campeonato para ver os confrontos.', style: TextStyle(color: Colors.white, fontSize: 18)),
                    )
                  else
                    Expanded(
                      child: _confrontos.isEmpty
                          ? const Center(child: Text('Nenhum confronto encontrado.', style: TextStyle(color: Colors.white, fontSize: 18)))
                          : ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                ..._buildConfrontosPorGrupo(),
                              ],
                            ),
                    ),
                ],
              ),
      ),
    );
  }

  List<Widget> _buildConfrontosPorGrupo() {
    final Map<String, List<Map<String, dynamic>>> confrontosPorGrupo = {};
    final List<Map<String, dynamic>> confrontosEliminatorios = [];
    
    for (final c in _confrontos) {
      if (c['phase'] == 'eliminatoria') {
        confrontosEliminatorios.add(c);
      } else {
        final groupId = c['group_id'] ?? '';
        confrontosPorGrupo.putIfAbsent(groupId, () => []);
        confrontosPorGrupo[groupId]!.add(c);
      }
    }

    List<Widget> widgets = [];

    // Adicionar confrontos da fase de grupos
    if (confrontosPorGrupo.isNotEmpty) {
      widgets.add(const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Fase de Grupos',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black26, blurRadius: 2)]),
        ),
      ));

      // Ordenar os grupos alfabeticamente pelo nome
      final sortedGroupIds = confrontosPorGrupo.keys.toList()
        ..sort((a, b) {
          final nameA = _groupNames[a]?.toLowerCase() ?? '';
          final nameB = _groupNames[b]?.toLowerCase() ?? '';
          return nameA.compareTo(nameB);
        });

      for (final groupId in sortedGroupIds) {
        widgets.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 18),
              Text(
                'Confrontos ${_groupNames[groupId] ?? 'Grupo'}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black26, blurRadius: 2)]),
              ),
              const SizedBox(height: 10),
              ...confrontosPorGrupo[groupId]!.map((c) => _buildConfrontoCard(c)),
            ],
          ),
        );
      }
    }

    // Adicionar confrontos da fase eliminatória
    if (confrontosEliminatorios.isNotEmpty) {
      widgets.add(const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Fase Eliminatória',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black26, blurRadius: 2)]),
        ),
      ));

      // Ordenar por rodada
      confrontosEliminatorios.sort((a, b) => (a['round'] ?? 0).compareTo(b['round'] ?? 0));

      for (final c in confrontosEliminatorios) {
        widgets.add(_buildConfrontoCard(c));
      }
    }

    return widgets;
  }

  Widget _buildConfrontoCard(Map<String, dynamic> c) {
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
          child: ListTile(
            leading: Icon(
              c['phase'] == 'eliminatoria' ? Icons.emoji_events : Icons.sports_kabaddi,
              color: c['phase'] == 'eliminatoria' ? Colors.amber : null,
            ),
            title: Text('$team1Name x $team2Name'),
            subtitle: Text(c['phase'] == 'eliminatoria' ? 'Rodada ${c['round']}' : 'Rodada ${c['round'] ?? 1}'),
            trailing: resultado != null
                ? Text(
                    '${resultado['team1_score'] ?? 0} : ${resultado['team2_score'] ?? 0}',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  )
                : const Text('Pendente', style: TextStyle(color: Colors.orange)),
          ),
        );
      },
    );
  }
} 