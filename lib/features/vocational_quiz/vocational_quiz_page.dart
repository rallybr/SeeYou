import 'package:flutter/material.dart';
import '../../data/remote/vocational_project_service.dart';
import '../../data/remote/vocational_question_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:seeyou/widgets/modern_background.dart';
import 'dart:async';
import 'dart:math';

class VocationalQuizPage extends StatefulWidget {
  const VocationalQuizPage({Key? key}) : super(key: key);

  @override
  State<VocationalQuizPage> createState() => _VocationalQuizPageState();
}

class _VocationalQuizPageState extends State<VocationalQuizPage> {
  int currentQuestion = 0;
  bool loading = true;
  List<Map<String, dynamic>> questions = [];
  List<Map<String, dynamic>> projects = [];
  List<String?> selectedOptions = List.filled(12, null);
  bool showResult = false;
  List<String> topProjectIds = [];

  final PageController _carouselController = PageController(viewportFraction: 0.25);
  Timer? _carouselTimer;

  int countdownKey = 0;
  bool timeoutActive = false;

  @override
  void initState() {
    super.initState();
    _fetchQuestionsAndProjects();
    _startCarouselAutoplay();
  }

  void _startCarouselAutoplay() {
    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (projects.isEmpty || !_carouselController.hasClients) return;
      int nextPage = _carouselController.page!.round() + 1;
      if (nextPage >= projects.length) {
        _carouselController.jumpToPage(0);
      } else {
        _carouselController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _carouselController.dispose();
    super.dispose();
  }

  Future<void> _fetchQuestionsAndProjects() async {
    setState(() => loading = true);
    try {
      final projectsData = await VocationalProjectService().getProjects();
      final questionsData = await VocationalQuestionService().getQuestionsWithOptions();
      setState(() {
        projects = projectsData;
        questions = questionsData.map((q) => {
          'id': q['id'],
          'pergunta': q['pergunta'],
          'opcoes': (q['vocational_options'] as List)
              .map((o) => o['texto'] as String)
              .toList(),
          'projetos': (q['vocational_options'] as List)
              .map((o) => o['project_id'] as String)
              .toList(),
        }).toList();
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar quiz: $e')),
      );
    }
  }

  Future<void> _enviarSolicitacaoProjeto(Map<String, dynamic> projeto) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client.from('vocational_requests').insert({
        'user_id': user.id,
        'project_id': projeto['id'],
        'status': 'pendente',
        'created_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Solicitação enviada para o coordenador do projeto ${projeto['nome']}!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar solicitação: $e')),
      );
    }
  }

  void _nextQuestionTimeout() async {
    if (timeoutActive) return;
    timeoutActive = true;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final question = questions[currentQuestion];
    final questionId = question['id'];
    // Verifica se já respondeu
    // No quiz vocacional não tem duel_id, então só verifica user e question
    final existing = await Supabase.instance.client
        .from('quiz_answers')
        .select()
        .eq('user_id', user.id)
        .eq('question_id', questionId)
        .maybeSingle();
    if (existing == null) {
      await Supabase.instance.client.from('quiz_answers').insert({
        'user_id': user.id,
        'question_id': questionId,
        'option_id': null, // Não respondeu
        'answered_at': DateTime.now().toIso8601String(),
      });
    }
    setState(() {
      showResult = true;
    });
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      showResult = false;
      if (currentQuestion < questions.length - 1) {
        currentQuestion++;
      }
      timeoutActive = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ModernBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Quiz Vocacional', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.black.withOpacity(0.4),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 16),
                        // Carrossel de logos dos projetos
                        SizedBox(
                          height: 90,
                          child: PageView.builder(
                            controller: _carouselController,
                            itemCount: projects.length == 0 ? 0 : projects.length + 4,
                            padEnds: false,
                            itemBuilder: (context, index) {
                              if (projects.isEmpty) return const SizedBox.shrink();
                              final project = projects[index % projects.length];
                              return CircleAvatar(
                                radius: 34,
                                backgroundImage: NetworkImage(project['logo_url'] ?? ''),
                                backgroundColor: Colors.white,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Pergunta
                        if (!showResult)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Text(
                                questions.isNotEmpty ? questions[currentQuestion]['pergunta'] ?? '' : 'Pergunta',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        // Opções
                        if (!showResult && currentQuestion < questions.length) ...List.generate(5, (i) {
                          final optionText = questions.isNotEmpty
                              ? (questions[currentQuestion]['opcoes'] != null && questions[currentQuestion]['opcoes'].length > i
                                  ? questions[currentQuestion]['opcoes'][i] ?? ''
                                  : '')
                              : 'Opção ${String.fromCharCode(65 + i)}';
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedOptions[currentQuestion] = i.toString();
                                  if (currentQuestion < questions.length - 1) {
                                    currentQuestion++;
                                  } else if (currentQuestion == questions.length - 1) {
                                    // Calcular os dois projetos mais compatíveis
                                    final Map<String, int> projectCount = {};
                                    for (int q = 0; q < questions.length; q++) {
                                      final selected = selectedOptions[q];
                                      if (selected != null) {
                                        final projectId = questions[q]['projetos'][int.parse(selected)];
                                        projectCount[projectId] = (projectCount[projectId] ?? 0) + 1;
                                      }
                                    }
                                    final sorted = projectCount.entries.toList()
                                      ..sort((a, b) => b.value.compareTo(a.value));
                                    topProjectIds = sorted.take(2).map((e) => e.key).toList();
                                    showResult = true;
                                  }
                                });
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF7B2FF2).withOpacity(0.85), Color(0xFFF357A8).withOpacity(0.85)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.orange,
                                      child: Text(String.fromCharCode(65 + i), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 18),
                                    Expanded(
                                      child: Text(
                                        optionText,
                                        style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        if (showResult)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                            child: Column(
                              children: [
                                const Text(
                                  'Projetos mais compatíveis com você:',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                ...topProjectIds.map((id) {
                                  final projetoIndex = projects.indexWhere((p) => p['id'] == id);
                                  if (projetoIndex == -1) return const SizedBox.shrink();
                                  final projeto = projects[projetoIndex];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 18),
                                    child: GestureDetector(
                                      onTap: () {
                                        _enviarSolicitacaoProjeto(projeto);
                                      },
                                      child: Column(
                                        children: [
                                          CircleAvatar(
                                            radius: 44,
                                            backgroundImage: NetworkImage(projeto['logo_url'] ?? ''),
                                            backgroundColor: Colors.white,
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            projeto['nome'] ?? '',
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 8),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF2D2EFF),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            ),
                                            icon: const Icon(Icons.send, color: Colors.white),
                                            label: const Text('Quero participar', style: TextStyle(color: Colors.white)),
                                            onPressed: () => _enviarSolicitacaoProjeto(projeto),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        const Spacer(),
                        // Barra de progresso
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          child: Column(
                            children: [
                              LinearProgressIndicator(
                                value: showResult ? 1.0 : (currentQuestion / questions.length),
                                minHeight: 24,
                                backgroundColor: Colors.white.withOpacity(0.3),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2D2EFF)),
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                showResult
                                  ? '100% - Etapa ${questions.length + 1} de ${questions.length + 1}'
                                  : '${((currentQuestion / questions.length) * 100).toStringAsFixed(0)}% - Etapa ${currentQuestion + 1} de ${questions.length + 1}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                    if (!loading && !showResult && questions.isNotEmpty && currentQuestion < questions.length)
                      Positioned(
                        top: 90,
                        right: 24,
                        child: _CountdownCircle(
                          key: ValueKey('$currentQuestion-$countdownKey'),
                          seconds: 12,
                          onTimeout: () {
                            _nextQuestionTimeout();
                            setState(() => countdownKey++);
                          },
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _CountdownCircle extends StatefulWidget {
  final int seconds;
  final VoidCallback onTimeout;
  const _CountdownCircle({Key? key, required this.seconds, required this.onTimeout}) : super(key: key);

  @override
  State<_CountdownCircle> createState() => _CountdownCircleState();
}

class _CountdownCircleState extends State<_CountdownCircle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.seconds;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.seconds),
    )..addListener(() {
        final t = (widget.seconds - (_controller.value * widget.seconds)).ceil();
        if (t != _current && mounted) {
          setState(() => _current = t);
        }
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onTimeout();
        }
      });
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _CountdownCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seconds != widget.seconds) {
      _controller.dispose();
      _controller = AnimationController(
        vsync: this,
        duration: Duration(seconds: widget.seconds),
      )..addListener(() {
          final t = (widget.seconds - (_controller.value * widget.seconds)).ceil();
          if (t != _current && mounted) {
            setState(() => _current = t);
          }
        })
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            widget.onTimeout();
          }
        });
      _controller.forward(from: 0);
      setState(() => _current = widget.seconds);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(70, 70),
            painter: _CircleCountdownPainter(
              progress: 1 - _controller.value,
            ),
          ),
          Text(
            _current.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleCountdownPainter extends CustomPainter {
  final double progress;
  _CircleCountdownPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final startAngle = -pi / 2;
    final sweepAngle = 2 * pi * progress;
    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;
    final fgPaint = Paint()
      ..shader = SweepGradient(
        colors: [Colors.cyanAccent, Colors.greenAccent, Colors.blueAccent],
        startAngle: 0,
        endAngle: 2 * pi,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7;
    // Fundo
    canvas.drawArc(
      Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2 - 4),
      0,
      2 * pi,
      false,
      bgPaint,
    );
    // Progresso
    canvas.drawArc(
      Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2 - 4),
      startAngle,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircleCountdownPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
} 