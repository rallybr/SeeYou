import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CriarCampeonatoForm extends StatefulWidget {
  const CriarCampeonatoForm({Key? key}) : super(key: key);

  @override
  State<CriarCampeonatoForm> createState() => _CriarCampeonatoFormState();
}

class _CriarCampeonatoFormState extends State<CriarCampeonatoForm> {
  final _formKey = GlobalKey<FormState>();
  String? _titulo;
  int? _numEquipes;
  String? _quizId;
  bool _loading = false;
  bool _saving = false;
  List<Map<String, dynamic>> _quizzes = [];

  final List<int> _opcoesEquipes = [4, 8, 12, 16, 32];

  @override
  void initState() {
    super.initState();
    _fetchQuizzes();
  }

  Future<void> _fetchQuizzes() async {
    setState(() => _loading = true);
    final quizzes = await Supabase.instance.client
        .from('quizzes')
        .select('id, title')
        .eq('aprovado', true)
        .order('created_at', ascending: false);
    setState(() {
      _quizzes = List<Map<String, dynamic>>.from(quizzes);
      _loading = false;
    });
  }

  int _calcularNumGrupos(int numEquipes) {
    switch (numEquipes) {
      case 4:
        return 1;
      case 8:
        return 2;
      case 12:
        return 3;
      case 16:
        return 4;
      case 32:
        return 8;
      default:
        return 1;
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _saving = true);
    final numGrupos = _calcularNumGrupos(_numEquipes!);
    await Supabase.instance.client.from('quiz_championships').insert({
      'title': _titulo,
      'num_teams': _numEquipes,
      'num_groups': numGrupos,
      'created_by': Supabase.instance.client.auth.currentUser?.id,
      'quiz_id': _quizId,
    });
    setState(() => _saving = false);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Campeonato criado com sucesso!')),
      );
      _formKey.currentState?.reset();
      setState(() {
        _titulo = null;
        _numEquipes = null;
        _quizId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: const [
                  Icon(Icons.emoji_events, color: Color(0xFF2D2EFF), size: 32),
                  SizedBox(width: 12),
                  Text('Criar Campeonato', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D2EFF))),
                ],
              ),
              const SizedBox(height: 28),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Nome do Campeonato',
                  prefixIcon: const Icon(Icons.title, color: Color(0xFF7B2FF2)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
                onSaved: (v) => _titulo = v,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<int>(
                decoration: InputDecoration(
                  labelText: 'Quantidade de Equipes',
                  prefixIcon: const Icon(Icons.groups, color: Color(0xFFE94057)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                value: _numEquipes,
                items: _opcoesEquipes
                    .map<DropdownMenuItem<int>>((n) => DropdownMenuItem<int>(
                          value: n,
                          child: Text('$n Equipes (${_calcularNumGrupos(n)} grupo(s))'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _numEquipes = v),
                validator: (v) => v == null ? 'Selecione a quantidade de equipes' : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Quiz Base',
                  prefixIcon: const Icon(Icons.quiz, color: Color(0xFF2D2EFF)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                value: _quizId,
                items: _quizzes
                    .map<DropdownMenuItem<String>>((quiz) => DropdownMenuItem<String>(
                          value: quiz['id'] as String,
                          child: Text(quiz['title']),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _quizId = v),
                validator: (v) => v == null ? 'Selecione o quiz base' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D2EFF),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                ),
                icon: _saving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save, color: Colors.white),
                label: const Text('Criar Campeonato', style: TextStyle(color: Colors.white)),
                onPressed: _saving ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 