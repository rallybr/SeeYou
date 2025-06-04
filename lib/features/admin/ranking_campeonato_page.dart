import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RankingCampeonatoPage extends StatefulWidget {
  final String? championshipId;
  const RankingCampeonatoPage({Key? key, this.championshipId}) : super(key: key);

  @override
  State<RankingCampeonatoPage> createState() => _RankingCampeonatoPageState();
}

class _RankingCampeonatoPageState extends State<RankingCampeonatoPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _grupos = [];
  Map<String, String> _groupNames = {};
  Map<String, List<Map<String, dynamic>>> _classificacaoPorGrupo = {};

  @override
  void initState() {
    super.initState();
    if (widget.championshipId != null) {
      _fetchRanking();
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchRanking() async {
    setState(() => _loading = true);
    // Buscar grupos do campeonato
    final grupos = await Supabase.instance.client
        .from('quiz_groups')
        .select('id, name')
        .eq('championship_id', widget.championshipId!);
    final groupNames = <String, String>{};
    for (final g in grupos) {
      groupNames[g['id']] = g['name'] ?? '';
    }
    // Buscar equipes de cada grupo
    final groupIds = grupos.map((g) => g['id']).toList();
    final groupTeams = await Supabase.instance.client
        .from('quiz_group_teams')
        .select('group_id, team_id')
        .inFilter('group_id', groupIds);
    // Buscar nomes das equipes
    final teamIds = groupTeams.map((gt) => gt['team_id']).toSet().toList();
    final teams = await Supabase.instance.client
        .from('quiz_teams')
        .select('id, name')
        .inFilter('id', teamIds);
    final teamNames = <String, String>{};
    for (final t in teams) {
      teamNames[t['id']] = t['name'] ?? '';
    }
    // Buscar resultados dos confrontos
    final matches = await Supabase.instance.client
        .from('quiz_matches')
        .select('id, group_id, team1_id, team2_id')
        .eq('championship_id', widget.championshipId!);
    final matchIds = matches.map((m) => m['id']).toList();
    final results = await Supabase.instance.client
        .from('quiz_match_results')
        .select('match_id, team1_score, team2_score, winner_team_id')
        .inFilter('match_id', matchIds);
    // Calcular classificação por grupo
    final Map<String, List<Map<String, dynamic>>> classificacaoPorGrupo = {};
    for (final g in grupos) {
      final gid = g['id'];
      final equipesDoGrupo = groupTeams.where((gt) => gt['group_id'] == gid).map((gt) => gt['team_id']).toList();
      final List<Map<String, dynamic>> tabela = [];
      for (final tid in equipesDoGrupo) {
        int pontos = 0, vitorias = 0, empates = 0, derrotas = 0, saldo = 0, jogados = 0, golsPro = 0, golsContra = 0;
        for (final m in matches.where((m) => m['group_id'] == gid)) {
          final r = results.firstWhere((r) => r['match_id'] == m['id'], orElse: () => <String, dynamic>{});
          if (r.isEmpty) continue;
          if (m['team1_id'] == tid || m['team2_id'] == tid) {
            jogados++;
            final isTeam1 = m['team1_id'] == tid;
            final golsFeitos = (isTeam1 ? (r['team1_score'] ?? 0) : (r['team2_score'] ?? 0));
            final golsSofridos = (isTeam1 ? (r['team2_score'] ?? 0) : (r['team1_score'] ?? 0));
            golsPro += (golsFeitos is int) ? golsFeitos : (golsFeitos as num).toInt();
            golsContra += (golsSofridos is int) ? golsSofridos : (golsSofridos as num).toInt();
            saldo += ((golsFeitos is int ? golsFeitos : (golsFeitos as num).toInt()) - (golsSofridos is int ? golsSofridos : (golsSofridos as num).toInt()));
            if (r['team1_score'] == r['team2_score']) {
              empates++;
              pontos += 1;
            } else if (r['winner_team_id'] == tid) {
              vitorias++;
              pontos += 3;
            } else {
              derrotas++;
            }
          }
        }
        tabela.add({
          'team_id': tid,
          'nome': teamNames[tid] ?? '',
          'pontos': pontos,
          'vitorias': vitorias,
          'empates': empates,
          'derrotas': derrotas,
          'saldo': saldo,
          'jogados': jogados,
          'golsPro': golsPro,
          'golsContra': golsContra,
        });
      }
      tabela.sort((a, b) {
        if (b['pontos'] != a['pontos']) return b['pontos'] - a['pontos'];
        if (b['saldo'] != a['saldo']) return b['saldo'] - a['saldo'];
        if (b['golsPro'] != a['golsPro']) return b['golsPro'] - a['golsPro'];
        return a['nome'].compareTo(b['nome']);
      });
      classificacaoPorGrupo[gid] = tabela;
    }
    setState(() {
      _grupos = List<Map<String, dynamic>>.from(grupos);
      _groupNames = groupNames;
      _classificacaoPorGrupo = classificacaoPorGrupo;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.championshipId == null) {
      return const Center(child: Text('ID do campeonato não informado!'));
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ranking dos Grupos'),
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
            for (final g in _grupos)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 18),
                  Text(
                    _groupNames[g['id']] ?? 'Grupo',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black26, blurRadius: 2)]),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 6,
                    color: Colors.white.withOpacity(0.95),
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Equipe', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Pts', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('V', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('E', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('D', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('SG', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('J', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('GP', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('GC', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: [
                        for (final t in _classificacaoPorGrupo[g['id']] ?? [])
                          DataRow(cells: [
                            DataCell(Text(t['nome'] ?? '')),
                            DataCell(Text('${t['pontos']}')),
                            DataCell(Text('${t['vitorias']}')),
                            DataCell(Text('${t['empates']}')),
                            DataCell(Text('${t['derrotas']}')),
                            DataCell(Text('${t['saldo']}')),
                            DataCell(Text('${t['jogados']}')),
                            DataCell(Text('${t['golsPro']}')),
                            DataCell(Text('${t['golsContra']}')),
                          ]),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
} 