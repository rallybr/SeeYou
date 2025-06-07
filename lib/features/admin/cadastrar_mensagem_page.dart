import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CadastrarMensagemPage extends StatefulWidget {
  const CadastrarMensagemPage({Key? key}) : super(key: key);

  @override
  State<CadastrarMensagemPage> createState() => _CadastrarMensagemPageState();
}

class _CadastrarMensagemPageState extends State<CadastrarMensagemPage> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _autorController = TextEditingController();
  final _linkController = TextEditingController();
  String? _categoria;
  bool _publicando = false;

  @override
  void dispose() {
    _tituloController.dispose();
    _autorController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  void _publicar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _publicando = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');
      await Supabase.instance.client.from('mensagens').insert({
        'titulo': _tituloController.text.trim(),
        'categoria': _categoria,
        'autor': _autorController.text.trim(),
        'link': _linkController.text.trim(),
        'user_id': user.id,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mensagem publicada com sucesso!')),
        );
        _formKey.currentState?.reset();
        _tituloController.clear();
        _autorController.clear();
        _linkController.clear();
        setState(() => _categoria = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao publicar: \$e')),
        );
      }
    } finally {
      setState(() => _publicando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Cadastrar Mensagem', style: TextStyle(color: Color(0xFF7B2FF2), fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF7B2FF2)),
          onPressed: () {
            Navigator.of(context).pushReplacementNamed('/admin');
          },
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7B2FF2), Color(0xFFF357A8), Color(0xFFF2A93B)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
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
                        Icon(Icons.chat_bubble_outline, color: Color(0xFF7B2FF2), size: 32),
                        SizedBox(width: 12),
                        Text('Cadastrar Mensagem', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF7B2FF2))),
                      ],
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _tituloController,
                      decoration: InputDecoration(
                        labelText: 'Título',
                        prefixIcon: const Icon(Icons.title, color: Color(0xFF7B2FF2)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Informe o título' : null,
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: _categoria,
                      decoration: InputDecoration(
                        labelText: 'Categoria',
                        prefixIcon: const Icon(Icons.category, color: Color(0xFF7B2FF2)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Reflexão', child: Text('Reflexão')),
                        DropdownMenuItem(value: 'Motivacional', child: Text('Motivacional')),
                        DropdownMenuItem(value: 'Gospel', child: Text('Gospel')),
                        DropdownMenuItem(value: 'Outros', child: Text('Outros')),
                      ],
                      onChanged: (v) => setState(() => _categoria = v),
                      validator: (v) => v == null ? 'Selecione a categoria' : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _autorController,
                      decoration: InputDecoration(
                        labelText: 'Autor',
                        prefixIcon: const Icon(Icons.person, color: Color(0xFF7B2FF2)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Informe o autor' : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _linkController,
                      decoration: InputDecoration(
                        labelText: 'Link (YouTube, áudio, texto, etc)',
                        prefixIcon: const Icon(Icons.link, color: Color(0xFF7B2FF2)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Informe o link ou conteúdo' : null,
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: _publicando ? null : _publicar,
                      icon: const Icon(Icons.publish, color: Colors.white),
                      label: _publicando
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Publicar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D2EFF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 