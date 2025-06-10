import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:seeyou/widgets/modern_background.dart';

class GerenciarSolicitacoesVocacionaisPage extends StatefulWidget {
  const GerenciarSolicitacoesVocacionaisPage({Key? key}) : super(key: key);

  @override
  State<GerenciarSolicitacoesVocacionaisPage> createState() => _GerenciarSolicitacoesVocacionaisPageState();
}

class _GerenciarSolicitacoesVocacionaisPageState extends State<GerenciarSolicitacoesVocacionaisPage> {
  bool loading = true;
  List<Map<String, dynamic>> solicitacoes = [];

  @override
  void initState() {
    super.initState();
    _fetchSolicitacoes();
  }

  Future<void> _fetchSolicitacoes() async {
    setState(() => loading = true);
    final data = await Supabase.instance.client
        .from('vocational_requests')
        .select('id, status, created_at, project_id, user_id, profiles(id, full_name, avatar_url, whatsapp), vocational_projects(id, nome)')
        .eq('status', 'pendente')
        .order('created_at', ascending: false);
    setState(() {
      solicitacoes = List<Map<String, dynamic>>.from(data);
      loading = false;
    });
  }

  Future<void> _atualizarStatus(String id, String status) async {
    await Supabase.instance.client
        .from('vocational_requests')
        .update({'status': status})
        .eq('id', id);
    _fetchSolicitacoes();
  }

  void _abrirWhatsapp(String? numero) {
    if (numero == null || numero.isEmpty) return;
    final url = 'https://wa.me/$numero';
    // ignore: deprecated_member_use
    // launch(url); // Use url_launcher se desejar
  }

  @override
  Widget build(BuildContext context) {
    return ModernBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Gerenciar Solicitações Vocacionais'),
          backgroundColor: const Color(0xFF7B2FF2),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : solicitacoes.isEmpty
                ? const Center(child: Text('Nenhuma solicitação pendente.'))
                : ListView.builder(
                    itemCount: solicitacoes.length,
                    itemBuilder: (context, index) {
                      final s = solicitacoes[index];
                      final user = s['profiles'] ?? {};
                      final projeto = s['vocational_projects'] ?? {};
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
                            child: user['avatar_url'] == null ? const Icon(Icons.person) : null,
                          ),
                          title: Text(user['full_name'] ?? 'Usuário', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Projeto: ${projeto['nome'] ?? ''}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check_circle, color: Colors.green),
                                tooltip: 'Aprovar',
                                onPressed: () => _atualizarStatus(s['id'], 'aprovado'),
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.red),
                                tooltip: 'Reprovar',
                                onPressed: () => _atualizarStatus(s['id'], 'reprovado'),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chat, color: Colors.teal),
                                tooltip: 'WhatsApp',
                                onPressed: () => _abrirWhatsapp(user['whatsapp']),
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