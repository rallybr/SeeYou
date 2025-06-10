import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/network/supabase_client.dart';

class VocationalQuestionService {
  final SupabaseClient _client = SupabaseService().client;

  Future<String> addQuestion({
    required String pergunta,
    required int ordem,
  }) async {
    final response = await _client.from('vocational_questions').insert({
      'pergunta': pergunta,
      'ordem': ordem,
    }).select('id').single();
    return response['id'] as String;
  }

  Future<void> addOption({
    required String questionId,
    required String texto,
    required String projectId,
  }) async {
    await _client.from('vocational_options').insert({
      'question_id': questionId,
      'texto': texto,
      'project_id': projectId,
    });
  }

  Future<List<Map<String, dynamic>>> getQuestionsWithOptions() async {
    final questions = await _client
        .from('vocational_questions')
        .select('id, ordem, pergunta, vocational_options(id, texto, project_id)')
        .order('ordem', ascending: true)
        .limit(12);
    return List<Map<String, dynamic>>.from(questions);
  }
} 