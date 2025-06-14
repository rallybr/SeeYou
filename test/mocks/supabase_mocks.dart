import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:postgrest/postgrest.dart';

@GenerateMocks([SupabaseClient])
class MockSupabaseClient extends Mock implements SupabaseClient {
  @override
  SupabaseQueryBuilder from(String table) {
    return MockSupabaseQueryBuilder();
  }
}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {
  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> select([String columns = '*']) {
    return MockPostgrestFilterBuilderList();
  }

  @override
  PostgrestFilterBuilder<Map<String, dynamic>> single() {
    return MockPostgrestFilterBuilderMap();
  }

  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> eq(String column, dynamic value) {
    return MockPostgrestFilterBuilderList();
  }

  @override
  PostgrestFilterBuilder<dynamic> insert(Object values, {bool? upsert, String? onConflict, bool? returning, bool? defaultToNull}) {
    return MockPostgrestFilterBuilderDynamic();
  }
}

class MockPostgrestFilterBuilderList extends Mock implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {
  @override
  Future<PostgrestResponse<List<Map<String, dynamic>>>> execute() async {
    return PostgrestResponse<List<Map<String, dynamic>>>(data: [], count: 0);
  }
}

class MockPostgrestFilterBuilderMap extends Mock implements PostgrestFilterBuilder<Map<String, dynamic>> {
  @override
  Future<PostgrestResponse<Map<String, dynamic>>> execute() async {
    return PostgrestResponse<Map<String, dynamic>>(data: {}, count: 0);
  }
}

class MockPostgrestFilterBuilderDynamic extends Mock implements PostgrestFilterBuilder<dynamic> {
  @override
  Future<PostgrestResponse<dynamic>> execute() async {
    return PostgrestResponse<dynamic>(data: null, count: 0);
  }
}

class MockPostgrestTransformBuilder extends Mock implements PostgrestTransformBuilder<Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>> execute() async => {};
} 