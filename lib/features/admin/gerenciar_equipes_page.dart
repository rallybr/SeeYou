import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart'; // Para gráficos simples
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class GerenciarEquipesPage extends StatefulWidget {
  const GerenciarEquipesPage({Key? key}) : super(key: key);

  @override
  State<GerenciarEquipesPage> createState() => _GerenciarEquipesPageState();
}

class _GerenciarEquipesPageState extends State<GerenciarEquipesPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _equipes = [];
  List<Map<String, dynamic>> _campeonatos = [];
  String? _selectedChampionshipId;
  List<Map<String, dynamic>> _todasEquipes = [];
  String _filtroSituacao = 'ativo';
  String _filtroBusca = '';
  final ImagePicker _picker = ImagePicker();
  TextEditingController _logoUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCampeonatos();
    _fetchTodasEquipes();
  }

  Future<void> _fetchCampeonatos() async {
    setState(() => _loading = true);
    final data = await Supabase.instance.client
        .from('quiz_championships')
        .select('id, title')
        .order('created_at', ascending: false);
    setState(() {
      _campeonatos = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  Future<void> _fetchEquipes() async {
    if (_selectedChampionshipId == null) return;
    setState(() => _loading = true);
    var query = Supabase.instance.client
        .from('quiz_teams')
        .select('id, name, location, logo_url, situacao')
        .eq('championship_id', _selectedChampionshipId!);
    if (_filtroSituacao != 'todos') {
      query = query.eq('situacao', _filtroSituacao);
    }
    final data = await query;
    setState(() {
      _equipes = List<Map<String, dynamic>>.from(data)
        .where((e) => _filtroBusca.isEmpty || (e['name']?.toLowerCase().contains(_filtroBusca.toLowerCase()) ?? false) || (e['location']?.toLowerCase().contains(_filtroBusca.toLowerCase()) ?? false))
        .toList();
      _loading = false;
    });
  }

  Future<void> _fetchTodasEquipes() async {
    // Busca todas as equipes cadastradas no sistema (independente do campeonato)
    final data = await Supabase.instance.client
        .from('quiz_teams')
        .select('id, name, location, logo_url, championship_id, situacao')
        .eq('situacao', 'ativo');
    setState(() {
      _todasEquipes = List<Map<String, dynamic>>.from(data);
    });
  }

  Future<void> _removerEquipeDoCampeonato(String equipeId, String championshipId) async {
    print('Tentando remover equipe $equipeId do campeonato $championshipId');
    setState(() => _loading = true);
    try {
      // 1. Buscar todos os confrontos da equipe neste campeonato
      final matches = await Supabase.instance.client
          .from('quiz_matches')
          .select('id')
          .or('team1_id.eq.$equipeId,team2_id.eq.$equipeId')
          .eq('championship_id', championshipId)
          .eq('situacao', 'ativo');
      print('Confrontos encontrados: ' + matches.toString());

      if (matches != null && matches.isNotEmpty) {
        final matchIds = matches.map((m) => m['id'].toString()).toList();

        // Marcar resultados dos confrontos como removido
        if (matchIds.isNotEmpty) {
          await Supabase.instance.client
              .from('quiz_match_results')
              .update({'situacao': 'removido'})
              .inFilter('match_id', matchIds);
          // Marcar confrontos como removido
          await Supabase.instance.client
              .from('quiz_matches')
              .update({'situacao': 'removido'})
              .inFilter('id', matchIds);
        }
      }

      // 2. Marcar a equipe como removida neste campeonato
      final resUpdate = await Supabase.instance.client
          .from('quiz_teams')
          .update({'situacao': 'removido'})
          .eq('id', equipeId)
          .eq('championship_id', championshipId);
      print('Resultado update quiz_teams: ' + resUpdate.toString());

      await _fetchEquipes();
      await _fetchTodasEquipes();
      setState(() {});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Equipe desvinculada do campeonato (histórico preservado)!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: const Color(0xFF2D2EFF),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Erro ao remover equipe: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao remover equipe: $e', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _vincularEquipe(String equipeId) async {
    if (_selectedChampionshipId == null) return;
    setState(() => _loading = true);
    // Atualiza o championship_id da equipe para o campeonato selecionado
    await Supabase.instance.client
        .from('quiz_teams')
        .update({'championship_id': _selectedChampionshipId})
        .eq('id', equipeId);
    await _fetchEquipes();
    await _fetchTodasEquipes();
    setState(() => _loading = false);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Equipe vinculada ao campeonato com sucesso!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF2D2EFF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          duration: const Duration(seconds: 2),
        ),
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

  void _abrirModalVincularEquipe() async {
    if (_selectedChampionshipId == null) return;
    String busca = '';
    String? equipeSelecionada;
    bool cadastrando = false;
    String novoNome = '', novoLocal = '', novoLogo = '';

    // Buscar grupos do campeonato
    final grupos = await Supabase.instance.client
        .from('quiz_groups')
        .select('id')
        .eq('championship_id', _selectedChampionshipId!);
    final groupIds = grupos.map((g) => g['id']).toList();

    // Buscar equipes já vinculadas a esses grupos
    final vinculadas = groupIds.isEmpty
        ? []
        : await Supabase.instance.client
            .from('quiz_group_teams')
            .select('team_id')
            .inFilter('group_id', groupIds);
    final idsVinculadas = vinculadas.map((e) => e['team_id']).toSet();

    // Filtrar equipes ativas que ainda não participam deste campeonato
    List<Map<String, dynamic>> equipesDisponiveis = _todasEquipes
        .where((e) => !idsVinculadas.contains(e['id']))
        .toList();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // Aplicar filtro de busca
            final equipesFiltradas = equipesDisponiveis.where((e) =>
              busca.isEmpty ||
              (e['name']?.toLowerCase().contains(busca.toLowerCase()) ?? false) ||
              (e['location']?.toLowerCase().contains(busca.toLowerCase()) ?? false)
            ).toList();

            return AlertDialog(
              title: Text(cadastrando ? 'Criar uma Nova Equipe' : 'Vincular Equipe ao Campeonato'),
              content: cadastrando
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          decoration: const InputDecoration(labelText: 'Nome da equipe'),
                          onChanged: (v) => novoNome = v,
                        ),
                        TextField(
                          decoration: const InputDecoration(labelText: 'Localidade'),
                          onChanged: (v) => novoLocal = v,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _logoUrlController,
                                decoration: const InputDecoration(labelText: 'URL do logo (opcional)'),
                                onChanged: (v) => novoLogo = v,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.photo_library, color: Color(0xFF2D2EFF)),
                                  tooltip: 'Selecionar da galeria',
                                  onPressed: () async {
                                    await _pickImageFromGallery((url) {
                                      _logoUrlController.text = url;
                                      novoLogo = url;
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.camera_alt, color: Color(0xFF2D2EFF)),
                                  tooltip: 'Tirar foto',
                                  onPressed: () async {
                                    await _pickImageFromCamera((url) {
                                      _logoUrlController.text = url;
                                      novoLogo = url;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Buscar equipe ou localidade',
                                  prefixIcon: const Icon(Icons.search),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onChanged: (v) {
                                  setState(() => _filtroBusca = v);
                                  _fetchEquipes();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Buscar equipe ou localidade',
                                    prefixIcon: const Icon(Icons.search),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  onChanged: (v) {
                                    setState(() => _filtroBusca = v);
                                    _fetchEquipes();
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              DropdownButton<String>(
                                value: _filtroSituacao,
                                items: [
                                  DropdownMenuItem(
                                    value: 'ativo',
                                    child: Row(
                                      children: const [
                                        Text('Ativos', style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 18, fontWeight: FontWeight.bold)),
                                        SizedBox(width: 4),
                                        Icon(Icons.filter_list, color: Colors.white, size: 20),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'removido',
                                    child: Text('Removidos', style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 18)),
                                  ),
                                  const DropdownMenuItem(
                                    value: 'todos',
                                    child: Text('Todos', style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 18)),
                                  ),
                                ],
                                onChanged: (v) {
                                  setState(() => _filtroSituacao = v!);
                                  _fetchEquipes();
                                },
                                style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.bold),
                                dropdownColor: Color(0xFF333333),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        equipesFiltradas.isEmpty
                            ? const Text('Nenhuma equipe disponível para vincular.')
                            : DropdownButtonFormField<String>(
                                decoration: const InputDecoration(labelText: 'Selecione a equipe'),
                                items: equipesFiltradas
                                    .map((e) => DropdownMenuItem<String>(
                                          value: e['id'],
                                          child: Text(e['name'] ?? ''),
                                        ))
                                    .toList(),
                                onChanged: (v) => setStateDialog(() => equipeSelecionada = v),
                              ),
                      ],
                    ),
              actions: [
                if (!cadastrando)
                  TextButton(
                    onPressed: () => setStateDialog(() => cadastrando = true),
                    child: const Text('Cadastrar nova equipe'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: cadastrando
                      ? () async {
                          if (novoNome.trim().isEmpty) return;
                          final res = await Supabase.instance.client.from('quiz_teams').insert({
                            'name': novoNome,
                            'location': novoLocal,
                            'logo_url': novoLogo,
                            'situacao': 'ativo',
                            'championship_id': _selectedChampionshipId,
                          }).select().single();
                          await _fetchTodasEquipes();
                          setStateDialog(() {
                            cadastrando = false;
                            novoNome = '';
                            novoLocal = '';
                            novoLogo = '';
                            equipeSelecionada = res['id'];
                            _logoUrlController.clear();
                            equipesDisponiveis = _todasEquipes.where((e) => (e['championship_id'] == null || e['championship_id'] == '' || e['id'] == equipeSelecionada)).toList();
                          });
                        }
                      : (equipesFiltradas.isEmpty || equipeSelecionada == null)
                          ? null
                          : () async {
                              try {
                                await Supabase.instance.client
                                    .from('quiz_teams')
                                    .update({'championship_id': _selectedChampionshipId})
                                    .eq('id', equipeSelecionada!);
                                Navigator.of(context).pop();
                                await _fetchEquipes();
                                await _fetchTodasEquipes();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Equipe vinculada ao campeonato com sucesso!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      backgroundColor: Color(0xFF2D2EFF),
                                      behavior: SnackBarBehavior.floating,
                                      margin: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              } catch (e) {
                                Navigator.of(context).pop();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Erro ao vincular equipe: $e', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              }
                            },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D2EFF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(cadastrando ? 'Salvar' : 'Vincular', style: const TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _abrirHistoricoCampeonato() async {
    if (_selectedChampionshipId == null) {
      print('Nenhum campeonato selecionado para histórico!');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecione um campeonato antes de acessar esta funcionalidade.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    setState(() => _loading = true);
    final confrontos = await Supabase.instance.client
        .from('quiz_matches')
        .select('id, team1_id, team2_id, situacao, phase, status')
        .eq('championship_id', _selectedChampionshipId!);
    final resultados = await Supabase.instance.client
        .from('quiz_match_results')
        .select('match_id, team1_score, team2_score, winner_team_id, situacao');
    final equipes = await Supabase.instance.client
        .from('quiz_teams')
        .select('id, name')
        .eq('championship_id', _selectedChampionshipId!);
    setState(() => _loading = false);

    // Mapeia id para nome
    final Map<String, String> equipeNomes = {for (var e in equipes) e['id']: e['name']};

    String? filtroEquipeId;
    String filtroSituacao = 'todos';

    showDialog(
      context: context,
      builder: (context) {
        List<Map<String, dynamic>> confrontosFiltrados = confrontos.where((c) {
          final bool equipeMatch = filtroEquipeId == null || c['team1_id'] == filtroEquipeId || c['team2_id'] == filtroEquipeId;
          final bool situacaoMatch = filtroSituacao == 'todos' || c['situacao'] == filtroSituacao;
          return equipeMatch && situacaoMatch;
        }).toList();
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Histórico de Confrontos e Resultados'),
            content: SizedBox(
              width: 400,
              height: 500,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<String>(
                          value: filtroEquipeId,
                          hint: const Text('Filtrar por equipe'),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('Todas as equipes')),
                            ...equipes.map((e) => DropdownMenuItem<String>(value: e['id'], child: Text(e['name']))),
                          ],
                          onChanged: (v) => setStateDialog(() => filtroEquipeId = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: filtroSituacao,
                        items: const [
                          DropdownMenuItem(value: 'ativo', child: Text('Ativos', style: TextStyle(color: Colors.black, fontSize: 18))),
                          DropdownMenuItem(value: 'removido', child: Text('Removidos', style: TextStyle(color: Colors.black, fontSize: 18))),
                          DropdownMenuItem(value: 'todos', child: Text('Todos', style: TextStyle(color: Colors.black, fontSize: 18))),
                        ],
                        onChanged: (v) => setStateDialog(() => filtroSituacao = v!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: confrontosFiltrados.isEmpty
                        ? const Center(child: Text('Nenhum confronto encontrado.'))
                        : ListView(
                            children: confrontosFiltrados.map<Widget>((c) {
                              final res = resultados.firstWhere(
                                (r) => r['match_id'] == c['id'],
                                orElse: () => <String, dynamic>{},
                              );
                              final team1 = equipeNomes[c['team1_id']] ?? 'Equipe 1';
                              final team2 = equipeNomes[c['team2_id']] ?? 'Equipe 2';
                              final placar = res.isNotEmpty ? '${res['team1_score']} x ${res['team2_score']}' : 'Sem resultado';
                              return Card(
                                color: c['situacao'] == 'removido' ? Colors.red[50] : Colors.white,
                                child: ListTile(
                                  title: Text('$team1 vs $team2', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('Placar: $placar\nSituação: ${c['situacao']} | Fase: ${c['phase']} | Status: ${c['status']}'),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fechar'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _abrirRelatorios() async {
    if (_selectedChampionshipId == null) {
      print('Nenhum campeonato selecionado para relatório!');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecione um campeonato antes de acessar esta funcionalidade.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    setState(() => _loading = true);
    final equipes = await Supabase.instance.client
        .from('quiz_teams')
        .select('id, name, situacao')
        .eq('championship_id', _selectedChampionshipId!);
    final confrontos = await Supabase.instance.client
        .from('quiz_matches')
        .select('id, team1_id, team2_id, situacao, status')
        .eq('championship_id', _selectedChampionshipId!);
    final resultados = await Supabase.instance.client
        .from('quiz_match_results')
        .select('match_id, team1_score, team2_score, winner_team_id');
    setState(() => _loading = false);
    final totalAtivas = equipes.where((e) => e['situacao'] == 'ativo').length;
    final totalRemovidas = equipes.where((e) => e['situacao'] == 'removido').length;
    final totalConfrontos = confrontos.length;
    final totalFinalizados = confrontos.where((c) => c['status'] == 'finalizado').length;

    // Gráfico de barras: vitórias por equipe
    final Map<String, int> vitoriasPorEquipe = {};
    for (final e in equipes) {
      vitoriasPorEquipe[e['name']] = 0;
    }
    for (final r in resultados) {
      final winnerId = r['winner_team_id'];
      if (winnerId != null) {
        final equipe = equipes.firstWhere((e) => e['id'] == winnerId, orElse: () => <String, dynamic>{});
        if (equipe.isNotEmpty) {
          vitoriasPorEquipe[equipe['name']] = (vitoriasPorEquipe[equipe['name']] ?? 0) + 1;
        }
      }
    }
    final List<BarChartGroupData> barGroups = [];
    int idx = 0;
    vitoriasPorEquipe.forEach((nome, vitorias) {
      barGroups.add(BarChartGroupData(x: idx, barRods: [BarChartRodData(toY: vitorias.toDouble(), color: const Color(0xFF2D2EFF))], showingTooltipIndicators: [0]));
      idx++;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Relatórios do Campeonato'),
        content: SizedBox(
          width: 400,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Equipes Ativas: $totalAtivas'),
              Text('Equipes Removidas: $totalRemovidas'),
              Text('Total de Confrontos: $totalConfrontos'),
              Text('Confrontos Finalizados: $totalFinalizados'),
              const SizedBox(height: 16),
              const Text('Distribuição de Equipes:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(
                height: 100,
                child: PieChart(
                  PieChartData(
                    sections: [
                      PieChartSectionData(value: totalAtivas.toDouble(), color: const Color(0xFF2D2EFF), title: 'Ativas'),
                      PieChartSectionData(value: totalRemovidas.toDouble(), color: const Color(0xFFE94057), title: 'Removidas'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Vitórias por Equipe:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(
                height: 120,
                child: BarChart(
                  BarChartData(
                    barGroups: barGroups,
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= vitoriasPorEquipe.keys.length) return const SizedBox();
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(vitoriasPorEquipe.keys.elementAt(idx), style: const TextStyle(fontSize: 10)),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Equipes'),
        backgroundColor: const Color(0xFF2D2EFF),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Colors.white),
            tooltip: 'Ver Relatórios',
            onPressed: _selectedChampionshipId == null ? null : _abrirRelatorios,
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: 'Ver Histórico',
            onPressed: _selectedChampionshipId == null ? null : _abrirHistoricoCampeonato,
          ),
        ],
      ),
      body: Container(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Selecione o Campeonato',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                value: _selectedChampionshipId,
                items: _campeonatos
                    .map<DropdownMenuItem<String>>((c) => DropdownMenuItem<String>(
                          value: c['id'] as String,
                          child: Text(c['title'] ?? ''),
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedChampionshipId = v;
                  });
                  if (v != null) _fetchEquipes();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: _loading || _selectedChampionshipId == null ? null : _abrirModalVincularEquipe,
                icon: const Icon(Icons.group_add, color: Colors.white),
                label: const Text('Vincular Equipe', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D2EFF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar equipe ou localidade',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onChanged: (v) {
                        setState(() => _filtroBusca = v);
                        _fetchEquipes();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _filtroSituacao,
                    items: [
                      DropdownMenuItem(
                        value: 'ativo',
                        child: Row(
                          children: const [
                            Text('Ativos', style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 18, fontWeight: FontWeight.bold)),
                            SizedBox(width: 4),
                            Icon(Icons.filter_list, color: Colors.white, size: 20),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'removido',
                        child: Text('Removidos', style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 18)),
                      ),
                      const DropdownMenuItem(
                        value: 'todos',
                        child: Text('Todos', style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 18)),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _filtroSituacao = v!);
                      _fetchEquipes();
                    },
                    style: const TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.bold),
                    dropdownColor: Color(0xFF333333),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedChampionshipId == null
                      ? const Center(child: Text('Selecione um campeonato para listar as equipes.', style: TextStyle(color: Colors.white, fontSize: 18)))
                      : _equipes.isEmpty
                          ? const Center(child: Text('Nenhuma equipe encontrada com os filtros atuais.', style: TextStyle(color: Colors.white, fontSize: 18)))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _equipes.length,
                              itemBuilder: (context, i) {
                                final equipe = _equipes[i];
                                return Card(
                                  color: Colors.white.withOpacity(0.95),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  margin: const EdgeInsets.symmetric(vertical: 10),
                                  elevation: 6,
                                  child: ListTile(
                                    leading: equipe['logo_url'] != null && equipe['logo_url'].toString().isNotEmpty
                                        ? CircleAvatar(backgroundImage: NetworkImage(equipe['logo_url']), radius: 26)
                                        : const CircleAvatar(child: Icon(Icons.flag), radius: 26),
                                    title: Text(equipe['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                    subtitle: Text(equipe['location'] ?? '', style: const TextStyle(fontSize: 15)),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 28),
                                      tooltip: 'Desvincular equipe',
                                      onPressed: _loading ? null : () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Desvincular Equipe'),
                                            content: const Text('Tem certeza que deseja desvincular esta equipe do campeonato?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(context).pop(false),
                                                child: const Text('Cancelar'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.of(context).pop(true),
                                                child: const Text('Desvincular', style: TextStyle(color: Colors.red)),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          _removerEquipeDoCampeonato(equipe['id'], _selectedChampionshipId!);
                                        }
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
} 