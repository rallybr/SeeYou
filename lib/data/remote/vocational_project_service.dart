import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/network/supabase_client.dart';

class VocationalProjectService {
  final SupabaseClient _client = SupabaseService().client;

  Future<void> addProject({
    required String nome,
    required String descricao,
    required String logoUrl,
    required String responsavelId,
  }) async {
    await _client.from('vocational_projects').insert({
      'nome': nome,
      'descricao': descricao,
      'logo_url': logoUrl,
      'responsavel_id': responsavelId,
    });
  }

  Future<List<Map<String, dynamic>>> getProjects() async {
    final response = await _client.from('vocational_projects').select();
    return List<Map<String, dynamic>>.from(response);
  }
} 