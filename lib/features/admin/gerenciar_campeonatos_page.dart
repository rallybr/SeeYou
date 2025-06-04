import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'confrontos_campeonato_page.dart';
import 'ranking_campeonato_page.dart';

class GerenciarCampeonatosPage extends StatefulWidget {
  const GerenciarCampeonatosPage({Key? key}) : super(key: key);

  @override
  State<GerenciarCampeonatosPage> createState() => _GerenciarCampeonatosPageState();
}

class _GerenciarCampeonatosPageState extends State<GerenciarCampeonatosPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _campeonatos = [];
  Map<String, dynamic>? _campeonatoSelecionado;
  List<Map<String, dynamic>> _equipes = [];
  bool _loadingEquipes = false;
  List<Map<String, dynamic>> _grupos = [];
  Map<String, List<Map<String, dynamic>>> _equipesPorGrupo = {};
  bool _sorteando = false;
  List<Map<String, dynamic>> _confrontos = [];
  bool _gerandoConfrontos = false;

  // Campos do formulário de equipe
  final _formEquipeKey = GlobalKey<FormState>();
  String? _nomeEquipe;
  String? _localidadeEquipe;
  String? _logoEquipe;
  bool _salvandoEquipe = false;

  // Novo: Controllers para placar
  final Map<String, TextEditingController> _placarEquipe1 = {};
  final Map<String, TextEditingController> _placarEquipe2 = {};
  bool _salvandoResultado = false;

  Map<String, String> _teamNames = {};
  Map<String, String> _groupNames = {};

  @override
  void initState() {
    super.initState();
    _fetchCampeonatos();
  }

  Future<void> _fetchCampeonatos() async {
    setState(() => _loading = true);
    final data = await Supabase.instance.client
        .from('quiz_championships')
        .select('id, title, num_teams, num_groups, status, created_at')
        .order('created_at', ascending: false);
    setState(() {
      _campeonatos = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  Future<void> _fetchEquipes() async {
    if (_campeonatoSelecionado == null) return;
    setState(() => _loadingEquipes = true);
    final data = await Supabase.instance.client
        .from('quiz_teams')
        .select('id, name, location, logo_url')
        .eq('championship_id', _campeonatoSelecionado!['id']);
    setState(() {
      _equipes = List<Map<String, dynamic>>.from(data);
      _loadingEquipes = false;
    });
  }

  Future<void> _adicionarEquipe() async {
    if (!_formEquipeKey.currentState!.validate()) return;
    _formEquipeKey.currentState!.save();
    setState(() => _salvandoEquipe = true);
    await Supabase.instance.client.from('quiz_teams').insert({
      'name': _nomeEquipe,
      'location': _localidadeEquipe,
      'logo_url': _logoEquipe,
      'championship_id': _campeonatoSelecionado!['id'],
    });
    setState(() {
      _salvandoEquipe = false;
      _nomeEquipe = null;
      _localidadeEquipe = null;
      _logoEquipe = null;
    });
    _formEquipeKey.currentState?.reset();
    _fetchEquipes();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Equipe cadastrada com sucesso!')),
      );
    }
  }

  void _selecionarCampeonato(Map<String, dynamic> campeonato) {
    setState(() {
      _campeonatoSelecionado = campeonato;
    });
    _fetchEquipes();
  }

  Future<void> _sortearEquipesNosGrupos() async {
    if (_campeonatoSelecionado == null || _equipes.isEmpty) return;
    setState(() => _sorteando = true);
    final numGrupos = _campeonatoSelecionado!['num_groups'] as int;
    final campeonatoId = _campeonatoSelecionado!['id'] as String;

    // 1. Criar grupos (A, B, C, ...)
    List<Map<String, dynamic>> gruposCriados = [];
    for (int i = 0; i < numGrupos; i++) {
      final nomeGrupo = 'Grupo ${String.fromCharCode(65 + i)}';
      final grupo = await Supabase.instance.client
          .from('quiz_groups')
          .insert({
            'name': nomeGrupo,
            'championship_id': campeonatoId,
          })
          .select()
          .single();
      gruposCriados.add(grupo);
    }

    // 2. Embaralhar equipes
    final equipesEmbaralhadas = List<Map<String, dynamic>>.from(_equipes);
    equipesEmbaralhadas.shuffle();

    // 3. Distribuir equipes nos grupos
    Map<String, List<Map<String, dynamic>>> equipesPorGrupo = {};
    for (int i = 0; i < equipesEmbaralhadas.length; i++) {
      final grupoIndex = i % numGrupos;
      final grupo = gruposCriados[grupoIndex];
      equipesPorGrupo.putIfAbsent(grupo['id'], () => []);
      equipesPorGrupo[grupo['id']]!.add(equipesEmbaralhadas[i]);
      // Salvar relação no banco
      await Supabase.instance.client.from('quiz_group_teams').insert({
        'group_id': grupo['id'],
        'team_id': equipesEmbaralhadas[i]['id'],
      });
    }

    setState(() {
      _grupos = gruposCriados;
      _equipesPorGrupo = equipesPorGrupo;
      _sorteando = false;
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sorteio realizado com sucesso!')),
      );
    }
  }

  Future<void> _gerarConfrontos() async {
    if (_grupos.isEmpty || _equipesPorGrupo.isEmpty) return;
    setState(() => _gerandoConfrontos = true);
    List<Map<String, dynamic>> confrontosGerados = [];
    for (final grupo in _grupos) {
      final equipes = _equipesPorGrupo[grupo['id']] ?? [];
      final n = equipes.length;
      // Geração de confrontos todos contra todos
      for (int i = 0; i < n; i++) {
        for (int j = i + 1; j < n; j++) {
          final confronto = await Supabase.instance.client
              .from('quiz_matches')
              .insert({
                'championship_id': _campeonatoSelecionado!['id'],
                'group_id': grupo['id'],
                'team1_id': equipes[i]['id'],
                'team2_id': equipes[j]['id'],
                'phase': 'grupos',
                'round': null, // pode ser calculado depois
                'status': 'pendente',
              })
              .select()
              .single();
          confrontosGerados.add({...confronto, 'grupo_nome': grupo['name'], 'team1_nome': equipes[i]['name'], 'team2_nome': equipes[j]['name']});
        }
      }
    }
    setState(() {
      _confrontos = confrontosGerados;
      _gerandoConfrontos = false;
    });
    await _buscarConfrontos();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Confrontos gerados com sucesso!')),
      );
    }
  }

  Future<void> _salvarResultadoConfronto(Map<String, dynamic> confronto, int placar1, int placar2) async {
    setState(() => _salvandoResultado = true);
    // Salvar resultado
    await Supabase.instance.client.from('quiz_match_results').insert({
      'match_id': confronto['id'],
      'team1_score': placar1,
      'team2_score': placar2,
      'winner_team_id': placar1 > placar2 ? confronto['team1_id'] : placar2 > placar1 ? confronto['team2_id'] : null,
      'finished_at': DateTime.now().toIso8601String(),
    });
    // Atualizar status do confronto
    await Supabase.instance.client.from('quiz_matches').update({'status': 'finalizado'}).eq('id', confronto['id']);
    setState(() => _salvandoResultado = false);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resultado salvo!')),
      );
    }
    // Atualizar confrontos na tela
    _buscarConfrontos();
  }

  Future<void> _buscarConfrontos() async {
    if (_campeonatoSelecionado == null) return;
    final data = await Supabase.instance.client
        .from('quiz_matches')
        .select('id, team1_id, team2_id, group_id, phase, status')
        .eq('championship_id', _campeonatoSelecionado!['id'])
        .order('group_id', ascending: true);
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
    });
  }

  Future<void> _atualizarResultadosAutomaticamente() async {
    if (_confrontos.isEmpty) return;
    setState(() => _salvandoResultado = true);
    for (final confronto in _confrontos) {
      if (confronto == null || confronto['status'] != 'pendente') continue;
      final matchId = confronto['id'];
      final team1Id = confronto['team1_id'];
      final team2Id = confronto['team2_id'];
      if (matchId == null || team1Id == null || team2Id == null) continue;
      // Buscar membros das equipes
      final membros1 = await Supabase.instance.client
          .from('quiz_team_members')
          .select('user_id')
          .eq('team_id', team1Id);
      final membros2 = await Supabase.instance.client
          .from('quiz_team_members')
          .select('user_id')
          .eq('team_id', team2Id);
      final userIds1 = membros1?.map((m) => m['user_id']).where((id) => id != null).toList() ?? [];
      final userIds2 = membros2?.map((m) => m['user_id']).where((id) => id != null).toList() ?? [];
      if (userIds1.isEmpty && userIds2.isEmpty) continue;
      // Buscar respostas corretas dos membros no quiz do campeonato
      final quizId = _campeonatoSelecionado!['quiz_id'];
      if (quizId == null) continue;
      // Buscar questões do quiz
      final questoes = await Supabase.instance.client
          .from('quiz_questions')
          .select('id')
          .eq('quiz_id', quizId);
      final questaoIds = questoes?.map((q) => q['id']).where((id) => id != null).toList() ?? [];
      if (questaoIds.isEmpty) continue;
      // Buscar respostas dos membros da equipe 1
      final respostas1 = await Supabase.instance.client
          .from('quiz_answers')
          .select('user_id, question_id, option_id, quiz_options(is_correct)')
          .inFilter('user_id', userIds1)
          .inFilter('question_id', questaoIds);
      // Buscar respostas dos membros da equipe 2
      final respostas2 = await Supabase.instance.client
          .from('quiz_answers')
          .select('user_id, question_id, option_id, quiz_options(is_correct)')
          .inFilter('user_id', userIds2)
          .inFilter('question_id', questaoIds);
      // Calcular pontuação: 1 ponto por resposta correta
      int pontos1 = respostas1?.where((r) => r['quiz_options']?['is_correct'] == true).length ?? 0;
      int pontos2 = respostas2?.where((r) => r['quiz_options']?['is_correct'] == true).length ?? 0;
      // Salvar resultado se ainda não existir
      final jaTemResultado = await Supabase.instance.client
          .from('quiz_match_results')
          .select('id')
          .eq('match_id', matchId)
          .maybeSingle();
      if (jaTemResultado == null) {
        await Supabase.instance.client.from('quiz_match_results').insert({
          'match_id': matchId,
          'team1_score': pontos1,
          'team2_score': pontos2,
          'winner_team_id': pontos1 > pontos2 ? team1Id : pontos2 > pontos1 ? team2Id : null,
          'finished_at': DateTime.now().toIso8601String(),
        });
        await Supabase.instance.client.from('quiz_matches').update({'status': 'finalizado'}).eq('id', matchId);
      }
    }
    setState(() => _salvandoResultado = false);
    await _buscarConfrontos();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resultados atualizados automaticamente!')),
      );
    }
  }

  int _confrontoPlacar(Map<String, dynamic> confronto, int equipe) {
    if (confronto['status'] != 'finalizado') return 0;
    if (equipe == 1) return confronto['team1_score'] ?? 0;
    if (equipe == 2) return confronto['team2_score'] ?? 0;
    return 0;
  }

  // Função auxiliar para buscar placar do confronto a partir de quiz_match_results
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
    if (_campeonatoSelecionado == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2D2EFF),
              Color(0xFF7B2FF2),
              Color(0xFFE94057),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.dashboard, color: Color(0xFF2D2EFF)),
                  label: const Text('Voltar ao Dashboard', style: TextStyle(color: Color(0xFF2D2EFF), fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    elevation: 6,
                    shadowColor: Color(0xFF2D2EFF).withOpacity(0.18),
                    side: const BorderSide(color: Color(0xFF7B2FF2), width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil('/admin', (route) => false);
                  },
                ),
                const SizedBox(height: 32),
                const Text('Gerencie um Campeonato', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 24),
                ..._campeonatos.map((c) => Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: ListTile(
                    leading: const Icon(Icons.emoji_events, color: Color(0xFF2D2EFF)),
                    title: Text(c['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Equipes: ${c['num_teams']}  |  Grupos: ${c['num_groups']}  |  Status: ${c['status'] ?? 'indefinido'}'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _selecionarCampeonato(c),
                  ),
                )),
                if (_campeonatos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('Nenhum campeonato cadastrado.', style: TextStyle(fontSize: 18)),
                  ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Painel de gerenciamento do campeonato selecionado
      return Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2D2EFF),
              Color(0xFF7B2FF2),
              Color(0xFFE94057),
            ],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Gerenciando: ${_campeonatoSelecionado!['title']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.sports_kabaddi, color: Color(0xFF2D2EFF)),
                  label: const Text('Ver Confrontos', style: TextStyle(color: Color(0xFF2D2EFF), fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    elevation: 6,
                    shadowColor: Color(0xFF2D2EFF).withOpacity(0.18),
                    side: const BorderSide(color: Color(0xFF7B2FF2), width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ConfrontosCampeonatoPage(
                          championshipId: _campeonatoSelecionado!['id'],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.leaderboard, color: Color(0xFF2D2EFF)),
                  label: const Text('Ver Ranking dos Grupos', style: TextStyle(color: Color(0xFF2D2EFF), fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    elevation: 6,
                    shadowColor: Color(0xFF2D2EFF).withOpacity(0.18),
                    side: const BorderSide(color: Color(0xFF7B2FF2), width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => RankingCampeonatoPage(
                          championshipId: _campeonatoSelecionado!['id'],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                // Formulário de cadastro de equipe
                Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formEquipeKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Cadastrar Nova Equipe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 12),
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Nome da Equipe',
                              prefixIcon: Icon(Icons.flag),
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
                            onSaved: (v) => _nomeEquipe = v,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Localidade',
                              prefixIcon: Icon(Icons.location_on),
                            ),
                            onSaved: (v) => _localidadeEquipe = v,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'URL do Logo (opcional)',
                              prefixIcon: Icon(Icons.image),
                            ),
                            onSaved: (v) => _logoEquipe = v,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: _salvandoEquipe
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.add),
                            label: const Text('Adicionar Equipe'),
                            onPressed: _salvandoEquipe ? null : _adicionarEquipe,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Listagem das equipes cadastradas
                const Text('Equipes Cadastradas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                _loadingEquipes
                    ? const CircularProgressIndicator()
                    : _equipes.isEmpty
                        ? const Text('Nenhuma equipe cadastrada ainda.')
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _equipes.length,
                            itemBuilder: (context, i) {
                              final equipe = _equipes[i];
                              return ListTile(
                                leading: equipe['logo_url'] != null && equipe['logo_url'].toString().isNotEmpty
                                    ? CircleAvatar(backgroundImage: NetworkImage(equipe['logo_url']))
                                    : const CircleAvatar(child: Icon(Icons.flag)),
                                title: Text(equipe['name'] ?? ''),
                                subtitle: Text(equipe['location'] ?? ''),
                              );
                            },
                          ),
                const SizedBox(height: 24),
                // Botão para sorteio dos grupos (a lógica será implementada em seguida)
                ElevatedButton.icon(
                  icon: const Icon(Icons.shuffle),
                  label: const Text('Sortear Equipes nos Grupos'),
                  onPressed: _equipes.length == (_campeonatoSelecionado!['num_teams'] ?? 0) && !_sorteando
                      ? _sortearEquipesNosGrupos
                      : null,
                ),
                const SizedBox(height: 24),
                if (_grupos.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      const Text('Resultado do Sorteio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 8),
                      ..._grupos.map((grupo) => Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(grupo['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 6),
                                  ...(_equipesPorGrupo[grupo['id']] ?? []).map((equipe) => Row(
                                        children: [
                                          equipe['logo_url'] != null && equipe['logo_url'].toString().isNotEmpty
                                              ? CircleAvatar(backgroundImage: NetworkImage(equipe['logo_url']), radius: 14)
                                              : const CircleAvatar(child: Icon(Icons.flag), radius: 14),
                                          const SizedBox(width: 8),
                                          Text(equipe['name'] ?? '', style: const TextStyle(fontSize: 15)),
                                          if ((equipe['location'] ?? '').toString().isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Text('(${equipe['location']})', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                          ]
                                        ],
                                      )),
                                ],
                              ),
                            ),
                          )),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.sports_kabaddi),
                        label: const Text('Gerar Confrontos'),
                        onPressed: !_gerandoConfrontos && _confrontos.isEmpty ? _gerarConfrontos : null,
                      ),
                      if (_confrontos.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Atualizar Resultados'),
                          onPressed: _salvandoResultado ? null : _atualizarResultadosAutomaticamente,
                        ),
                        const SizedBox(height: 16),
                        const Text('Confrontos Gerados', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        ..._confrontos.map((c) {
                          final id = c['id'].toString();
                          final team1Name = _teamNames[c['team1_id']] ?? 'Equipe 1';
                          final team2Name = _teamNames[c['team2_id']] ?? 'Equipe 2';
                          final groupName = _groupNames[c['group_id']] ?? '';
                          return FutureBuilder<Map<String, dynamic>?>(
                            future: _buscarResultadoConfronto(id),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || snapshot.data == null) {
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  child: ListTile(
                                    leading: const Icon(Icons.sports_kabaddi),
                                    title: Text('$team1Name x $team2Name'),
                                    subtitle: Text(groupName),
                                    trailing: const Text('Pendente', style: TextStyle(color: Colors.orange)),
                                  ),
                                );
                              }
                              final resultado = snapshot.data!;
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  leading: const Icon(Icons.sports_kabaddi),
                                  title: Text('$team1Name x $team2Name'),
                                  subtitle: Text(groupName),
                                  trailing: Text(
                                    '$team1Name ${resultado['team1_score'] ?? 0} : ${resultado['team2_score'] ?? 0} $team2Name',
                                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                      ],
                    ],
                  ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Voltar'),
                  onPressed: () => setState(() => _campeonatoSelecionado = null),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
} 