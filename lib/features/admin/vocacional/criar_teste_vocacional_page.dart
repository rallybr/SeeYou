import 'package:flutter/material.dart';

class CriarTesteVocacionalPage extends StatefulWidget {
  const CriarTesteVocacionalPage({Key? key}) : super(key: key);

  @override
  State<CriarTesteVocacionalPage> createState() => _CriarTesteVocacionalPageState();
}

class _CriarTesteVocacionalPageState extends State<CriarTesteVocacionalPage> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  bool _salvando = false;

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  void _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    // TODO: Salvar no banco
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _salvando = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teste vocacional criado com sucesso!')),
      );
      _formKey.currentState?.reset();
      _tituloController.clear();
      _descricaoController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Criar Teste Vocacional', style: TextStyle(color: Color(0xFF7B2FF2), fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF7B2FF2)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double maxCardWidth = constraints.maxWidth < 480 ? constraints.maxWidth * 0.98 : 420;
          return Container(
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
                  constraints: BoxConstraints(maxWidth: maxCardWidth),
                  padding: EdgeInsets.all(constraints.maxWidth < 480 ? 12 : 24),
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
                        LayoutBuilder(
                          builder: (context, c) {
                            if (c.maxWidth < 320) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Icon(Icons.psychology, color: Color(0xFF7B2FF2), size: 32),
                                  SizedBox(height: 8),
                                  Text('Criar Teste Vocacional', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF7B2FF2))),
                                ],
                              );
                            }
                            return Row(
                              children: const [
                                Icon(Icons.psychology, color: Color(0xFF7B2FF2), size: 32),
                                SizedBox(width: 12),
                                Text('Criar Teste Vocacional', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF7B2FF2))),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _tituloController,
                          decoration: InputDecoration(
                            labelText: 'Título do Teste',
                            prefixIcon: const Icon(Icons.title, color: Color(0xFF7B2FF2)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'Informe o título' : null,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _descricaoController,
                          decoration: InputDecoration(
                            labelText: 'Descrição',
                            prefixIcon: const Icon(Icons.description, color: Color(0xFF7B2FF2)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 28),
                        ElevatedButton.icon(
                          onPressed: _salvando ? null : _salvar,
                          icon: const Icon(Icons.save, color: Colors.white),
                          label: _salvando
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Criar Teste', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D2EFF),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
} 