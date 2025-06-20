import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui';
import 'criar_campeonato_form.dart';
import 'gerenciar_campeonatos_page.dart';
import 'ranking_campeonato_page.dart';
import 'limpar_duplicados_page.dart';
import 'gerenciar_equipes_page.dart';
import 'gerenciar_participantes_page.dart';
import 'confrontos_campeonato_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  int? _selectedQuizSubMenu; // null = não está em submenu
  int? _selectedChampionshipSubMenu;

  final List<String> _sections = [
    'Visão Geral',
    'Usuários',
    'Posts',
    'Moderação',
    'Estatísticas',
    'Configurações',
    'Bible Quiz', // Novo menu principal
    'Quiz Campeonato',
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

  final List<String> _championshipSubMenus = [
    'Criar Campeonato',
    'Gerenciar Campeonatos',
    'Ranking de Campeonato',
  ];

  String? _championshipId;
  List<Map<String, dynamic>> _championships = [];
  List<Map<String, dynamic>> _quizzes = [];
  bool _loading = true;
  List<Map<String, dynamic>> _categorias = [];

  @override
  void initState() {
    super.initState();
    _fetchCategorias();
    _fetchChampionships();
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

  Future<void> _fetchChampionships() async {
    final data = await Supabase.instance.client
        .from('quiz_championships')
        .select('id, title');
    setState(() {
      _championships = List<Map<String, dynamic>>.from(data);
    });
  }

  Future<void> _fetchQuizzes() async {
    var query = Supabase.instance.client.from('quizzes').select('id, title');
    if (_championshipId != null) {
      query = query.eq('championship_id', _championshipId!);
    }
    final data = await query;
    setState(() {
      _quizzes = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        return Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: Stack(
              children: [
                // Fundo glassmorphism
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(0),
                    bottomRight: Radius.circular(0),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      height: kToolbarHeight + 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.45),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                AppBar(
                  title: const Text('DASHBOARD', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                ),
              ],
            ),
          ),
          drawer: isDesktop ? null : _DashboardDrawer(
            selectedIndex: _selectedIndex,
            onSelect: (i) => setState(() {
              _selectedIndex = i;
              _selectedQuizSubMenu = null;
              _selectedChampionshipSubMenu = null;
            }),
            sections: _sections,
            selectedQuizSubMenu: _selectedQuizSubMenu,
            onQuizSubMenuSelect: (i) => setState(() {
              _selectedIndex = _sections.length - 1;
              _selectedQuizSubMenu = i;
              _selectedChampionshipSubMenu = null;
            }),
            quizSubMenus: _quizSubMenus,
            selectedChampionshipSubMenu: _selectedChampionshipSubMenu,
            onChampionshipSubMenuSelect: (i) => setState(() {
              _selectedIndex = _sections.length;
              _selectedChampionshipSubMenu = i;
              _selectedQuizSubMenu = null;
            }),
            championshipSubMenus: _championshipSubMenus,
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
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - kToolbarHeight,
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
                            _selectedChampionshipSubMenu = null;
                          }),
                          sections: _sections,
                          selectedQuizSubMenu: _selectedQuizSubMenu,
                          onQuizSubMenuSelect: (i) => setState(() {
                            _selectedIndex = _sections.length - 1;
                            _selectedQuizSubMenu = i;
                            _selectedChampionshipSubMenu = null;
                          }),
                          quizSubMenus: _quizSubMenus,
                          selectedChampionshipSubMenu: _selectedChampionshipSubMenu,
                          onChampionshipSubMenuSelect: (i) => setState(() {
                            _selectedIndex = _sections.length;
                            _selectedChampionshipSubMenu = i;
                            _selectedQuizSubMenu = null;
                          }),
                          championshipSubMenus: _championshipSubMenus,
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: _selectedIndex == _sections.length - 1
                            ? _BibleQuizSection(index: _selectedQuizSubMenu)
                            : _selectedIndex == _sections.length
                                ? _QuizChampionshipSection(index: _selectedChampionshipSubMenu)
                                : _DashboardSection(index: _selectedIndex),
                      ),
                    ),
                  ],
                ),
              ),
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
  final int? selectedChampionshipSubMenu;
  final Function(int)? onChampionshipSubMenuSelect;
  final List<String>? championshipSubMenus;
  const _DashboardDrawer({
    required this.selectedIndex,
    required this.onSelect,
    required this.sections,
    this.selectedQuizSubMenu,
    this.onQuizSubMenuSelect,
    this.quizSubMenus,
    this.selectedChampionshipSubMenu,
    this.onChampionshipSubMenuSelect,
    this.championshipSubMenus,
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
      Icons.emoji_events, // Quiz Campeonato
    ];
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFFB71C1C),
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
            leading: const Icon(Icons.home, color: Color(0xFFB71C1C)),
            title: const Text('Home', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB71C1C))),
            onTap: () {
              Navigator.of(context).pushNamedAndRemoveUntil('/feed', (route) => false);
            },
          ),
          const Divider(),
          for (int i = 0; i < sections.length; i++)
            if (sections[i] != 'Bible Quiz' && sections[i] != 'Quiz Campeonato')
              ListTile(
                leading: Icon(icons[i], color: Color(0xFFB71C1C)),
                title: Text(sections[i], style: TextStyle(fontWeight: selectedIndex == i ? FontWeight.bold : FontWeight.normal, color: Color(0xFFB71C1C))),
                selected: selectedIndex == i,
                onTap: () {
                  onSelect(i);
                  if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                },
              ),
          // Menu Midias
          ExpansionTile(
            leading: const Icon(Icons.perm_media, color: Color(0xFFB71C1C)),
            title: const Text('Midias', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB71C1C))),
            children: [
              ListTile(
                leading: const Icon(Icons.library_music, color: Color(0xFF2D2EFF)),
                title: const Text('Musicas', style: TextStyle(color: Color(0xFF2D2EFF))),
                onTap: () {
                  Navigator.of(context).pushNamed('/admin/musicas');
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_collection_outlined, color: Color(0xFF2D2EFF)),
                title: const Text('Videos', style: TextStyle(color: Color(0xFF2D2EFF))),
                onTap: () {
                  Navigator.of(context).pushNamed('/admin/videos');
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline, color: Color(0xFF2D2EFF)),
                title: const Text('Mensagens', style: TextStyle(color: Color(0xFF2D2EFF))),
                onTap: () {
                  Navigator.of(context).pushNamed('/admin/mensagens');
                },
              ),
            ],
          ),
          // Menu Vocacional
          ExpansionTile(
            leading: const Icon(Icons.psychology, color: Color(0xFFB71C1C)),
            title: const Text('Vocacional', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB71C1C))),
            children: [
              ListTile(
                leading: const Icon(Icons.quiz, color: Color(0xFF2D2EFF)),
                title: const Text('Criar Teste Vocacional', style: TextStyle(color: Color(0xFF2D2EFF))),
                onTap: () {
                  Navigator.of(context).pushNamed('/admin/vocacional/criar_teste');
                },
              ),
              ListTile(
                leading: const Icon(Icons.group_work, color: Color(0xFF2D2EFF)),
                title: const Text('Cadastrar Projeto', style: TextStyle(color: Color(0xFF2D2EFF))),
                onTap: () {
                  Navigator.of(context).pushNamed('/admin/vocacional/cadastrar_projeto');
                },
              ),
              ListTile(
                leading: const Icon(Icons.question_answer, color: Color(0xFF2D2EFF)),
                title: const Text('Criar Questão', style: TextStyle(color: Color(0xFF2D2EFF))),
                onTap: () {
                  Navigator.of(context).pushNamed('/admin/vocacional/criar_questao');
                },
              ),
              ListTile(
                leading: const Icon(Icons.manage_accounts, color: Color(0xFF2D2EFF)),
                title: const Text('Gerenciar', style: TextStyle(color: Color(0xFF2D2EFF))),
                onTap: () {
                  Navigator.of(context).pushNamed('/admin/vocacional/gerenciar');
                },
              ),
              ListTile(
                leading: const Icon(Icons.verified, color: Color(0xFF2D2EFF)),
                title: const Text('Projetos (Aprovados)', style: TextStyle(color: Color(0xFF2D2EFF))),
                onTap: () {
                  Navigator.of(context).pushNamed('/admin/vocacional/aprovados');
                },
              ),
            ],
          ),
          // Bible Quiz menu com submenus
          ExpansionTile(
            leading: Icon(icons[6], color: Color(0xFFB71C1C)),
            title: Text('Bible Quiz', style: TextStyle(fontWeight: selectedIndex == sections.length - 1 ? FontWeight.bold : FontWeight.normal, color: Color(0xFFB71C1C))),
            initiallyExpanded: selectedIndex == sections.length - 1,
            children: [
              for (int i = 0; i < (quizSubMenus?.length ?? 0); i++)
                ListTile(
                  leading: Icon(Icons.arrow_right, color: Color(0xFF2D2EFF)),
                  title: Text(quizSubMenus![i], style: TextStyle(fontWeight: selectedQuizSubMenu == i ? FontWeight.bold : FontWeight.normal, color: Color(0xFF2D2EFF))),
                  selected: selectedQuizSubMenu == i,
                  onTap: () {
                    onQuizSubMenuSelect?.call(i);
                    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                  },
                ),
            ],
          ),
          // Quiz Campeonato menu com submenus
          ExpansionTile(
            leading: Icon(icons[7], color: Color(0xFFB71C1C)),
            title: Text('Quiz Campeonato', style: TextStyle(fontWeight: selectedIndex == sections.length ? FontWeight.bold : FontWeight.normal, color: Color(0xFFB71C1C))),
            initiallyExpanded: selectedIndex == sections.length,
            children: [
              // Submenu Gerenciamento
              ExpansionTile(
                leading: const Icon(Icons.settings, color: Color(0xFFB71C1C)),
                title: const Text('Gerenciamento', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB71C1C))),
                children: [
                  ListTile(
                    leading: const Icon(Icons.manage_accounts, color: Color(0xFF2D2EFF)),
                    title: const Text('Gerenciar Campeonatos', style: TextStyle(color: Color(0xFF2D2EFF))),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const GerenciarCampeonatosPage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.groups, color: Color(0xFF2D2EFF)),
                    title: const Text('Gerenciar Equipe', style: TextStyle(color: Color(0xFF2D2EFF))),
                    onTap: () async {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const GerenciarEquipesPage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.group_add, color: Color(0xFF2D2EFF)),
                    title: const Text('Gerenciar Participantes', style: TextStyle(color: Color(0xFF2D2EFF))),
                    onTap: () async {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const GerenciarParticipantesPage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.sports_kabaddi, color: Color(0xFF2D2EFF)),
                    title: const Text('Ver Confrontos', style: TextStyle(color: Color(0xFF2D2EFF))),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ConfrontosCampeonatoPage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.leaderboard, color: Color(0xFF2D2EFF)),
                    title: const Text('Ver Ranking dos Grupos', style: TextStyle(color: Color(0xFF2D2EFF))),
                    onTap: () {
                      // Aqui você pode abrir uma tela de seleção de campeonato antes de mostrar ranking
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.cleaning_services, color: Color(0xFF2D2EFF)),
                    title: const Text('Limpar Duplicados', style: TextStyle(color: Color(0xFF2D2EFF))),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const LimparDuplicadosPage(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.add_box, color: Color(0xFF2D2EFF)),
                    title: const Text('Criar Campeonato', style: TextStyle(color: Color(0xFF2D2EFF))),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            appBar: AppBar(
                              title: const Text('Criar Campeonato'),
                              backgroundColor: Color(0xFF2D2EFF),
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
                              child: CriarCampeonatoForm(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.emoji_events, color: Color(0xFF2D2EFF)),
                    title: const Text('Ranking de Campeonato', style: TextStyle(color: Color(0xFF2D2EFF))),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => Scaffold(
                            appBar: AppBar(
                              title: const Text('Ranking de Campeonato'),
                              backgroundColor: Color(0xFF2D2EFF),
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
                              child: RankingCampeonatoPage(),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
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

class _DashboardOverview extends StatefulWidget {
  @override
  State<_DashboardOverview> createState() => _DashboardOverviewState();
}

class _DashboardOverviewState extends State<_DashboardOverview> {
  int? totalUsuarios;
  int? totalPosts;
  int? totalQuizzes;
  int? totalParticipantes;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    final usuarios = await Supabase.instance.client.from('profiles').select('id');
    final posts = await Supabase.instance.client.from('posts').select('id');
    final quizzes = await Supabase.instance.client.from('quizzes').select('id');
    // Buscar participantes únicos em quizzes (usando quiz_answers)
    final participantesRaw = await Supabase.instance.client
      .from('quiz_answers')
      .select('user_id, question_id');
    // Buscar quiz_id de cada resposta
    final questoes = await Supabase.instance.client
      .from('quiz_questions')
      .select('id, quiz_id');
    final questaoToQuiz = {for (var q in questoes) q['id']: q['quiz_id']};
    final Set<String> participantesUnicos = {};
    for (final resp in participantesRaw) {
      final quizId = questaoToQuiz[resp['question_id']];
      if (quizId != null && resp['user_id'] != null) {
        participantesUnicos.add('${quizId}_${resp['user_id']}');
      }
    }
    setState(() {
      totalUsuarios = usuarios.length;
      totalPosts = posts.length;
      totalQuizzes = quizzes.length;
      totalParticipantes = participantesUnicos.length;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 18,
              runSpacing: 18,
              alignment: WrapAlignment.center,
              children: [
                _DashboardCard(title: 'Usuários', value: totalUsuarios.toString(), icon: Icons.people, color: Colors.blue),
                _DashboardCard(title: 'Posts', value: totalPosts.toString(), icon: Icons.post_add, color: Colors.purple),
                _DashboardCard(title: 'Quizzes', value: totalQuizzes.toString(), icon: Icons.quiz, color: Colors.orange),
                _DashboardCard(title: 'Participantes', value: totalParticipantes.toString(), icon: Icons.emoji_events, color: Colors.green),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Gráfico de barras
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 8,
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Usuários por mês', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  SizedBox(
                    height: 220,
                    child: BarChart(
                      BarChartData(
                        barGroups: [
                          BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 10, color: Colors.blue)]),
                          BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 12, color: Colors.blue)]),
                          BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 8, color: Colors.blue)]),
                          BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 15, color: Colors.blue)]),
                          BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 7, color: Colors.blue)]),
                          BarChartGroupData(x: 5, barRods: [BarChartRodData(toY: 13, color: Colors.blue)]),
                        ],
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final months = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun'];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(months[value.toInt()]),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Outros gráficos podem ser adicionados aqui
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  const _DashboardCard({required this.title, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      color: Colors.white.withOpacity(0.96),
      shadowColor: color.withOpacity(0.18),
      child: Container(
        width: 140,
        height: 120,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: color)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
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
  String? _championshipId;
  List<Map<String, dynamic>> _categorias = [];
  List<Map<String, dynamic>> _championships = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fetchCategorias();
    _fetchChampionships();
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

  Future<void> _fetchChampionships() async {
    final data = await Supabase.instance.client
        .from('quiz_championships')
        .select('id, title');
    setState(() {
      _championships = List<Map<String, dynamic>>.from(data);
    });
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _saving = true);
    final quizData = {
      'title': _titulo,
      'category_id': _categoriaId,
      'created_by': Supabase.instance.client.auth.currentUser?.id,
      'championship_id': _championshipId,
    };
    print('Tentando criar quiz com os dados:');
    print(quizData);
    try {
      final response = await Supabase.instance.client.from('quizzes').insert(quizData).select().single();
      print('Quiz criado: $response');
      setState(() => _saving = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quiz criado com sucesso!')),
        );
        // Aqui você pode navegar para a próxima etapa (adicionar questões)
      }
    } catch (e) {
      print('Erro ao criar quiz: $e');
      setState(() => _saving = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar quiz: $e')),
        );
      }
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
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Campeonato',
                  prefixIcon: const Icon(Icons.emoji_events, color: Color(0xFF2D2EFF)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                value: _championshipId,
                items: _championships
                    .map<DropdownMenuItem<String>>((champ) => DropdownMenuItem<String>(
                          value: champ['id'] as String,
                          child: Text(champ['title']),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _championshipId = v),
                validator: (v) => v == null ? 'Selecione o campeonato' : null,
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
  String? _championshipId;

  @override
  void initState() {
    super.initState();
    _fetchQuizzes();
  }

  Future<void> _fetchQuizzes() async {
    var query = Supabase.instance.client.from('quizzes').select('id, title');
    if (_championshipId != null) {
      query = query.eq('championship_id', _championshipId!);
    }
    final data = await query;
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
        .or('aprovado.is.false,aprovado.is.null')
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
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
  String? _championshipId;

  @override
  void initState() {
    super.initState();
    _fetchQuizzes();
  }

  Future<void> _fetchQuizzes() async {
    var query = Supabase.instance.client.from('quizzes').select('id, title');
    if (_championshipId != null) {
      query = query.eq('championship_id', _championshipId!);
    }
    final data = await query;
    setState(() {
      _quizzes = List<Map<String, dynamic>>.from(data);
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
                          : const Icon(Icons.save, color: Colors.white),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
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
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D2EFF)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('$acertos/$_totalQuestoes', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: percent),
                            duration: const Duration(milliseconds: 900),
                            builder: (context, value, child) {
                              return Stack(
                                children: [
                                  Container(
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  Container(
                                    height: 18,
                                    width: 220 * value,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF2D2EFF), Color(0xFF7B2FF2), Color(0xFFE94057)],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: Center(
                                      child: Text(
                                        '${(value * 100).toStringAsFixed(0)}%',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14, shadows: [Shadow(color: Colors.black26, blurRadius: 2)]),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
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

class _QuizChampionshipSection extends StatelessWidget {
  final int? index;
  const _QuizChampionshipSection({this.index});

  @override
  Widget build(BuildContext context) {
    switch (index) {
      case 0:
        return const CriarCampeonatoForm();
      case 1:
        return const GerenciarCampeonatosPage();
      case 2:
        return const RankingCampeonatoPage();
      default:
        return const Center(child: Text('Selecione uma opção do menu Quiz Campeonato'));
    }
  }
} 