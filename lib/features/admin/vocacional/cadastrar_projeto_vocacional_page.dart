import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../data/remote/vocational_project_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class CadastrarProjetoVocacionalPage extends StatefulWidget {
  const CadastrarProjetoVocacionalPage({Key? key}) : super(key: key);

  @override
  State<CadastrarProjetoVocacionalPage> createState() => _CadastrarProjetoVocacionalPageState();
}

class _CadastrarProjetoVocacionalPageState extends State<CadastrarProjetoVocacionalPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _logoController = TextEditingController();
  bool _salvando = false;
  File? _imagemSelecionada;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  void _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      // TODO: Substituir pelo ID do usuário logado
      final responsavelId = Supabase.instance.client.auth.currentUser?.id ?? '';
      await VocationalProjectService().addProject(
        nome: _nomeController.text.trim(),
        descricao: _descricaoController.text.trim(),
        logoUrl: _logoController.text.trim(),
        responsavelId: responsavelId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Projeto cadastrado com sucesso!')),
        );
        _formKey.currentState?.reset();
        _nomeController.clear();
        _descricaoController.clear();
        _logoController.clear();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao cadastrar projeto: $e')),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _selecionarImagem() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imagemSelecionada = File(picked.path));
      await _uploadImagem();
    }
  }

  Future<void> _tirarFoto() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() => _imagemSelecionada = File(picked.path));
      await _uploadImagem();
    }
  }

  Future<void> _uploadImagem() async {
    if (_imagemSelecionada == null) return;
    final fileName = 'logo_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storage = Supabase.instance.client.storage.from('logos');
    final res = await storage.upload(fileName, _imagemSelecionada!);
    final url = storage.getPublicUrl(fileName);
    setState(() => _logoController.text = url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Cadastrar Projeto', style: TextStyle(color: Color(0xFF7B2FF2), fontWeight: FontWeight.bold)),
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
                                  Icon(Icons.group_work, color: Color(0xFF7B2FF2), size: 32),
                                  SizedBox(height: 8),
                                  Text('Cadastrar Projeto', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF7B2FF2))),
                                ],
                              );
                            }
                            return Row(
                              children: const [
                                Icon(Icons.group_work, color: Color(0xFF7B2FF2), size: 32),
                                SizedBox(width: 12),
                                Text('Cadastrar Projeto', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF7B2FF2))),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _nomeController,
                          decoration: InputDecoration(
                            labelText: 'Nome do Projeto',
                            prefixIcon: const Icon(Icons.title, color: Color(0xFF7B2FF2)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'Informe o nome' : null,
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
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _logoController,
                          decoration: InputDecoration(
                            labelText: 'URL da Logo',
                            prefixIcon: const Icon(Icons.image, color: Color(0xFF7B2FF2)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            filled: true,
                            fillColor: Colors.white,
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.upload_file, color: Color(0xFF2D2EFF)),
                                  tooltip: 'Enviar imagem',
                                  onPressed: _selecionarImagem,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.camera_alt, color: Color(0xFF2D2EFF)),
                                  tooltip: 'Tirar foto',
                                  onPressed: _tirarFoto,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        ElevatedButton.icon(
                          onPressed: _salvando ? null : _salvar,
                          icon: const Icon(Icons.save, color: Colors.white),
                          label: _salvando
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Cadastrar Projeto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
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