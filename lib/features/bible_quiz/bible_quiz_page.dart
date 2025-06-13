import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'dart:async';

// Tela principal do Bible Quiz
// Inspirada no layout fornecido pelo usuário
// Pronta para receber animações, sons e integração com assets
// Desenvolvido para o app SeeYou
//
// Pontos de melhoria:
// - Adicionar animações com pacotes como lottie ou animated_text_kit
// - Integrar sons de acerto/erro usando audioplayers
// - Substituir logo e ícones por assets personalizados
// - Melhorar responsividade para diferentes tamanhos de tela

class BibleQuizPage extends StatefulWidget {
  final String? quizId;
  final String? duelId;
  const BibleQuizPage({Key? key, this.quizId, this.duelId}) : super(key: key);

  @override
  State<BibleQuizPage> createState() => _BibleQuizPageState();
}

class _BibleQuizPageState extends State<BibleQuizPage>
    with SingleTickerProviderStateMixin {
  int currentQuestion = 0;
  int correctAnswers = 0;
  bool showResult = false;
  bool isCorrect = false;
  double progress = 0.0;

  bool loading = true;
  List<Map<String, dynamic>> questions = [];
  String? quizId; // Pode ser passado por parâmetro futuramente

  int countdownKey = 0;
  bool timeoutActive = false;
  bool quizFinished = false;

  @override
  void initState() {
    super.initState();
    quizId = widget.quizId;
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    setState(() { loading = true; });
    final user = Supabase.instance.client.auth.currentUser;
    // Buscar quizId aprovado mais recente se não definido
    String? usedQuizId = quizId;
    if (usedQuizId == null) {
      final quiz = await Supabase.instance.client
        .from('quizzes')
        .select('id')
        .eq('aprovado', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
      usedQuizId = quiz?['id'];
    }
    if (usedQuizId == null) {
      setState(() { loading = false; });
      return;
    }
    // Buscar questões e opções
    final questoes = await Supabase.instance.client
      .from('quiz_questions')
      .select('id, question_text, quiz_options(id, option_text, option_letter, is_correct)')
      .eq('quiz_id', usedQuizId)
      .order('order', ascending: true);
    // Montar lista no formato esperado
    final List<Map<String, dynamic>> loadedQuestions = [];
    for (final q in questoes) {
      final options = List<Map<String, dynamic>>.from(q['quiz_options']);
      options.sort((a, b) => (a['option_letter'] as String).compareTo(b['option_letter'] as String));
      final answerIndex = options.indexWhere((o) => o['is_correct'] == true);
      loadedQuestions.add({
        'id': q['id'],
        'question': q['question_text'],
        'options': options.map((o) => o['option_text'] as String).toList(),
        'optionIds': options.map((o) => o['id'] as String).toList(),
        'answer': answerIndex,
      });
    }
    // Buscar respostas do usuário para esse quiz
    List<dynamic> respostas = [];
    if (user != null && loadedQuestions.isNotEmpty) {
      final questionIds = loadedQuestions.map((q) => q['id']).toList();
      respostas = await Supabase.instance.client
        .from('quiz_answers')
        .select('question_id, option_id, quiz_options(is_correct)')
        .eq('user_id', user.id)
        .inFilter('question_id', questionIds);
    }
    // Calcular progresso e acertos
    int acertos = 0;
    int respondidas = 0;
    final Set<String> respondidasIds = {};
    for (final r in respostas) {
      respondidasIds.add(r['question_id']);
      if (r['quiz_options']?['is_correct'] == true) {
        acertos++;
      }
    }
    // Descobrir próxima questão não respondida
    int proxQuestao = 0;
    for (int i = 0; i < loadedQuestions.length; i++) {
      if (!respondidasIds.contains(loadedQuestions[i]['id'])) {
        proxQuestao = i;
        break;
      }
      // Se respondeu todas, fica na última
      if (i == loadedQuestions.length - 1) proxQuestao = i;
    }
    setState(() {
      questions = loadedQuestions;
      loading = false;
      correctAnswers = acertos;
      progress = loadedQuestions.isNotEmpty ? respondidasIds.length / loadedQuestions.length : 0.0;
      currentQuestion = proxQuestao;
    });
  }

  void _playSound(bool correct) async {
    final asset = correct ? 'sounds/success.mp3' : 'sounds/error.mp3';
    final player = AudioPlayer();
    await player.play(AssetSource(asset));
    // Libera o player após o som terminar
    player.onPlayerComplete.listen((event) {
      player.dispose();
    });
  }

  void _onOptionSelected(int index) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return; // Não logado
    final question = questions[currentQuestion];
    final questionId = question['id'];
    final optionId = question['optionIds'][index];
    String? teamId;
    // Se for quiz de campeonato, buscar o team_id do usuário
    if (quizId != null) {
      // Buscar o championship_id do quiz
      final quizData = await Supabase.instance.client
        .from('quizzes')
        .select('championship_id')
        .eq('id', quizId!)
        .maybeSingle();
      final championshipId = quizData?['championship_id'];
      if (championshipId != null) {
        // Buscar o team_id do usuário neste campeonato
        final teamMember = await Supabase.instance.client
          .from('quiz_team_members')
          .select('team_id')
          .eq('user_id', user.id)
          .single();
        teamId = teamMember['team_id'];
      }
    }
    // Verificar se já respondeu
    bool jaRespondeu = false;
    if (widget.duelId != null) {
      // No duelo, só bloqueia se já respondeu para esse duelo
      final existing = await Supabase.instance.client
        .from('quiz_answers')
        .select()
        .eq('user_id', user.id)
        .eq('question_id', questionId)
        .eq('duel_id', widget.duelId!)
        .maybeSingle();
      jaRespondeu = existing != null;
    } else {
      // Fora do duelo, bloqueia se já respondeu globalmente
      final existing = await Supabase.instance.client
        .from('quiz_answers')
        .select()
        .eq('user_id', user.id)
        .eq('question_id', questionId)
        .maybeSingle();
      jaRespondeu = existing != null;
    }
    if (jaRespondeu) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.97),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          contentPadding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
          titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24),
          title: Column(
            children: const [
              Icon(Icons.info_outline, color: Color(0xFF2D2EFF), size: 40),
              SizedBox(height: 12),
              Text(
                'Você já respondeu essa questão',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Color(0xFF2D2EFF),
                ),
              ),
            ],
          ),
          content: const Text(
            'Deseja ver mais quizzes disponíveis para participar?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF7B2FF2),
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              child: const Text('Fechar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/quizzes');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D2EFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              child: const Text('Ver mais quizzes', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }
    // Registrar resposta no Supabase
    await Supabase.instance.client.from('quiz_answers').insert({
      'user_id': user.id,
      'question_id': questionId,
      'option_id': optionId,
      'answered_at': DateTime.now().toIso8601String(),
      if (teamId != null) 'team_id': teamId,
      if (widget.duelId != null) 'duel_id': widget.duelId!,
    });
    final bool acertou = index == question['answer'];
    setState(() {
      showResult = true;
      isCorrect = acertou;
      if (acertou) correctAnswers++;
      progress = (currentQuestion + 1) / questions.length;
    });
    _playSound(acertou);
    Future.delayed(const Duration(seconds: 2), () async {
      setState(() {
        showResult = false;
        if (currentQuestion < questions.length - 1) {
          currentQuestion++;
        }
      });
      // Se terminou o quiz, salva resultado do duelo se duelId estiver presente
      if (currentQuestion == questions.length - 1 && widget.duelId != null) {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          // Buscar todas as respostas corretas deste duelo e quiz
          final respostas = await Supabase.instance.client
            .from('quiz_answers')
            .select('question_id, option_id, quiz_options(is_correct)')
            .eq('user_id', user.id)
            .eq('duel_id', widget.duelId!)
            .eq('quiz_id', quizId!)
            .order('answered_at', ascending: true);

          int acertos = 0;
          for (final r in respostas) {
            if (r['quiz_options']?['is_correct'] == true) {
              acertos++;
            }
          }

          await Supabase.instance.client.from('quiz_duel_results').upsert({
            'duel_id': widget.duelId!,
            'user_id': user.id,
            'score': acertos,
            'finished_at': DateTime.now().toIso8601String(),
          });
        }
      }
    });
  }

  void _nextQuestionTimeout() async {
    if (timeoutActive) return;
    if (quizFinished || currentQuestion >= questions.length) return;
    timeoutActive = true;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final question = questions[currentQuestion];
    final questionId = question['id'];
    // Verifica se já respondeu
    PostgrestFilterBuilder existingQuery = Supabase.instance.client
        .from('quiz_answers')
        .select()
        .eq('user_id', user.id)
        .eq('question_id', questionId);
    if (widget.duelId != null) {
      existingQuery = existingQuery.eq('duel_id', widget.duelId!);
    }
    final existing = await existingQuery.limit(1).maybeSingle();
    if (existing == null) {
      final answerData = {
        'user_id': user.id,
        'question_id': questionId,
        'option_id': null, // Não respondeu
        'answered_at': DateTime.now().toIso8601String(),
      };
      if (widget.duelId != null) {
        answerData['duel_id'] = widget.duelId;
      }
      await Supabase.instance.client.from('quiz_answers').insert(answerData);
    }
    setState(() {
      showResult = true;
      isCorrect = false;
      progress = (currentQuestion + 1) / questions.length;
    });
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      showResult = false;
      if (currentQuestion < questions.length - 1) {
        currentQuestion++;
      } else {
        quizFinished = true;
      }
      timeoutActive = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (questions.isEmpty) {
      return Scaffold(
        body: Stack(
          children: [
            // Fundo gradiente animado
            AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2D2EFF), // Azul vibrante
                    Color(0xFF7B2FF2), // Roxo
                    Color(0xFFE94057), // Vermelho/rosa
                  ],
                ),
              ),
            ),
            // Botão de voltar sobreposto
            Positioned(
              top: 16,
              left: 8,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Voltar',
                ),
              ),
            ),
            // Mensagem central
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.info_outline, color: Colors.white, size: 48),
                    SizedBox(height: 24),
                    Text(
                      'Nenhuma questão disponível para este quiz.',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    final question = questions[currentQuestion];
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 650 || size.width < 350;
    final isLarge = size.width > 600;
    return Scaffold(
      body: Stack(
        children: [
          // Fundo gradiente animado
          AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2D2EFF), // Azul vibrante
                  Color(0xFF7B2FF2), // Roxo
                  Color(0xFFE94057), // Vermelho/rosa
                ],
              ),
            ),
          ),
          // Botão de voltar sobreposto
          Positioned(
            top: 16,
            left: 8,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Voltar',
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isSmall ? 6 : isLarge ? 48 : 16,
                vertical: isSmall ? 6 : 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo
                  Center(
                    child: FractionallySizedBox(
                      widthFactor: isSmall ? 0.95 : isLarge ? 0.6 : 0.8,
                      child: Image.asset(
                        'assets/images/bible_quiz_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SizedBox(height: isSmall ? 12 : 32),
                  // Caixa da questão
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isSmall ? 12 : isLarge ? 36 : 24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xAA2D2EFF), // Azul translúcido
                          Color(0xAA7B2FF2), // Roxo translúcido
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(isSmall ? 10 : 16),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      question['question'],
                      style: TextStyle(
                        fontSize: isSmall ? 16 : isLarge ? 28 : 22,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: isSmall ? 12 : 32),
                  // Opções
                  Expanded(
                    child: ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 4,
                      separatorBuilder: (_, __) => SizedBox(height: isSmall ? 8 : 16),
                      itemBuilder: (context, i) {
                        final letters = ['A', 'B', 'C', 'D'];
                        return GestureDetector(
                          onTap: showResult ? null : () => _onOptionSelected(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            padding: EdgeInsets.symmetric(
                              vertical: isSmall ? 10 : isLarge ? 28 : 18,
                              horizontal: isSmall ? 8 : isLarge ? 32 : 16,
                            ),
                            decoration: BoxDecoration(
                              gradient: !showResult
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xAA2D2EFF), // Azul translúcido
                                        Color(0xAA7B2FF2), // Roxo translúcido
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: showResult
                                  ? (i == question['answer']
                                      ? Colors.green.withOpacity(0.7)
                                      : Colors.red.withOpacity(0.7))
                                  : null,
                              borderRadius: BorderRadius.circular(isSmall ? 18 : 32),
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 8,
                                  offset: Offset(2, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: isSmall ? 18 : isLarge ? 36 : 28, // responsivo
                                  backgroundColor: const Color(0xFFFF7200),
                                  child: Text(
                                    letters[i],
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: isSmall ? 16 : isLarge ? 36 : 28, // responsivo
                                    ),
                                  ),
                                ),
                                SizedBox(width: isSmall ? 8 : 16),
                                Expanded(
                                  child: Text(
                                    question['options'][i],
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isSmall ? 14 : isLarge ? 22 : 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Barra de progresso
                  Padding(
                    padding: EdgeInsets.only(bottom: isSmall ? 12 : isLarge ? 56 : 32),
                    child: Column(
                      children: [
                        CustomProgressBar(
                          value: progress,
                          height: isSmall ? 24 : isLarge ? 48 : 38,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(progress * 100).toStringAsFixed(0)}% - Acertos: $correctAnswers',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: isSmall ? 13 : isLarge ? 20 : 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Popup de resultado
          if (showResult)
            Center(
              child: AnimatedScale(
                scale: showResult ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isCorrect ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Text(
                    isCorrect ? 'Acertou! 🎉' : 'Errou! 😢',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          if (!loading && !showResult && questions.isNotEmpty && !quizFinished && currentQuestion < questions.length)
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
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class CustomProgressBar extends StatelessWidget {
  final double value;
  final double height;
  const CustomProgressBar({Key? key, required this.value, this.height = 28}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final progressWidth = width * value;
        return Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(color: Color(0xFF4DEAFF), width: 3), // azul claro
          ),
          child: Stack(
            children: [
              // Barra laranja
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: progressWidth,
                height: height,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8800), // laranja
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
              // Texto centralizado
              Center(
                child: Text(
                  '${(value * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
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