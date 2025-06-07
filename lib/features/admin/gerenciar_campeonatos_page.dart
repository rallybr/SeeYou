import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'confrontos_campeonato_page.dart';
import 'ranking_campeonato_page.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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

  final ImagePicker _picker = ImagePicker();
  TextEditingController _logoEquipeController = TextEditingController();

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
      'logo_url': _logoEquipeController.text.isNotEmpty ? _logoEquipeController.text : _logoEquipe,
      'championship_id': _campeonatoSelecionado!['id'],
    });
    setState(() {
      _salvandoEquipe = false;
      _nomeEquipe = null;
      _localidadeEquipe = null;
      _logoEquipe = null;
      _logoEquipeController.clear();
    });
    _formEquipeKey.currentState?.reset();
    _fetchEquipes();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Equipe cadastrada com sucesso!')),
      );
    }
  }

  Future<String?> _uploadImageToSupabase(File imageFile) async {
    final fileName = 'logo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storage = Supabase.instance.client.storage.from('logos');
    final res = await storage.upload(fileName, imageFile);
    if (res != null && res.isNotEmpty) {
      final url = storage.getPublicUrl(fileName);
      return url;
    }
    return null;
  }

  Future<void> _pickImageFromGallery(Function(String) onUrl) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final url = await _uploadImageToSupabase(File(image.path));
      if (url != null) onUrl(url);
    }
  }

  Future<void> _pickImageFromCamera(Function(String) onUrl) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      final url = await _uploadImageToSupabase(File(image.path));
      if (url != null) onUrl(url);
    }
  }

  void _selecionarCampeonato(Map<String, dynamic> campeonato) async {
    setState(() {
      _campeonatoSelecionado = campeonato;
      _grupos = [];
      _equipesPorGrupo = {};
      _confrontos = [];
    });
    await _fetchEquipes();
    await _fetchGrupos();
  }

  Future<void> _fetchGrupos() async {
    if (_campeonatoSelecionado == null) return;
    final campeonatoId = _campeonatoSelecionado!['id'] as String;
    final grupos = await Supabase.instance.client
        .from('quiz_groups')
        .select('id, name')
        .eq('championship_id', campeonatoId);
    setState(() {
      _grupos = List<Map<String, dynamic>>.from(grupos);
    });
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

  Future<void> _criarGrupos() async {
    if (_campeonatoSelecionado == null) return;
    setState(() => _loading = true);
    final campeonatoId = _campeonatoSelecionado!['id'] as String;
    try {
      // Buscar grupos já existentes
      final gruposExistentes = await Supabase.instance.client
          .from('quiz_groups')
          .select('id, name')
          .eq('championship_id', campeonatoId);
      print('Grupos existentes:');
      print(gruposExistentes);
      if (gruposExistentes != null && gruposExistentes.isNotEmpty) {
        setState(() {
          _grupos = List<Map<String, dynamic>>.from(gruposExistentes);
          _loading = false;
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Os grupos já existem para este campeonato!')),
          );
        }
        return;
      }
      final numGrupos = _campeonatoSelecionado!['num_groups'] as int;
      List<Map<String, dynamic>> gruposCriados = [];
      for (int i = 0; i < numGrupos; i++) {
        final nomeGrupo = 'Grupo ${String.fromCharCode(65 + i)}';
        print('Criando grupo: $nomeGrupo');
        final grupo = await Supabase.instance.client
            .from('quiz_groups')
            .insert({
              'name': nomeGrupo,
              'championship_id': campeonatoId,
            })
            .select()
            .single();
        print('Grupo criado: $grupo');
        gruposCriados.add(grupo);
      }
      // Buscar novamente os grupos do banco para garantir atualização
      final gruposAtualizados = await Supabase.instance.client
          .from('quiz_groups')
          .select('id, name')
          .eq('championship_id', campeonatoId);
      print('Grupos atualizados:');
      print(gruposAtualizados);
      setState(() {
        _grupos = List<Map<String, dynamic>>.from(gruposAtualizados);
        _loading = false;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grupos criados com sucesso!')),
        );
      }
    } catch (e, s) {
      print('Erro ao criar grupos: $e');
      print(s);
      setState(() => _loading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar grupos: $e')),
        );
      }
    }
  }

  Future<void> _resetarGrupos() async {
    if (_campeonatoSelecionado == null) return;
    final campeonatoId = _campeonatoSelecionado!['id'] as String;
    setState(() => _loading = true);
    try {
      // Buscar grupos do campeonato
      final grupos = await Supabase.instance.client
          .from('quiz_groups')
          .select('id')
          .eq('championship_id', campeonatoId);
      final groupIds = grupos.map((g) => g['id']).toList();
      print('RESET: Grupos encontrados para excluir:');
      print(groupIds);
      // Excluir confrontos e relações
      if (groupIds.isNotEmpty) {
        final del1 = await Supabase.instance.client
            .from('quiz_group_teams')
            .delete()
            .inFilter('group_id', groupIds);
        print('RESET: quiz_group_teams excluídos:');
        print(del1);
        final del2 = await Supabase.instance.client
            .from('quiz_matches')
            .delete()
            .inFilter('group_id', groupIds);
        print('RESET: quiz_matches excluídos:');
        print(del2);
        final del3 = await Supabase.instance.client
            .from('quiz_groups')
            .delete()
            .inFilter('id', groupIds);
        print('RESET: quiz_groups excluídos:');
        print(del3);
      }
      // Buscar novamente os grupos do banco para garantir atualização
      final gruposAtualizados = await Supabase.instance.client
          .from('quiz_groups')
          .select('id, name')
          .eq('championship_id', campeonatoId);
      setState(() {
        _grupos = List<Map<String, dynamic>>.from(gruposAtualizados);
        _equipesPorGrupo = {};
        _confrontos = [];
        _loading = false;
      });
      print('RESET: Grupos após exclusão:');
      print(_grupos);
      // Forçar rebuild para garantir que o botão Criar Grupos apareça
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) setState(() {});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grupos resetados com sucesso!')),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      print('RESET: Erro ao resetar grupos: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao resetar grupos: $e')),
        );
      }
    }
  }

  Future<void> _gerarFaseEliminatoria() async {
    if (_campeonatoSelecionado == null) return;
    setState(() => _gerandoConfrontos = true);

    try {
      // Buscar classificados de cada grupo (2 primeiros)
      final grupos = await Supabase.instance.client
          .from('quiz_groups')
          .select('id, name')
          .eq('championship_id', _campeonatoSelecionado!['id']);
      
      List<String> classificados = [];
      for (final grupo in grupos) {
        // Buscar equipes do grupo
        final equipes = await Supabase.instance.client
            .from('quiz_group_teams')
            .select('team_id')
            .eq('group_id', grupo['id']);
        
        // Buscar resultados das equipes
        final resultados = await Supabase.instance.client
            .from('quiz_match_results')
            .select('match_id, team1_score, team2_score, winner_team_id')
            .inFilter('match_id', _confrontos.where((c) => c['group_id'] == grupo['id']).map((c) => c['id']).toList());
        
        // Calcular pontuação de cada equipe
        Map<String, int> pontos = {};
        for (final equipe in equipes) {
          final teamId = equipe['team_id'];
          pontos[teamId] = 0;
          for (final resultado in resultados) {
            if (resultado['winner_team_id'] == teamId) {
              pontos[teamId] = (pontos[teamId] ?? 0) + 3;
            } else if (resultado['team1_score'] == resultado['team2_score']) {
              pontos[teamId] = (pontos[teamId] ?? 0) + 1;
            }
          }
        }
        
        // Ordenar equipes por pontos e pegar as 2 primeiras
        final equipesOrdenadas = pontos.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        
        classificados.addAll(equipesOrdenadas.take(2).map((e) => e.key));
      }

      // Gerar confrontos da fase eliminatória
      final numEquipes = classificados.length;
      final numRodadas = (numEquipes / 2).ceil();
      
      for (int i = 0; i < numEquipes; i += 2) {
        if (i + 1 < numEquipes) {
          await Supabase.instance.client
              .from('quiz_matches')
              .insert({
                'championship_id': _campeonatoSelecionado!['id'],
                'team1_id': classificados[i],
                'team2_id': classificados[i + 1],
                'phase': 'eliminatoria',
                'round': 1,
                'status': 'pendente',
              });
        }
      }

      await _buscarConfrontos();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fase eliminatória gerada com sucesso!')),
        );
      }
    } catch (e) {
      print('Erro ao gerar fase eliminatória: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar fase eliminatória: $e')),
        );
      }
    } finally {
      setState(() => _gerandoConfrontos = false);
    }
  }

  Future<void> _gerarProximaRodadaEliminatoria() async {
    if (_campeonatoSelecionado == null) return;
    setState(() => _gerandoConfrontos = true);

    try {
      // Buscar confrontos da última rodada
      final confrontosAtuais = await Supabase.instance.client
          .from('quiz_matches')
          .select('id, team1_id, team2_id, round')
          .eq('championship_id', _campeonatoSelecionado!['id'])
          .eq('phase', 'eliminatoria')
          .order('round', ascending: false);

      if (confrontosAtuais.isEmpty) {
        throw Exception('Nenhum confronto encontrado na fase eliminatória');
      }

      final ultimaRodada = confrontosAtuais.first['round'] as int;
      final confrontosUltimaRodada = confrontosAtuais.where((c) => c['round'] == ultimaRodada).toList();

      // Verificar se todos os confrontos da última rodada foram finalizados
      for (final confronto in confrontosUltimaRodada) {
        final resultado = await Supabase.instance.client
            .from('quiz_match_results')
            .select('winner_team_id')
            .eq('match_id', confronto['id'])
            .maybeSingle();
        
        if (resultado == null || resultado['winner_team_id'] == null) {
          throw Exception('Existem confrontos pendentes na última rodada');
        }
      }

      // Coletar vencedores da última rodada
      List<String> vencedores = [];
      for (final confronto in confrontosUltimaRodada) {
        final resultado = await Supabase.instance.client
            .from('quiz_match_results')
            .select('winner_team_id')
            .eq('match_id', confronto['id'])
            .single();
        vencedores.add(resultado['winner_team_id']);
      }

      // Gerar confrontos da próxima rodada
      final numEquipes = vencedores.length;
      if (numEquipes < 2) {
        throw Exception('Não há equipes suficientes para a próxima rodada');
      }

      for (int i = 0; i < numEquipes; i += 2) {
        if (i + 1 < numEquipes) {
          await Supabase.instance.client
              .from('quiz_matches')
              .insert({
                'championship_id': _campeonatoSelecionado!['id'],
                'team1_id': vencedores[i],
                'team2_id': vencedores[i + 1],
                'phase': 'eliminatoria',
                'round': ultimaRodada + 1,
                'status': 'pendente',
              });
        }
      }

      await _buscarConfrontos();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Próxima rodada gerada com sucesso!')),
        );
      }
    } catch (e) {
      print('Erro ao gerar próxima rodada: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar próxima rodada: $e')),
        );
      }
    } finally {
      setState(() => _gerandoConfrontos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG: Quantidade de grupos no build: ${_grupos.length}');
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_campeonatoSelecionado == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Gerenciar Campeonatos'),
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
      );
    } else {
      // Painel de gerenciamento do campeonato selecionado
      return Scaffold(
        appBar: AppBar(
          title: Text(_campeonatoSelecionado!['title'] ?? 'Gerenciar Campeonato'),
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
              const SizedBox(height: 24),
              // Formulário de cadastro de equipe
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formEquipeKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cadastrar Nova Equipe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Nome da Equipe',
                            prefixIcon: const Icon(Icons.flag, color: Color(0xFF2D2EFF)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
                          onSaved: (v) => _nomeEquipe = v,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Localidade',
                            prefixIcon: const Icon(Icons.location_city, color: Color(0xFF7B2FF2)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
                          onSaved: (v) => _localidadeEquipe = v,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _logoEquipeController,
                          decoration: InputDecoration(
                            labelText: 'URL do Logo (opcional)',
                            prefixIcon: const Icon(Icons.image, color: Color(0xFFE94057)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onSaved: (v) => _logoEquipe = v,
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.photo_library, color: Color(0xFF2D2EFF)),
                              tooltip: 'Selecionar da galeria',
                              onPressed: () async {
                                await _pickImageFromGallery((url) {
                                  _logoEquipeController.text = url;
                                  _logoEquipe = url;
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.camera_alt, color: Color(0xFF2D2EFF)),
                              tooltip: 'Tirar foto',
                              onPressed: () async {
                                await _pickImageFromCamera((url) {
                                  _logoEquipeController.text = url;
                                  _logoEquipe = url;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save, color: Colors.white),
                          label: const Text('Salvar Equipe', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D2EFF),
                            elevation: 6,
                            shadowColor: Color(0xFF2D2EFF).withOpacity(0.18),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _salvandoEquipe ? null : _adicionarEquipe,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Lista de equipes
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Equipes Cadastradas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _loadingEquipes
                          ? const CircularProgressIndicator()
                          : _equipes.isEmpty
                              ? const Text('Nenhuma equipe cadastrada ainda.')
                              : Column(
                                  children: [
                                    for (final equipe in _equipes)
                                      ListTile(
                                        leading: equipe['logo_url'] != null && equipe['logo_url'].toString().isNotEmpty
                                            ? CircleAvatar(backgroundImage: NetworkImage(equipe['logo_url']))
                                            : const CircleAvatar(child: Icon(Icons.flag)),
                                        title: Text(equipe['name'] ?? ''),
                                        subtitle: Text(equipe['location'] ?? ''),
                                      ),
                                  ],
                                ),
                    ],
                  ),
                ),
              ),
              // Botão Criar Grupos destacado após lista de equipes
              if (_grupos.isEmpty) ...[
                const SizedBox(height: 24),
                Card(
                  color: Color(0xFF2D2EFF).withOpacity(0.08),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_circle),
                        label: const Text('Criar Grupos'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D2EFF),
                          foregroundColor: Colors.white,
                          elevation: 6,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => _criarGrupos(),
                      ),
                    ),
                  ),
                ),
              ],
              // Exibir grupos criados (antes do sorteio)
              if (_grupos.isNotEmpty && _equipesPorGrupo.isEmpty) ...[
                const SizedBox(height: 16),
                const Text('Grupos Criados', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                ..._grupos.map((grupo) => Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(grupo['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    )),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.shuffle),
                  label: const Text('Distribuir Equipes nos Grupos'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D2EFF),
                    foregroundColor: Colors.white,
                    elevation: 6,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _equipes.length == (_campeonatoSelecionado!['num_teams'] ?? 0) && !_sorteando
                      ? _sortearEquipesNosGrupos
                      : null,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: const Text('Resetar Grupos', style: TextStyle(color: Colors.red)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    elevation: 4,
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _resetarGrupos,
                ),
              ],
              // Exibir equipes sorteadas em cada grupo
              if (_grupos.isNotEmpty && _equipesPorGrupo.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('Equipes Sorteadas nos Grupos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.emoji_events),
                  label: const Text('Gerar Fase Eliminatória'),
                  onPressed: _confrontos.isNotEmpty && _confrontos.every((c) => c['status'] == 'finalizado') ? _gerarFaseEliminatoria : null,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Gerar Próxima Rodada'),
                  onPressed: _confrontos.any((c) => c['phase'] == 'eliminatoria') && 
                           _confrontos.where((c) => c['phase'] == 'eliminatoria').every((c) => c['status'] == 'finalizado') ? 
                           _gerarProximaRodadaEliminatoria : null,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: const Text('Resetar Grupos', style: TextStyle(color: Colors.red)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    elevation: 4,
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _resetarGrupos,
                ),
              ],
            ],
          ),
        ),
      );
    }
  }
} 