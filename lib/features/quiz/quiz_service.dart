import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/network/supabase_client.dart';

class QuizService {
  final SupabaseClient _client = SupabaseService().client;

  Future<List<Map<String, dynamic>>> getQuizzes({String? categoryId}) async {
    var query = _client
        .from('quizzes')
        .select('id, title, category_id, championship_id, created_at')
        .eq('aprovado', true);
    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }
    final quizzes = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(quizzes);
  }

  Future<Map<String, dynamic>> getQuizWithQuestions(String quizId) async {
    final quiz = await _client
        .from('quizzes')
        .select('id, title, category_id, championship_id')
        .eq('id', quizId)
        .single();

    final questions = await _client
        .from('quiz_questions')
        .select('id, question_text, quiz_options(id, option_text, option_letter, is_correct)')
        .eq('quiz_id', quizId)
        .order('order', ascending: true);

    final List<Map<String, dynamic>> formattedQuestions = [];
    for (final q in questions) {
      final options = List<Map<String, dynamic>>.from(q['quiz_options']);
      options.sort((a, b) => (a['option_letter'] as String).compareTo(b['option_letter'] as String));
      final answerIndex = options.indexWhere((o) => o['is_correct'] == true);
      formattedQuestions.add({
        'id': q['id'],
        'question': q['question_text'],
        'options': options.map((o) => o['option_text'] as String).toList(),
        'optionIds': options.map((o) => o['id'] as String).toList(),
        'answer': answerIndex,
      });
    }

    return {
      'quiz': quiz,
      'questions': formattedQuestions,
    };
  }

  Future<void> submitAnswer({
    required String questionId,
    required String optionId,
    String? duelId,
    String? teamId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    final answerData = {
      'user_id': user.id,
      'question_id': questionId,
      'option_id': optionId,
      'answered_at': DateTime.now().toIso8601String(),
    };

    if (duelId != null) {
      answerData['duel_id'] = duelId;
    }

    if (teamId != null) {
      answerData['team_id'] = teamId;
    }

    await _client.from('quiz_answers').insert(answerData);
  }

  Future<Map<String, dynamic>> getQuizResults(String quizId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Usuário não autenticado');

    // Buscar total de questões do quiz
    final questions = await _client
        .from('quiz_questions')
        .select('id')
        .eq('quiz_id', quizId);
    final totalQuestions = questions.length;

    // Buscar respostas do usuário
    final answers = await _client
        .from('quiz_answers')
        .select('question_id, option_id, answered_at, quiz_options(is_correct)')
        .eq('user_id', user.id)
        .inFilter('question_id', questions.map((q) => q['id']).toList());

    int correctAnswers = 0;
    final answeredQuestions = <String>{};
    for (final answer in answers) {
      answeredQuestions.add(answer['question_id']);
      if (answer['quiz_options']?['is_correct'] == true) {
        correctAnswers++;
      }
    }

    return {
      'totalQuestions': totalQuestions,
      'answeredQuestions': answeredQuestions.length,
      'correctAnswers': correctAnswers,
      'score': totalQuestions > 0 ? (correctAnswers / totalQuestions) * 100 : 0,
    };
  }

  Future<List<Map<String, dynamic>>> getQuizRanking(String quizId) async {
    // Buscar total de questões do quiz
    final questions = await _client
        .from('quiz_questions')
        .select('id')
        .eq('quiz_id', quizId);
    final totalQuestions = questions.length;

    // Buscar todas as respostas dos usuários para esse quiz
    final answers = await _client
        .from('quiz_answers')
        .select('user_id, question_id, option_id, answered_at, quiz_options(is_correct), profiles(id, username, avatar_url)')
        .inFilter('question_id', questions.map((q) => q['id']).toList());

    // Agrupar por usuário
    final Map<String, Map<String, dynamic>> ranking = {};
    for (final answer in answers) {
      final user = answer['profiles'];
      final userId = user['id'];
      final userRanking = ranking.putIfAbsent(userId, () => {
        'user_id': userId,
        'username': user['username'],
        'avatar_url': user['avatar_url'],
        'correct_answers': 0,
        'wrong_answers': 0,
      });

      if (answer['quiz_options']?['is_correct'] == true) {
        userRanking['correct_answers'] += 1;
      } else {
        userRanking['wrong_answers'] += 1;
      }
    }

    final rankingList = ranking.values.toList();
    rankingList.sort((a, b) => (b['correct_answers'] as int).compareTo(a['correct_answers'] as int));

    return rankingList;
  }
} 