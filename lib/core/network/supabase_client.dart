import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  late final SupabaseClient client;

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal() {
    client = Supabase.instance.client;
  }
} 