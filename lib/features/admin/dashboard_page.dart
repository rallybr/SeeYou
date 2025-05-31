import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  int? _selectedQuizSubMenu; // null = não está em submenu

  final List<String> _sections = [
    'Visão Geral',
    'Usuários',
    'Posts',
    'Moderação',
    'Estatísticas',
    'Configurações',
    'Bible Quiz', // Novo menu principal
  ];

  final List<String> _quizSubMenus = [
    'Criar Quiz',
    'Adicionar Questão',
    'Aprovar Quiz',
    'Editar Quiz',
    'Editar Questão',
    'Ranking',
    'Histórico de Participação',
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Administração - Dashboard'),
            backgroundColor: Colors.deepPurple,
          ),
          drawer: isDesktop ? null : _DashboardDrawer(
            selectedIndex: _selectedIndex,
            onSelect: (i) => setState(() {
              _selectedIndex = i;
              _selectedQuizSubMenu = null;
            }),
            sections: _sections,
            selectedQuizSubMenu: _selectedQuizSubMenu,
            onQuizSubMenuSelect: (i) => setState(() {
              _selectedIndex = _sections.length - 1;
              _selectedQuizSubMenu = i;
            }),
            quizSubMenus: _quizSubMenus,
          ),
          body: Container(
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
            child: Row(
              children: [
                if (isDesktop)
                  SizedBox(
                    width: 220,
                    child: _DashboardDrawer(
                      selectedIndex: _selectedIndex,
                      onSelect: (i) => setState(() {
                        _selectedIndex = i;
                        _selectedQuizSubMenu = null;
                      }),
                      sections: _sections,
                      selectedQuizSubMenu: _selectedQuizSubMenu,
                      onQuizSubMenuSelect: (i) => setState(() {
                        _selectedIndex = _sections.length - 1;
                        _selectedQuizSubMenu = i;
                      }),
                      quizSubMenus: _quizSubMenus,
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _selectedIndex == _sections.length - 1
                        ? _BibleQuizSection(index: _selectedQuizSubMenu)
                        : _DashboardSection(index: _selectedIndex),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DashboardDrawer extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onSelect;
  final List<String> sections;
  final int? selectedQuizSubMenu;
  final Function(int)? onQuizSubMenuSelect;
  final List<String>? quizSubMenus;
  const _DashboardDrawer({
    required this.selectedIndex,
    required this.onSelect,
    required this.sections,
    this.selectedQuizSubMenu,
    this.onQuizSubMenuSelect,
    this.quizSubMenus,
  });

  @override
  Widget build(BuildContext context) {
    final icons = [
      Icons.dashboard,
      Icons.people,
      Icons.photo_library,
      Icons.shield,
      Icons.bar_chart,
      Icons.settings,
      Icons.quiz, // Bible Quiz
    ];
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.deepPurple,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.admin_panel_settings, color: Colors.white, size: 40),
                SizedBox(height: 12),
                Text('Painel Admin', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home, color: Colors.deepPurple),
            title: const Text('Home', style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              Navigator.of(context).pushNamedAndRemoveUntil('/feed', (route) => false);
            },
          ),
          const Divider(),
          for (int i = 0; i < sections.length; i++)
            if (sections[i] != 'Bible Quiz')
              ListTile(
                leading: Icon(icons[i], color: selectedIndex == i ? Colors.deepPurple : null),
                title: Text(sections[i], style: TextStyle(fontWeight: selectedIndex == i ? FontWeight.bold : FontWeight.normal)),
                selected: selectedIndex == i,
                onTap: () {
                  onSelect(i);
                  if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                },
              ),
          // Bible Quiz menu com submenus
          ExpansionTile(
            leading: Icon(icons.last, color: selectedIndex == sections.length - 1 ? Colors.deepPurple : null),
            title: Text('Bible Quiz', style: TextStyle(fontWeight: selectedIndex == sections.length - 1 ? FontWeight.bold : FontWeight.normal)),
            initiallyExpanded: selectedIndex == sections.length - 1,
            children: [
              for (int i = 0; i < (quizSubMenus?.length ?? 0); i++)
                ListTile(
                  leading: Icon(Icons.arrow_right, color: selectedQuizSubMenu == i ? Colors.deepPurple : null),
                  title: Text(quizSubMenus![i], style: TextStyle(fontWeight: selectedQuizSubMenu == i ? FontWeight.bold : FontWeight.normal)),
                  selected: selectedQuizSubMenu == i,
                  onTap: () {
                    onQuizSubMenuSelect?.call(i);
                    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardSection extends StatelessWidget {
  final int index;
  const _DashboardSection({required this.index});

  @override
  Widget build(BuildContext context) {
    switch (index) {
      case 0:
        return _DashboardOverview();
      case 1:
        return _DashboardUsers();
      case 2:
        return _DashboardPosts();
      case 3:
        return _DashboardModeration();
      case 4:
        return _DashboardStats();
      case 5:
        return _DashboardSettings();
      default:
        return const SizedBox.shrink();
    }
  }
}

class _DashboardOverview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Visão Geral', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    );
  }
}

class _DashboardUsers extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Gestão de Usuários', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    );
  }
}

class _DashboardPosts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Gestão de Posts', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    );
  }
}

class _DashboardModeration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Moderação', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    );
  }
}

class _DashboardStats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Estatísticas', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    );
  }
}

class _DashboardSettings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Configurações', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
    );
  }
}

class _BibleQuizSection extends StatelessWidget {
  final int? index;
  const _BibleQuizSection({this.index});

  @override
  Widget build(BuildContext context) {
    switch (index) {
      case 0:
        return const CriarQuizForm();
      case 1:
        return const CriarQuestaoForm();
      case 2:
        return const AprovarQuizForm();
      case 3:
        return const EditarQuizForm();
      case 4:
        return const EditarQuestaoForm();
      case 5:
        return const RankingQuizForm();
      case 6:
        return const Center(child: Text('Histórico de Participação'));
      default:
        return const Center(child: Text('Selecione uma opção do menu Bible Quiz'));
    }
  }
}

class CriarQuizForm extends StatefulWidget {
  const CriarQuizForm({Key? key}) : super(key: key);

  @override
  State<CriarQuizForm> createState() => _CriarQuizFormState();
}

class _CriarQuizFormState extends State<CriarQuizForm> {
  final _formKey = GlobalKey<FormState>();
  String? _titulo;
  String? _categoriaId;
  List<Map<String, dynamic>> _categorias = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fetchCategorias();
  }

  Future<void> _fetchCategorias() async {
    final data = await Supabase.instance.client
        .from('quiz_categories')
        .select('id, name');
    setState(() {
      _categorias = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _saving = true);
    await Supabase.instance.client.from('quizzes').insert({
      'title': _titulo,
      'category_id': _categoriaId,
      'created_by': Supabase.instance.client.auth.currentUser?.id,
    });
    setState(() => _saving = false);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quiz criado com sucesso!')),
      );
      // Aqui você pode navegar para a próxima etapa (adicionar questões)
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
                  Icon(Icons.quiz, color: Color(0xFF2D2EFF), size: 32),
                  SizedBox(width: 12),
                  Text('Criar Novo Quiz', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D2EFF))),
                ],
              ),
              const SizedBox(height: 28),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Título do Quiz',
                  prefixIcon: const Icon(Icons.title, color: Color(0xFF7B2FF2)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
                onSaved: (v) => _titulo = v,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Categoria',
                  prefixIcon: const Icon(Icons.category, color: Color(0xFFE94057)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                value: _categoriaId,
                items: _categorias
                    .map<DropdownMenuItem<String>>((cat) => DropdownMenuItem<String>(
                          value: cat['id'] as String,
                          child: Text(cat['name']),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _categoriaId = v),
                validator: (v) => v == null ? 'Selecione uma categoria' : null,
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
                label: const Text('Criar Quiz', style: TextStyle(color: Colors.white)),
                onPressed: _saving ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CriarQuestaoForm extends StatefulWidget {
  const CriarQuestaoForm({Key? key}) : super(key: key);

  @override
  State<CriarQuestaoForm> createState() => _CriarQuestaoFormState();
}

class _CriarQuestaoFormState extends State<CriarQuestaoForm> {
  final _formKey = GlobalKey<FormState>();
  String? _quizId;
  String? _questionText;
  final List<TextEditingController> _optionControllers =
      List.generate(4, (_) => TextEditingController());
  int? _correctIndex;
  List<Map<String, dynamic>> _quizzes = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fetchQuizzes();
  }

  Future<void> _fetchQuizzes() async {
    final data = await Supabase.instance.client
        .from('quizzes')
        .select('id, title');
    setState(() {
      _quizzes = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  void _submit() async {
    if (!_formKey.currentState!.validate() || _correctIndex == null) return;
    _formKey.currentState!.save();
    setState(() => _saving = true);

    // 1. Cria a questão
    final questionRes = await Supabase.instance.client.from('quiz_questions').insert({
      'quiz_id': _quizId,
      'question_text': _questionText,
      'order': 1, // ou calcule a ordem conforme necessário
    }).select().single();

    final questionId = questionRes['id'];

    // 2. Cria as opções
    final letters = ['A', 'B', 'C', 'D'];
    for (int i = 0; i < 4; i++) {
      await Supabase.instance.client.from('quiz_options').insert({
        'question_id': questionId,
        'option_text': _optionControllers[i].text,
        'option_letter': letters[i],
        'is_correct': i == _correctIndex,
      });
    }

    setState(() => _saving = false);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Questão cadastrada com sucesso!')),
      );
      // Limpar campos
      _formKey.currentState?.reset();
      setState(() {
        _quizId = null;
        _questionText = null;
        _correctIndex = null;
        for (final controller in _optionControllers) {
          controller.clear();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Center(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16),
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
                    Icon(Icons.help_outline, color: Color(0xFF2D2EFF), size: 32),
                    SizedBox(width: 12),
                    Text('Adicionar Questão', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D2EFF))),
                  ],
                ),
                const SizedBox(height: 28),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Quiz',
                    prefixIcon: const Icon(Icons.quiz, color: Color(0xFF7B2FF2)),
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
                  validator: (v) => v == null ? 'Selecione o quiz' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Enunciado da Questão',
                    prefixIcon: const Icon(Icons.question_answer, color: Color(0xFFE94057)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
                  onSaved: (v) => _questionText = v,
                ),
                const SizedBox(height: 20),
                ...List.generate(4, (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _optionControllers[i],
                    decoration: InputDecoration(
                      labelText: 'Opção ${String.fromCharCode(65 + i)}',
                      prefixIcon: Icon(Icons.circle, color: i == 0 ? Colors.orange : Colors.blueAccent),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
                  ),
                )),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF2D2EFF)),
                      const SizedBox(width: 8),
                      const Text('Correta:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 12),
                      ...List.generate(4, (i) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Radio<int>(
                            value: i,
                            groupValue: _correctIndex,
                            onChanged: (v) => setState(() => _correctIndex = v),
                            activeColor: Colors.green,
                          ),
                          Text(String.fromCharCode(65 + i)),
                        ],
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D2EFF),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 8,
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  icon: _saving
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save, color: Colors.white),
                  label: const Text('Salvar Questão', style: TextStyle(color: Colors.white)),
                  onPressed: _saving ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AprovarQuizForm extends StatefulWidget {
  const AprovarQuizForm({Key? key}) : super(key: key);

  @override
  State<AprovarQuizForm> createState() => _AprovarQuizFormState();
}

class _AprovarQuizFormState extends State<AprovarQuizForm> {
  bool _loading = true;
  List<Map<String, dynamic>> _quizzes = [];

  @override
  void initState() {
    super.initState();
    _fetchQuizzes();
  }

  Future<void> _fetchQuizzes() async {
    final data = await Supabase.instance.client
        .from('quizzes')
        .select('id, title, category_id, created_by, aprovado, destaque')
        .order('created_at', ascending: false);
    setState(() {
      _quizzes = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  Future<String> _getCategoriaNome(String categoryId) async {
    final data = await Supabase.instance.client
        .from('quiz_categories')
        .select('name')
        .eq('id', categoryId)
        .maybeSingle();
    return data?['name'] ?? '';
  }

  Future<String> _getCriadorNome(String userId) async {
    final data = await Supabase.instance.client
        .from('profiles')
        .select('username')
        .eq('id', userId)
        .maybeSingle();
    return data?['username'] ?? '';
  }

  Future<void> _aprovarQuiz(String quizId) async {
    await Supabase.instance.client
        .from('quizzes')
        .update({'aprovado': true})
        .eq('id', quizId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Quiz aprovado!')),
    );
    _fetchQuizzes();
  }

  Future<void> _recusarQuiz(String quizId) async {
    await Supabase.instance.client
        .from('quizzes')
        .delete()
        .eq('id', quizId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Quiz recusado e removido!')),
    );
    _fetchQuizzes();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_quizzes.isEmpty) {
      return const Center(child: Text('Nenhum quiz cadastrado.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _quizzes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (context, i) {
        final quiz = _quizzes[i];
        return FutureBuilder<List<String>>(
          future: Future.wait([
            _getCategoriaNome(quiz['category_id']),
            _getCriadorNome(quiz['created_by']),
          ]),
          builder: (context, snapshot) {
            final categoria = snapshot.data?[0] ?? '';
            final criador = snapshot.data?[1] ?? '';
            return Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.quiz, color: Color(0xFF2D2EFF), size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          quiz['title'] ?? '',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D2EFF)),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          quiz['destaque'] == true ? Icons.star : Icons.star_border,
                          color: quiz['destaque'] == true ? Colors.amber : Colors.grey,
                        ),
                        tooltip: 'Destacar Quiz na Home',
                        onPressed: () async {
                          // Remove destaque de todos os outros quizzes
                          await Supabase.instance.client
                              .from('quizzes')
                              .update({'destaque': false})
                              .neq('id', quiz['id']);
                          // Destaca o quiz atual
                          await Supabase.instance.client
                              .from('quizzes')
                              .update({'destaque': true})
                              .eq('id', quiz['id']);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Quiz destacado na Home!')),
                          );
                          _fetchQuizzes();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.category, color: Color(0xFFE94057), size: 20),
                      const SizedBox(width: 6),
                      Text(categoria, style: const TextStyle(fontSize: 16)),
                      const Spacer(),
                      const Icon(Icons.person, color: Color(0xFF7B2FF2), size: 20),
                      const SizedBox(width: 6),
                      Text(criador, style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.check, color: Colors.white),
                          label: const Text('Aprovar', style: TextStyle(color: Colors.white)),
                          onPressed: () => _aprovarQuiz(quiz['id']),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.close, color: Colors.white),
                          label: const Text('Recusar', style: TextStyle(color: Colors.white)),
                          onPressed: () => _recusarQuiz(quiz['id']),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class EditarQuizForm extends StatefulWidget {
  const EditarQuizForm({Key? key}) : super(key: key);

  @override
  State<EditarQuizForm> createState() => _EditarQuizFormState();
}

class _EditarQuizFormState extends State<EditarQuizForm> {
  bool _loading = true;
  List<Map<String, dynamic>> _quizzes = [];
  List<Map<String, dynamic>> _categorias = [];
  Map<String, dynamic>? _selectedQuiz;
  String? _titulo;
  String? _categoriaId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final quizzes = await Supabase.instance.client
        .from('quizzes')
        .select('id, title, category_id, aprovado')
        .eq('aprovado', true)
        .order('created_at', ascending: false);
    final categorias = await Supabase.instance.client
        .from('quiz_categories')
        .select('id, name');
    setState(() {
      _quizzes = List<Map<String, dynamic>>.from(quizzes);
      _categorias = List<Map<String, dynamic>>.from(categorias);
      _loading = false;
    });
  }

  void _onSelectQuiz(String? quizId) {
    final quiz = _quizzes.firstWhere((q) => q['id'] == quizId, orElse: () => {});
    setState(() {
      _selectedQuiz = quiz;
      _titulo = quiz['title'];
      _categoriaId = quiz['category_id'];
    });
  }

  void _submit() async {
    if (_selectedQuiz == null || _titulo == null || _categoriaId == null) return;
    setState(() => _saving = true);
    await Supabase.instance.client.from('quizzes').update({
      'title': _titulo,
      'category_id': _categoriaId,
    }).eq('id', _selectedQuiz!['id']);
    setState(() => _saving = false);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quiz atualizado com sucesso!')),
      );
      _fetchData();
      setState(() {
        _selectedQuiz = null;
        _titulo = null;
        _categoriaId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Center(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: const [
                  Icon(Icons.edit, color: Color(0xFF2D2EFF), size: 32),
                  SizedBox(width: 12),
                  Text('Editar Quiz', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D2EFF))),
                ],
              ),
              const SizedBox(height: 28),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Selecione o Quiz',
                  prefixIcon: const Icon(Icons.quiz, color: Color(0xFF7B2FF2)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                value: _selectedQuiz?['id'],
                items: _quizzes
                    .map<DropdownMenuItem<String>>((quiz) => DropdownMenuItem<String>(
                          value: quiz['id'] as String,
                          child: Text(quiz['title']),
                        ))
                    .toList(),
                onChanged: _onSelectQuiz,
                validator: (v) => v == null ? 'Selecione o quiz' : null,
              ),
              if (_selectedQuiz != null) ...[
                const SizedBox(height: 20),
                TextFormField(
                  initialValue: _titulo,
                  decoration: InputDecoration(
                    labelText: 'Título do Quiz',
                    prefixIcon: const Icon(Icons.title, color: Color(0xFF7B2FF2)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (v) => setState(() => _titulo = v),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Categoria',
                    prefixIcon: const Icon(Icons.category, color: Color(0xFFE94057)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  value: _categoriaId,
                  items: _categorias
                      .map<DropdownMenuItem<String>>((cat) => DropdownMenuItem<String>(
                            value: cat['id'] as String,
                            child: Text(cat['name']),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _categoriaId = v),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D2EFF),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 8,
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  icon: _saving
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save, color: Colors.white),
                  label: const Text('Salvar Alterações', style: TextStyle(color: Colors.white)),
                  onPressed: _saving ? null : _submit,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EditarQuestaoForm extends StatefulWidget {
  const EditarQuestaoForm({Key? key}) : super(key: key);

  @override
  State<EditarQuestaoForm> createState() => _EditarQuestaoFormState();
}

class _EditarQuestaoFormState extends State<EditarQuestaoForm> {
  bool _loading = true;
  List<Map<String, dynamic>> _quizzes = [];
  List<Map<String, dynamic>> _questoes = [];
  List<Map<String, dynamic>> _opcoes = [];
  String? _quizId;
  String? _questaoId;
  String? _enunciado;
  final List<TextEditingController> _optionControllers =
      List.generate(4, (_) => TextEditingController());
  int? _correctIndex;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fetchQuizzes();
  }

  Future<void> _fetchQuizzes() async {
    final quizzes = await Supabase.instance.client
        .from('quizzes')
        .select('id, title')
        .order('created_at', ascending: false);
    setState(() {
      _quizzes = List<Map<String, dynamic>>.from(quizzes);
      _loading = false;
    });
  }

  Future<void> _fetchQuestoes(String quizId) async {
    setState(() {
      _questoes = [];
      _questaoId = null;
      _enunciado = null;
      _opcoes = [];
      _correctIndex = null;
      for (final c in _optionControllers) {
        c.clear();
      }
    });
    final questoes = await Supabase.instance.client
        .from('quiz_questions')
        .select('id, question_text')
        .eq('quiz_id', quizId)
        .order('order', ascending: true);
    setState(() {
      _questoes = List<Map<String, dynamic>>.from(questoes);
    });
  }

  Future<void> _fetchOpcoes(String questaoId) async {
    final opcoes = await Supabase.instance.client
        .from('quiz_options')
        .select('id, option_text, option_letter, is_correct')
        .eq('question_id', questaoId)
        .order('option_letter', ascending: true);
    setState(() {
      _opcoes = List<Map<String, dynamic>>.from(opcoes);
      for (int i = 0; i < 4; i++) {
        _optionControllers[i].text = _opcoes[i]['option_text'];
        if (_opcoes[i]['is_correct'] == true) {
          _correctIndex = i;
        }
      }
    });
  }

  void _onSelectQuiz(String? quizId) {
    setState(() {
      _quizId = quizId;
      _questaoId = null;
      _enunciado = null;
      _opcoes = [];
      _correctIndex = null;
      for (final c in _optionControllers) {
        c.clear();
      }
    });
    if (quizId != null) {
      _fetchQuestoes(quizId);
    }
  }

  void _onSelectQuestao(String? questaoId) {
    final questao = _questoes.firstWhere((q) => q['id'] == questaoId, orElse: () => {});
    setState(() {
      _questaoId = questaoId;
      _enunciado = questao['question_text'];
    });
    if (questaoId != null) {
      _fetchOpcoes(questaoId);
    }
  }

  void _submit() async {
    final questaoId = _questaoId;
    if (questaoId == null || _enunciado == null || _correctIndex == null) return;
    setState(() => _saving = true);

    // Atualiza a questão
    await Supabase.instance.client.from('quiz_questions').update({
      'question_text': _enunciado,
    }).eq('id', questaoId);

    // Atualiza as opções
    for (int i = 0; i < 4; i++) {
      await Supabase.instance.client.from('quiz_options').update({
        'option_text': _optionControllers[i].text,
        'is_correct': i == _correctIndex,
      }).eq('id', _opcoes[i]['id']);
    }

    setState(() => _saving = false);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Questão atualizada com sucesso!')),
      );
      _fetchQuestoes(_quizId!);
      setState(() {
        _questaoId = null;
        _enunciado = null;
        _opcoes = [];
        _correctIndex = null;
        for (final c in _optionControllers) {
          c.clear();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth * 0.95;
          return SingleChildScrollView(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              padding: const EdgeInsets.all(16),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.edit_note, color: Color(0xFF2D2EFF), size: 32),
                      SizedBox(width: 12),
                      Text('Editar Questão', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D2EFF))),
                    ],
                  ),
                  const SizedBox(height: 28),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Quiz',
                      prefixIcon: const Icon(Icons.quiz, color: Color(0xFF7B2FF2)),
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
                    onChanged: _onSelectQuiz,
                    validator: (v) => v == null ? 'Selecione o quiz' : null,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Questão',
                      prefixIcon: const Icon(Icons.help, color: Color(0xFFE94057)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    value: _questaoId,
                    items: [
                      ..._questoes.map<DropdownMenuItem<String>>((q) => DropdownMenuItem<String>(
                            value: q['id'] as String,
                            child: Text(q['question_text']),
                          )),
                      const DropdownMenuItem<String>(
                        value: '__nova__',
                        child: Text('Adicionar Nova', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D2EFF))),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == '__nova__') {
                        setState(() {
                          _questaoId = v;
                          _enunciado = '';
                          _correctIndex = null;
                          for (final c in _optionControllers) {
                            c.clear();
                          }
                        });
                      } else {
                        _onSelectQuestao(v);
                      }
                    },
                    validator: (v) => v == null ? 'Selecione a questão' : null,
                  ),
                  if (_questaoId == '__nova__') ...[
                    const SizedBox(height: 20),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Enunciado da Nova Questão',
                        prefixIcon: const Icon(Icons.question_answer, color: Color(0xFFE94057)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (v) => setState(() => _enunciado = v),
                    ),
                    const SizedBox(height: 20),
                    ...List.generate(4, (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: _optionControllers[i],
                        decoration: InputDecoration(
                          labelText: 'Opção ${String.fromCharCode(65 + i)}',
                          prefixIcon: Icon(Icons.circle, color: i == 0 ? Colors.orange : Colors.blueAccent),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    )),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFF2D2EFF)),
                          const SizedBox(width: 8),
                          const Text('Correta:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                          ...List.generate(4, (i) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Radio<int>(
                                value: i,
                                groupValue: _correctIndex,
                                onChanged: (v) => setState(() => _correctIndex = v),
                                activeColor: Colors.green,
                              ),
                              Text(String.fromCharCode(65 + i)),
                            ],
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D2EFF),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 8,
                        minimumSize: const Size(double.infinity, 56),
                      ),
                      icon: _saving
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.add, color: Colors.white),
                      label: const Text('Salvar Nova Questão', style: TextStyle(color: Colors.white)),
                      onPressed: _saving
                          ? null
                          : () async {
                              if (_enunciado == null || _enunciado!.isEmpty || _correctIndex == null || _optionControllers.any((c) => c.text.isEmpty)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Preencha todos os campos e selecione a opção correta.')),
                                );
                                return;
                              }
                              setState(() => _saving = true);
                              // 1. Cria a questão
                              final questionRes = await Supabase.instance.client.from('quiz_questions').insert({
                                'quiz_id': _quizId,
                                'question_text': _enunciado,
                                'order': _questoes.length + 1,
                              }).select().single();
                              final questionId = questionRes['id'];
                              // 2. Cria as opções
                              final letters = ['A', 'B', 'C', 'D'];
                              for (int i = 0; i < 4; i++) {
                                await Supabase.instance.client.from('quiz_options').insert({
                                  'question_id': questionId,
                                  'option_text': _optionControllers[i].text,
                                  'option_letter': letters[i],
                                  'is_correct': i == _correctIndex,
                                });
                              }
                              setState(() => _saving = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Nova questão cadastrada com sucesso!')),
                                );
                                // Limpar campos e atualizar lista
                                _fetchQuestoes(_quizId!);
                                setState(() {
                                  _questaoId = null;
                                  _enunciado = null;
                                  _correctIndex = null;
                                  for (final c in _optionControllers) {
                                    c.clear();
                                  }
                                });
                              }
                            },
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class RankingQuizForm extends StatefulWidget {
  const RankingQuizForm({Key? key}) : super(key: key);

  @override
  State<RankingQuizForm> createState() => _RankingQuizFormState();
}

class _RankingQuizFormState extends State<RankingQuizForm> {
  String? _quizId;
  List<Map<String, dynamic>> _quizzes = [];
  List<Map<String, dynamic>> _ranking = [];
  int _totalQuestoes = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchQuizzes();
  }

  Future<void> _fetchQuizzes() async {
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

  Future<void> _fetchRanking(String quizId) async {
    setState(() {
      _loading = true;
      _ranking = [];
      _totalQuestoes = 0;
    });

    // Buscar total de questões do quiz
    final questoes = await Supabase.instance.client
        .from('quiz_questions')
        .select('id')
        .eq('quiz_id', quizId);
    final totalQuestoes = questoes.length;

    // Buscar todas as respostas dos usuários para esse quiz
    final respostas = await Supabase.instance.client
        .from('quiz_answers')
        .select('user_id, question_id, option_id, answered_at, quiz_options(is_correct), profiles(id, username, avatar_url)')
        .inFilter('question_id', questoes.map((q) => q['id']).toList());

    // Agrupar por usuário
    final Map<String, Map<String, dynamic>> ranking = {};
    for (final r in respostas) {
      final user = r['profiles'];
      final userId = user['id'];
      final userRanking = ranking.putIfAbsent(userId, () => {
        'user_id': userId,
        'username': user['username'],
        'avatar_url': user['avatar_url'],
        'acertos': 0,
        'erros': 0,
      });
      if (r['quiz_options']?['is_correct'] == true) {
        userRanking['acertos'] += 1;
      } else {
        userRanking['erros'] += 1;
      }
    }
    final rankingList = ranking.values.toList();
    rankingList.sort((a, b) => (b['acertos'] as int).compareTo(a['acertos'] as int));

    setState(() {
      _ranking = rankingList;
      _totalQuestoes = totalQuestoes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: const [
                  Icon(Icons.leaderboard, color: Color(0xFF2D2EFF), size: 32),
                  SizedBox(width: 12),
                  Text('Ranking do Quiz', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2D2EFF))),
                ],
              ),
              const SizedBox(height: 28),
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Quiz',
                  prefixIcon: const Icon(Icons.quiz, color: Color(0xFF7B2FF2)),
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
                onChanged: (v) {
                  setState(() => _quizId = v);
                  if (v != null) _fetchRanking(v);
                },
                validator: (v) => v == null ? 'Selecione o quiz' : null,
              ),
              const SizedBox(height: 28),
              if (_quizId != null && _ranking.isNotEmpty)
                Column(
                  children: _ranking.map((user) {
                    final acertos = user['acertos'] as int;
                    final erros = user['erros'] as int;
                    final percent = _totalQuestoes > 0 ? acertos / _totalQuestoes : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundImage: user['avatar_url'] != null && user['avatar_url'].toString().isNotEmpty
                                ? NetworkImage(user['avatar_url'])
                                : null,
                            radius: 28,
                            child: (user['avatar_url'] == null || user['avatar_url'].toString().isEmpty)
                                ? const Icon(Icons.person, size: 28)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Text(
                              user['username'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                )
              else if (_quizId != null)
                const Center(child: Text('Nenhum participante ainda.')),
            ],
          ),
        ),
      ),
    );
  }
} 