import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LimparDuplicadosPage extends StatefulWidget {
  const LimparDuplicadosPage({Key? key}) : super(key: key);

  @override
  State<LimparDuplicadosPage> createState() => _LimparDuplicadosPageState();
}

class _LimparDuplicadosPageState extends State<LimparDuplicadosPage> {
  String? _selectedType;
  List<Map<String, dynamic>> _duplicates = [];
  bool _loading = false;

  final List<String> _types = [
    'Grupos Duplicados',
    'Confrontos Duplicados',
    // Adicione outros tipos conforme necessário
  ];

  Future<void> _fetchDuplicates() async {
    if (_selectedType == null) return;
    setState(() {
      _loading = true;
    });
    // Aqui você deve implementar a lógica para buscar os duplicados do tipo selecionado
    // Por exemplo, para grupos duplicados:
    if (_selectedType == 'Grupos Duplicados') {
      final data = await Supabase.instance.client
          .from('quiz_groups')
          .select('id, name, championship_id')
          .order('championship_id');
      // Lógica para identificar duplicados (exemplo: mesmo nome e championship_id)
      final Map<String, List<Map<String, dynamic>>> groups = {};
      for (var group in data) {
        final key = '${group['name']}_${group['championship_id']}';
        if (!groups.containsKey(key)) {
          groups[key] = [];
        }
        groups[key]!.add(group);
      }
      _duplicates = groups.values.where((list) => list.length > 1).expand((list) => list).toList();
    } else if (_selectedType == 'Confrontos Duplicados') {
      // Implementar lógica para confrontos duplicados
      // Exemplo: buscar confrontos com mesmo grupo_id, team1_id e team2_id
      final data = await Supabase.instance.client
          .from('quiz_matches')
          .select('id, group_id, team1_id, team2_id')
          .order('group_id');
      final Map<String, List<Map<String, dynamic>>> matches = {};
      for (var match in data) {
        final key = '${match['group_id']}_${match['team1_id']}_${match['team2_id']}';
        if (!matches.containsKey(key)) {
          matches[key] = [];
        }
        matches[key]!.add(match);
      }
      _duplicates = matches.values.where((list) => list.length > 1).expand((list) => list).toList();
    }
    setState(() {
      _loading = false;
    });
  }

  Future<void> _deleteGroup(Map<String, dynamic> group) async {
    setState(() {
      _loading = true;
    });
    try {
      // Agora basta deletar o grupo, o banco cuidará do resto (ON DELETE CASCADE)
      await Supabase.instance.client
          .from('quiz_groups')
          .delete()
          .eq('id', group['id']);

      setState(() {
        _duplicates.removeWhere((g) => g['id'] == group['id']);
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Grupo excluído com sucesso!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF2D2EFF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir grupo: \\${e.toString()}')),
      );
    }
  }

  Future<void> _deleteDuplicates() async {
    if (_duplicates.isEmpty) return;
    setState(() {
      _loading = true;
    });
    try {
      if (_selectedType == 'Grupos Duplicados') {
        for (var group in _duplicates) {
          await Supabase.instance.client
              .from('quiz_groups')
              .delete()
              .eq('id', group['id']);
        }
      } else if (_selectedType == 'Confrontos Duplicados') {
        for (var match in _duplicates) {
          await Supabase.instance.client
              .from('quiz_matches')
              .delete()
              .eq('id', match['id']);
        }
      }
      setState(() {
        _duplicates = [];
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Duplicados excluídos com sucesso!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF2D2EFF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir duplicados: \\${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Limpar Duplicados'),
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Selecione o tipo de duplicados',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                value: _selectedType,
                items: _types
                    .map<DropdownMenuItem<String>>((type) => DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedType = value;
                    _duplicates = [];
                  });
                  if (value != null) {
                    _fetchDuplicates();
                  }
                },
              ),
              const SizedBox(height: 20),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_duplicates.isNotEmpty) ...[
                Expanded(
                  child: ListView.builder(
                    itemCount: _duplicates.length,
                    itemBuilder: (context, index) {
                      final item = _duplicates[index];
                      return ListTile(
                        title: Text(item['name'] ?? 'Confronto \\${item['id']}'),
                        subtitle: Text('ID: \\${item['id']}'),
                        trailing: _selectedType == 'Grupos Duplicados'
                            ? IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                tooltip: 'Excluir este grupo',
                                onPressed: _loading
                                    ? null
                                    : () => _deleteGroup(item),
                              )
                            : null,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 8,
                  ),
                  icon: const Icon(Icons.delete, color: Colors.white),
                  label: const Text('Excluir Duplicados', style: TextStyle(color: Colors.white)),
                  onPressed: _deleteDuplicates,
                ),
              ] else if (_selectedType != null)
                const Center(child: Text('Nenhum duplicado encontrado.')),
            ],
          ),
        ),
      ),
    );
  }
} 