import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ListaEquipesPage extends StatefulWidget {
  const ListaEquipesPage({Key? key}) : super(key: key);

  @override
  State<ListaEquipesPage> createState() => _ListaEquipesPageState();
}

class _ListaEquipesPageState extends State<ListaEquipesPage> {
  List<Map<String, dynamic>> equipes = [];
  Map<String, String> statusEquipe = {};
  bool loading = true;
  String? userId;

  @override
  void initState() {
    super.initState();
    _fetchEquipes();
  }

  Future<void> _fetchEquipes() async {
    setState(() => loading = true);
    final user = Supabase.instance.client.auth.currentUser;
    userId = user?.id;
    final equipesData = await Supabase.instance.client
        .from('quiz_teams')
        .select('id, name, location');
    List membros = [];
    if (userId != null) {
      membros = await Supabase.instance.client
          .from('quiz_team_members')
          .select('team_id, status')
          .eq('user_id', userId!);
    }
    final status = <String, String>{};
    for (final m in membros) {
      status[m['team_id']] = m['status'];
    }
    setState(() {
      equipes = List<Map<String, dynamic>>.from(equipesData);
      statusEquipe = status;
      loading = false;
    });
  }

  Future<void> _solicitarParticipacao(String equipeId) async {
    if (userId == null) return;
    await Supabase.instance.client
        .from('quiz_team_members')
        .insert({
          'team_id': equipeId,
          'user_id': userId,
          'status': 'pendente',
        });
    _fetchEquipes();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solicitação enviada! Aguarde aprovação.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escolha uma Equipe'),
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
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: equipes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, i) {
                  final equipe = equipes[i];
                  final status = statusEquipe[equipe['id']];
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 6,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.groups, color: Color(0xFF2D2EFF), size: 36),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  equipe['name'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF2D2EFF)),
                                ),
                                if (equipe['location'] != null && equipe['location'].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      equipe['location'],
                                      style: const TextStyle(fontSize: 15, color: Colors.black54),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (status == null)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2D2EFF),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _solicitarParticipacao(equipe['id']),
                              child: const Text('Solicitar', style: TextStyle(color: Colors.white)),
                            )
                          else if (status == 'pendente')
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text('Aguardando aprovação', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                            )
                          else if (status == 'aprovado')
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text('Você já é membro', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            )
                          else if (status == 'rejeitado')
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text('Solicitação rejeitada', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
} 