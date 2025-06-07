import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DueloQuizPage extends StatefulWidget {
  final String duelId;
  const DueloQuizPage({Key? key, required this.duelId}) : super(key: key);

  @override
  State<DueloQuizPage> createState() => _DueloQuizPageState();
}

class _DueloQuizPageState extends State<DueloQuizPage> {
  final _supabase = Supabase.instance.client;
  String? quizId;
  List<Map<String, dynamic>> questions = [];
  int currentQuestion = 0;
  int correctAnswers = 0;
  bool showResult = false;
  bool isCorrect = false;
  double progress = 0.0;
  bool loading = true;
  String? errorMsg;

  @override
  void initState() {
    super.initState();
    _fetchQuizAndQuestions();
  }

  Future<void> _fetchQuizAndQuestions() async {
    setState(() { loading = true; errorMsg = null; });
    try {
      // Buscar o quizId do duelo
      final duel = await _supabase
          .from('quiz_duels')
          .select('quiz_id')
          .eq('id', widget.duelId)
          .maybeSingle();
      quizId = duel?['quiz_id'];
      if (quizId == null) {
        setState(() { loading = false; errorMsg = 'Duelo não encontrado ou quiz_id ausente.'; });
        return;
      }
      // Buscar questões e opções
      final questoes = await _supabase
        .from('quiz_questions')
        .select('id, question_text, quiz_options(id, option_text, option_letter, is_correct)')
        .eq('quiz_id', quizId!)
        .order('order', ascending: true);
      if (questoes == null || questoes.isEmpty) {
        setState(() { loading = false; errorMsg = 'Nenhuma questão encontrada para este quiz.'; });
        return;
      }
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
      // Buscar respostas do usuário para esse duelo
      final user = _supabase.auth.currentUser;
      List<dynamic> respostas = [];
      if (user != null && loadedQuestions.isNotEmpty) {
        final questionIds = loadedQuestions.map((q) => q['id']).toList();
        respostas = await _supabase
          .from('quiz_answers')
          .select('question_id, option_id, quiz_options(is_correct)')
          .eq('user_id', user.id)
          .eq('duel_id', widget.duelId)
          .inFilter('question_id', questionIds);
      }
      // Calcular progresso e acertos
      int acertos = 0;
      final Set<String> respondidasIds = {};
      for (final r in respostas) {
        respondidasIds.add(r['question_id']);
        if (r['quiz_options']?['is_correct'] == true) {
          acertos++;
        }
      }
      int proxQuestao = 0;
      for (int i = 0; i < loadedQuestions.length; i++) {
        if (!respondidasIds.contains(loadedQuestions[i]['id'])) {
          proxQuestao = i;
          break;
        }
        if (i == loadedQuestions.length - 1) proxQuestao = i;
      }
      setState(() {
        questions = loadedQuestions;
        loading = false;
        correctAnswers = acertos;
        progress = loadedQuestions.isNotEmpty ? respondidasIds.length / loadedQuestions.length : 0.0;
        currentQuestion = proxQuestao;
      });
    } catch (e) {
      setState(() {
        loading = false;
        errorMsg = 'Erro ao carregar duelo: $e';
      });
    }
  }

  void _onOptionSelected(int index) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final question = questions[currentQuestion];
    final questionId = question['id'];
    final optionId = question['optionIds'][index];
    // Verificar se já respondeu essa questão neste duelo
    final existing = await _supabase
      .from('quiz_answers')
      .select()
      .eq('user_id', user.id)
      .eq('question_id', questionId)
      .eq('duel_id', widget.duelId)
      .maybeSingle();
    if (existing != null) {
      if (!mounted) return;
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
                'Você já respondeu essa questão neste duelo',
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
            'Cada duelo permite uma resposta por questão. Continue para as próximas!',
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
          ],
        ),
      );
      return;
    }
    // Salvar resposta
    await _supabase.from('quiz_answers').insert({
      'user_id': user.id,
      'question_id': questionId,
      'option_id': optionId,
      'duel_id': widget.duelId,
      'answered_at': DateTime.now().toIso8601String(),
    });
    final bool acertou = index == question['answer'];
    setState(() {
      showResult = true;
      isCorrect = acertou;
      if (acertou) correctAnswers++;
      progress = (currentQuestion + 1) / questions.length;
    });
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      showResult = false;
      if (currentQuestion < questions.length - 1) {
        currentQuestion++;
      }
    });
    // Se terminou, salva resultado do duelo
    if (currentQuestion == questions.length - 1) {
      final respostas = await _supabase
        .from('quiz_answers')
        .select('question_id, option_id, quiz_options(is_correct)')
        .eq('user_id', user.id)
        .eq('duel_id', widget.duelId)
        .order('answered_at', ascending: true);
      int acertos = 0;
      for (final r in respostas) {
        if (r['quiz_options']?['is_correct'] == true) {
          acertos++;
        }
      }
      await _supabase.from('quiz_duel_results').upsert({
        'duel_id': widget.duelId,
        'user_id': user.id,
        'score': acertos,
        'finished_at': DateTime.now().toIso8601String(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (errorMsg != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 18), textAlign: TextAlign.center),
          ),
        ),
      );
    }
    if (questions.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Nenhuma questão disponível para este duelo.')),
      );
    }
    final question = questions[currentQuestion];
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 650 || size.width < 350;
    final isLarge = size.width > 600;
    return Scaffold(
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 800),
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
          ),
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
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isSmall ? 12 : isLarge ? 36 : 24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xAA2D2EFF),
                          Color(0xAA7B2FF2),
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
                                        Color(0xAA2D2EFF),
                                        Color(0xAA7B2FF2),
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
                                  radius: isSmall ? 18 : isLarge ? 36 : 28,
                                  backgroundColor: const Color(0xFFFF7200),
                                  child: Text(
                                    letters[i],
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: isSmall ? 16 : isLarge ? 36 : 28,
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
        ],
      ),
    );
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
            border: Border.all(color: Color(0xFF4DEAFF), width: 3),
          ),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: progressWidth,
                height: height,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8800),
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
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