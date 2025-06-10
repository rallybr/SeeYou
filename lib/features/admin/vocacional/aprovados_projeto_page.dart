import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:seeyou/widgets/modern_background.dart';

class AprovadosProjetoPage extends StatefulWidget {
  const AprovadosProjetoPage({Key? key}) : super(key: key);

  @override
  State<AprovadosProjetoPage> createState() => _AprovadosProjetoPageState();
}

class _AprovadosProjetoPageState extends State<AprovadosProjetoPage> {
  bool loading = true;
  List<Map<String, dynamic>> aprovados = [];

  @override
  void initState() {
    super.initState();
    _fetchAprovados();
  }

  Future<void> _fetchAprovados() async {
    setState(() => loading = true);
    final data = await Supabase.instance.client
        .from('vocational_requests')
        .select('id, project_id, user_id, profiles(id, full_name, avatar_url, whatsapp), vocational_projects(id, nome)')
        .eq('status', 'aprovado')
        .order('created_at', ascending: false);
    setState(() {
      aprovados = List<Map<String, dynamic>>.from(data);
      loading = false;
    });
  }

  Future<void> _excluirAprovado(String id) async {
    await Supabase.instance.client
        .from('vocational_requests')
        .delete()
        .eq('id', id);
    _fetchAprovados();
  }

  void _abrirWhatsapp(String? numero) {
    if (numero == null || numero.isEmpty) return;
    final url = 'https://wa.me/$numero';
    // Use url_launcher para abrir o WhatsApp se desejar
  }

  @override
  Widget build(BuildContext context) {
    return ModernBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Aprovados por Projeto'),
          backgroundColor: const Color(0xFF7B2FF2),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : aprovados.isEmpty
                ? const Center(child: Text('Nenhum aprovado encontrado.'))
                : ListView.builder(
                    itemCount: aprovados.length,
                    itemBuilder: (context, index) {
                      final s = aprovados[index];
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
                                icon: const Icon(Icons.chat, color: Colors.teal),
                                tooltip: 'WhatsApp',
                                onPressed: () => _abrirWhatsapp(user['whatsapp']),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Excluir',
                                onPressed: () => _excluirAprovado(s['id']),
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