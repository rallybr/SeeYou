import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GerenciarParticipantesPage extends StatefulWidget {
  const GerenciarParticipantesPage({Key? key}) : super(key: key);

  @override
  State<GerenciarParticipantesPage> createState() => _GerenciarParticipantesPageState();
}

class _GerenciarParticipantesPageState extends State<GerenciarParticipantesPage> {
  String? equipeSelecionada;
  List<Map<String, dynamic>> equipes = [];
  List<Map<String, dynamic>> membrosAprovados = [];
  List<Map<String, dynamic>> solicitacoesPendentes = [];
  bool loadingEquipes = true;
  bool loadingMembros = false;
  TextEditingController _buscaController = TextEditingController();
  List<Map<String, dynamic>> sugestoesUsuarios = [];
  bool buscandoUsuarios = false;

  @override
  void initState() {
    super.initState();
    _fetchEquipes();
  }

  Future<void> _fetchEquipes() async {
    setState(() => loadingEquipes = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      print('Usuário não logado');
      return;
    }
    // Buscar nível do usuário
    final profile = await Supabase.instance.client
        .from('profiles')
        .select('nivel')
        .eq('id', user.id)
        .maybeSingle();
    final nivel = profile?['nivel'] ?? 'usuario';
    print('Nível do usuário: $nivel');
    if (nivel == 'admin') {
      // Admin vê todas as equipes
      final equipesData = await Supabase.instance.client
          .from('quiz_teams')
          .select('id, name');
      print('Equipes carregadas (admin): $equipesData');
      setState(() {
        equipes = List<Map<String, dynamic>>.from(equipesData);
        loadingEquipes = false;
      });
      return;
    }
    final equipeIds = await _getEquipesDoUsuario(user.id);
    print('Equipe IDs do usuário: $equipeIds');
    final equipesData = await Supabase.instance.client
        .from('quiz_teams')
        .select('id, name')
        .inFilter('id', equipeIds);
    print('Equipes carregadas: $equipesData');
    setState(() {
      equipes = List<Map<String, dynamic>>.from(equipesData);
      loadingEquipes = false;
    });
  }

  Future<List<String>> _getEquipesDoUsuario(String userId) async {
    final membros = await Supabase.instance.client
        .from('quiz_team_members')
        .select('team_id')
        .eq('user_id', userId)
        .eq('status', 'aprovado');
    return membros.map<String>((m) => m['team_id'] as String).toList();
  }

  Future<void> _fetchMembros(String equipeId) async {
    setState(() {
      loadingMembros = true;
      membrosAprovados = [];
      solicitacoesPendentes = [];
    });
    final membros = await Supabase.instance.client
        .from('quiz_team_members')
        .select('user_id, status, profiles(username, full_name)')
        .eq('team_id', equipeId);
    setState(() {
      membrosAprovados = membros.where((m) => m['status'] == 'aprovado').toList();
      solicitacoesPendentes = membros.where((m) => m['status'] == 'pendente').toList();
      loadingMembros = false;
    });
  }

  Future<void> _aprovarSolicitacao(String equipeId, String userId) async {
    final res = await Supabase.instance.client
        .from('quiz_team_members')
        .update({'status': 'aprovado'})
        .eq('team_id', equipeId)
        .eq('user_id', userId);
    print('Resultado update: $res');
    await Future.delayed(const Duration(milliseconds: 300));
    _fetchMembros(equipeId);
  }

  Future<void> _rejeitarSolicitacao(String equipeId, String userId) async {
    await Supabase.instance.client
        .from('quiz_team_members')
        .update({'status': 'rejeitado'})
        .eq('team_id', equipeId)
        .eq('user_id', userId);
    _fetchMembros(equipeId);
  }

  Future<void> _removerUsuarioEquipe(String equipeId, String userId) async {
    await Supabase.instance.client
        .from('quiz_team_members')
        .delete()
        .eq('team_id', equipeId)
        .eq('user_id', userId);
    _fetchMembros(equipeId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Usuário desassociado da equipe!')),
    );
  }

  void _onBuscaChanged(String value) async {
    if (value.length < 2) {
      setState(() => sugestoesUsuarios = []);
      return;
    }
    setState(() => buscandoUsuarios = true);
    final results = await Supabase.instance.client
        .from('profiles')
        .select('id, username, full_name')
        .ilike('username', '%$value%');
    setState(() {
      sugestoesUsuarios = List<Map<String, dynamic>>.from(results);
      buscandoUsuarios = false;
    });
  }

  Future<void> _adicionarUsuarioEquipe(String userId) async {
    if (equipeSelecionada == null) return;
    await Supabase.instance.client
        .from('quiz_team_members')
        .insert({
          'team_id': equipeSelecionada,
          'user_id': userId,
          'status': 'aprovado',
        });
    _fetchMembros(equipeSelecionada!);
    setState(() {
      sugestoesUsuarios = [];
      _buscaController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Usuário adicionado à equipe!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Participantes'),
        backgroundColor: const Color(0xFF2D2EFF),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: loadingEquipes
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      const Text('Selecione uma equipe:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: DropdownButton<String>(
                          value: equipeSelecionada,
                          hint: const Text('Escolha a equipe'),
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: equipes.map((e) => DropdownMenuItem<String>(value: e['id'] as String, child: Text(e['name'] as String))).toList(),
                          onChanged: (value) {
                            setState(() {
                              equipeSelecionada = value;
                            });
                            if (value != null) _fetchMembros(value);
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('Membros aprovados:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 8),
                      if (loadingMembros)
                        const Center(child: CircularProgressIndicator())
                      else if (membrosAprovados.isEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: const Text('Nenhum membro aprovado.', style: TextStyle(color: Colors.white70)),
                        )
                      else ...membrosAprovados.map((m) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListTile(
                              leading: const Icon(Icons.person, color: Colors.green),
                              title: Text(m['profiles']['username'] ?? 'Usuário', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(m['profiles']['full_name'] ?? ''),
                              trailing: IconButton(
                                icon: const Icon(Icons.person_remove, color: Colors.red),
                                tooltip: 'Desassociar usuário',
                                onPressed: () => _removerUsuarioEquipe(equipeSelecionada!, m['user_id']),
                              ),
                            ),
                          )),
                      const SizedBox(height: 24),
                      const Text('Solicitações pendentes:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 8),
                      ...solicitacoesPendentes.map((s) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListTile(
                              leading: const Icon(Icons.hourglass_empty, color: Colors.orange),
                              title: Text(s['profiles']['username'] ?? 'Usuário', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(s['profiles']['full_name'] ?? ''),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _aprovarSolicitacao(equipeSelecionada!, s['user_id'])),
                                  IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _rejeitarSolicitacao(equipeSelecionada!, s['user_id'])),
                                ],
                              ),
                            ),
                          )),
                      const SizedBox(height: 24),
                      const Text('Adicionar usuário à equipe:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _buscaController,
                                decoration: const InputDecoration(
                                  hintText: 'Buscar usuário...',
                                  border: InputBorder.none,
                                ),
                                onChanged: _onBuscaChanged,
                              ),
                            ),
                            if (buscandoUsuarios)
                              const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                          ],
                        ),
                      ),
                      if (sugestoesUsuarios.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: sugestoesUsuarios.length,
                            itemBuilder: (context, i) {
                              final u = sugestoesUsuarios[i];
                              return ListTile(
                                leading: const Icon(Icons.person),
                                title: Text(u['username'] ?? ''),
                                subtitle: Text(u['full_name'] ?? ''),
                                onTap: () => _adicionarUsuarioEquipe(u['id']),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
} 