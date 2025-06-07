import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DesafiarUsuarioPage extends StatefulWidget {
  const DesafiarUsuarioPage({super.key});

  @override
  State<DesafiarUsuarioPage> createState() => _DesafiarUsuarioPageState();
}

class _DesafiarUsuarioPageState extends State<DesafiarUsuarioPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _error;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _supabase
          .from('profiles')
          .select()
          .neq('id', userId.toString())
          .order('username')
          .limit(50);

      setState(() {
        _users = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar usuários: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _desafiarUsuario(String targetUserId, String targetUsername) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Verifica se já existe um desafio pendente
      final existingDuel = await _supabase
          .from('quiz_duels')
          .select()
          .or('challenger_id.eq.$userId,target_id.eq.$userId')
          .eq('status', 'pendente')
          .maybeSingle();

      if (existingDuel != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Você já tem um desafio pendente!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Cria o desafio
      final response = await _supabase.from('quiz_duels').insert({
        'challenger_id': userId,
        'target_id': targetUserId,
        'status': 'pendente',
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Desafio enviado para @$targetUsername!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navega de volta
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao enviar desafio: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    return _users.where((user) {
      final username = user['username']?.toString().toLowerCase() ?? '';
      final fullName = user['full_name']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return username.contains(query) || fullName.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Desafiar Usuário'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar usuário',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _filteredUsers.isEmpty
                        ? const Center(child: Text('Nenhum usuário encontrado'))
                        : ListView.builder(
                            itemCount: _filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = _filteredUsers[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: user['avatar_url'] != null
                                      ? NetworkImage(user['avatar_url'])
                                      : null,
                                  child: user['avatar_url'] == null
                                      ? Text(user['username'][0].toUpperCase())
                                      : null,
                                ),
                                title: Text(user['username']),
                                subtitle: user['full_name'] != null
                                    ? Text(user['full_name'])
                                    : null,
                                trailing: ElevatedButton(
                                  onPressed: () => _desafiarUsuario(
                                    user['id'],
                                    user['username'],
                                  ),
                                  child: const Text('Desafiar'),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
} 