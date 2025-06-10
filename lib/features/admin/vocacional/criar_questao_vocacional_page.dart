import 'package:flutter/material.dart';
import '../../../../data/remote/vocational_project_service.dart';
import '../../../../data/remote/vocational_question_service.dart';
import 'package:seeyou/widgets/modern_background.dart';

class CriarQuestaoVocacionalPage extends StatefulWidget {
  const CriarQuestaoVocacionalPage({Key? key}) : super(key: key);

  @override
  State<CriarQuestaoVocacionalPage> createState() => _CriarQuestaoVocacionalPageState();
}

class _CriarQuestaoVocacionalPageState extends State<CriarQuestaoVocacionalPage> {
  final _formKey = GlobalKey<FormState>();
  final _perguntaController = TextEditingController();
  final List<TextEditingController> _opcaoControllers = List.generate(5, (_) => TextEditingController());
  final List<String?> _projetoSelecionado = List.filled(5, null);
  bool _salvando = false;

  List<Map<String, dynamic>> _projetos = [];
  bool _carregandoProjetos = true;

  @override
  void initState() {
    super.initState();
    _carregarProjetos();
  }

  Future<void> _carregarProjetos() async {
    setState(() => _carregandoProjetos = true);
    try {
      _projetos = await VocationalProjectService().getProjects();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar projetos: $e')),
      );
    } finally {
      setState(() => _carregandoProjetos = false);
    }
  }

  @override
  void dispose() {
    _perguntaController.dispose();
    for (final c in _opcaoControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      // Ordem pode ser incrementada conforme a lógica do app, aqui exemplo fixo
      final ordem = 1;
      final questionId = await VocationalQuestionService().addQuestion(
        pergunta: _perguntaController.text.trim(),
        ordem: ordem,
      );
      for (int i = 0; i < 5; i++) {
        await VocationalQuestionService().addOption(
          questionId: questionId,
          texto: _opcaoControllers[i].text.trim(),
          projectId: _projetoSelecionado[i] ?? '',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Questão criada com sucesso!')),
        );
        _formKey.currentState?.reset();
        _perguntaController.clear();
        for (final c in _opcaoControllers) {
          c.clear();
        }
        setState(() => _projetoSelecionado.fillRange(0, 5, null));
      }
    } catch (e, stack) {
      print('Erro ao criar questão: $e\n$stack');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao criar questão: $e')),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ModernBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Criar Questão Vocacional'),
          backgroundColor: const Color(0xFF7B2FF2),
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
                                    Icon(Icons.question_answer, color: Color(0xFF7B2FF2), size: 32),
                                    SizedBox(height: 8),
                                    Text('Criar Questão', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF7B2FF2))),
                                  ],
                                );
                              }
                              return Row(
                                children: const [
                                  Icon(Icons.question_answer, color: Color(0xFF7B2FF2), size: 32),
                                  SizedBox(width: 12),
                                  Text('Criar Questão', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF7B2FF2))),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 28),
                          TextFormField(
                            controller: _perguntaController,
                            decoration: InputDecoration(
                              labelText: 'Pergunta',
                              prefixIcon: const Icon(Icons.help_outline, color: Color(0xFF7B2FF2)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Informe a pergunta' : null,
                          ),
                          const SizedBox(height: 20),
                          for (int i = 0; i < 5; i++) ...[
                            LayoutBuilder(
                              builder: (context, constraints) {
                                if (constraints.maxWidth < 400) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      TextFormField(
                                        controller: _opcaoControllers[i],
                                        decoration: InputDecoration(
                                          labelText: 'Opção ${String.fromCharCode(65 + i)}',
                                          prefixIcon: const Icon(Icons.circle, color: Color(0xFF2D2EFF)),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                          filled: true,
                                          fillColor: Colors.white,
                                        ),
                                        validator: (v) => v == null || v.isEmpty ? 'Informe a opção' : null,
                                      ),
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<String>(
                                        value: _projetoSelecionado[i],
                                        decoration: InputDecoration(
                                          labelText: 'Projeto',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                          filled: true,
                                          fillColor: Colors.white,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                        ),
                                        items: _carregandoProjetos
                                          ? [const DropdownMenuItem(value: null, child: Text('Carregando...'))]
                                          : _projetos.map((p) => DropdownMenuItem(
                                              value: p['id'] as String,
                                              child: Text(
                                                p['nome'] ?? '',
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 13),
                                              ),
                                            )).toList(),
                                        onChanged: (v) => setState(() => _projetoSelecionado[i] = v),
                                        validator: (v) => v == null ? 'Selecione' : null,
                                        isExpanded: true,
                                      ),
                                    ],
                                  );
                                }
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _opcaoControllers[i],
                                        decoration: InputDecoration(
                                          labelText: 'Opção ${String.fromCharCode(65 + i)}',
                                          prefixIcon: const Icon(Icons.circle, color: Color(0xFF2D2EFF)),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                          filled: true,
                                          fillColor: Colors.white,
                                        ),
                                        validator: (v) => v == null || v.isEmpty ? 'Informe a opção' : null,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 150,
                                      child: DropdownButtonFormField<String>(
                                        value: _projetoSelecionado[i],
                                        decoration: InputDecoration(
                                          labelText: 'Projeto',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                          filled: true,
                                          fillColor: Colors.white,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                        ),
                                        items: _carregandoProjetos
                                          ? [const DropdownMenuItem(value: null, child: Text('Carregando...'))]
                                          : _projetos.map((p) => DropdownMenuItem(
                                              value: p['id'] as String,
                                              child: Text(
                                                p['nome'] ?? '',
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 13),
                                              ),
                                            )).toList(),
                                        onChanged: (v) => setState(() => _projetoSelecionado[i] = v),
                                        validator: (v) => v == null ? 'Selecione' : null,
                                        isExpanded: true,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _salvando ? null : _salvar,
                            icon: const Icon(Icons.save, color: Colors.white),
                            label: _salvando
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Salvar Questão', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
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
      ),
    );
  }
} 