import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../feed/feed_page.dart';
import '../create_post/create_post_page.dart';
import '../feed/feed_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:seeyou/features/auth/widgets/profile_picture_picker.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../duel/historico_duelos_page.dart';
import '../duel/desafiar_usuario_page.dart';
import '../duel/notificacao_desafio_page.dart';
import '../duel/executar_duelo_page.dart';
import '../duel/duelo_quiz_page.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';

class ProfilePage extends StatefulWidget {
  final String? profileId; // Se nulo, mostra o perfil do logado
  const ProfilePage({Key? key, this.profileId}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? profile;
  bool loading = true;
  int _selectedIndex = 4;
  String? currentUserId;
  String? currentUserAvatarUrl;
  int postCount = 0;
  int followersCount = 0;
  int followingCount = 0;
  Map<String, dynamic>? _desafioPendente;
  String? _error;
  Map<String, dynamic>? _vocacionalAprovado;
  List<Map<String, dynamic>> _reflexoes = [];
  bool _verMaisReflexoes = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _fetchCurrentUserAvatar();
    _fetchStats();
    _verificarDesafioPendente();
    _fetchVocacionalAprovado();
    _fetchReflexoes();
  }

  Future<void> _fetchProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    currentUserId = user.id;
    final idToFetch = widget.profileId ?? user.id;
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', idToFetch)
          .maybeSingle();
      setState(() {
        profile = data;
        loading = false;
      });
      await _fetchStats();
    } catch (e) {
      setState(() {
        _error = 'Erro ao buscar perfil: $e';
        loading = false;
      });
    }
  }

  Future<void> _fetchCurrentUserAvatar() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final data = await Supabase.instance.client
        .from('profiles')
        .select('avatar_url')
        .eq('id', user.id)
        .maybeSingle();
    setState(() {
      currentUserAvatarUrl = data != null ? data['avatar_url'] as String? : null;
    });
  }

  Future<void> _fetchStats() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final idToFetch = widget.profileId ?? user.id;
    // Contar posts
    final posts = await Supabase.instance.client
        .from('posts')
        .select('id')
        .eq('user_id', idToFetch);
    // Contar seguidores
    final followers = await Supabase.instance.client
        .from('followers')
        .select('follower_user_id')
        .eq('followed_user_id', idToFetch);
    // Contar seguindo
    final following = await Supabase.instance.client
        .from('followers')
        .select('followed_user_id')
        .eq('follower_user_id', idToFetch);
    setState(() {
      postCount = posts.length;
      followersCount = followers.length;
      followingCount = following.length;
    });
  }

  Future<void> _verificarDesafioPendente() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('quiz_duels')
          .select()
          .eq('opponent_id', userId)
          .eq('status', 'pendente');
      Map<String, dynamic>? desafio;
      if (response != null && response is List && response.isNotEmpty) {
        desafio = response[0];
        // Buscar dados do desafiante
        final challenger = await _supabase
            .from('profiles')
            .select('id, username, avatar_url')
            .eq('id', desafio['challenger_id'])
            .maybeSingle();
        desafio['challenger'] = challenger;
      }
      if (mounted) {
        setState(() {
          _desafioPendente = desafio;
        });
      }
    } catch (e) {
      print('Erro ao verificar desafio pendente: $e');
    }
  }

  Future<void> _fetchVocacionalAprovado() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final idToFetch = widget.profileId ?? user.id;
    final data = await Supabase.instance.client
        .from('vocational_requests')
        .select('id, status, project_id, user_id, profiles(id, full_name, avatar_url), vocational_projects(id, nome, logo_url)')
        .eq('user_id', idToFetch)
        .eq('status', 'aprovado')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (mounted) {
      setState(() {
        _vocacionalAprovado = data;
      });
    }
  }

  Future<void> _fetchReflexoes() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final idToFetch = widget.profileId ?? user.id;
    final data = await Supabase.instance.client
        .from('reflexoes')
        .select()
        .eq('user_id', idToFetch)
        .order('ordem', ascending: true)
        .order('created_at', ascending: true);
    print('Reflexoes carregadas do Supabase:');
    for (var r in data) {
      print(r);
    }
    setState(() {
      _reflexoes = List<Map<String, dynamic>>.from(data);
    });
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const FeedPage()),
        (route) => false,
      );
    } else if (index == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CreatePostPage()),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF6A85F1),
                  Color(0xFFFBC2EB),
                  Color(0xFFF9F586),
                  Color(0xFFF68084),
                ],
              ),
            ),
          ),
          SafeArea(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : profile == null
                        ? const Center(child: Text('Perfil não encontrado'))
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                _ProfileHeader(profile: profile!),
                                if (profile != null && profile!['id'] != currentUserId)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: FollowButton(profileId: profile!['id']),
                                  ),
                                _ProfileStats(
                                  postCount: postCount,
                                  followersCount: followersCount,
                                  followingCount: followingCount,
                                ),
                                _ProfileBio(profile: profile!),
                                if (_desafioPendente != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Card(
                                      color: Colors.yellow[50],
                                      child: ListTile(
                                        leading: const Icon(Icons.sports_esports, color: Colors.orange),
                                        title: Text('Desafio de Quiz recebido de @${_desafioPendente!['challenger']['username']}'),
                                        subtitle: const Text('Você deseja aceitar ou rejeitar o desafio?'),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextButton(
                                              onPressed: () async {
                                                await _supabase.from('quiz_duels').update({
                                                  'status': 'em_andamento',
                                                }).eq('id', _desafioPendente!['id']);
                                                final duelId = _desafioPendente?['id'];
                                                final quizId = _desafioPendente?['quiz_id'];
                                                if (quizId != null && context.mounted) {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) => DueloQuizPage(duelId: duelId!),
                                                    ),
                                                  );
                                                }
                                                setState(() {
                                                  _desafioPendente = null;
                                                });
                                                _fetchProfile();
                                              },
                                              child: const Text('Aceitar'),
                                            ),
                                            TextButton(
                                              onPressed: () async {
                                                await _supabase.from('quiz_duels').update({
                                                  'status': 'rejeitado',
                                                }).eq('id', _desafioPendente!['id']);
                                                setState(() {
                                                  _desafioPendente = null;
                                                });
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Desafio rejeitado.')),
                                                  );
                                                }
                                                // Não navegue para ExecutarDueloPage aqui!
                                              },
                                              child: const Text('Rejeitar'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                _buildProfileActions(),
                                _ProfileHighlights(),
                                const Divider(height: 1),
                                _ProfileTabs(),
                                _DuelCarousel(profileId: profile!['id']),
                                if (_vocacionalAprovado != null && _vocacionalAprovado!['vocational_projects'] != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: MediaQuery.of(context).size.width * 0.92,
                                      ),
                                      child: Card(
                                        margin: const EdgeInsets.all(16),
                                        color: Colors.deepPurple[50],
                                        elevation: 6,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                        child: Padding(
                                          padding: const EdgeInsets.all(28),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  if (_vocacionalAprovado!['vocational_projects']?['logo_url'] != null &&
                                                      (_vocacionalAprovado!['vocational_projects']?['logo_url'] as String).isNotEmpty)
                                                    CircleAvatar(
                                                      radius: 28,
                                                      backgroundImage: NetworkImage(_vocacionalAprovado!['vocational_projects']['logo_url']),
                                                      backgroundColor: Colors.white,
                                                    ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      crossAxisAlignment: CrossAxisAlignment.center,
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            const Text(
                                                              'Me Identifiquei',
                                                              style: TextStyle(
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 22,
                                                                color: Colors.deepPurple,
                                                              ),
                                                              textAlign: TextAlign.center,
                                                            ),                                                            
                                                          ],
                                                        ),
                                                        const SizedBox(height: 8),
                                                        Text(
                                                          _vocacionalAprovado!['vocational_projects']?['nome'] ?? '',
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 16,
                                                          ),
                                                          textAlign: TextAlign.center,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  SizedBox(
                                                    width: 70,
                                                    height: 70,
                                                    child: Lottie.asset('assets/animations/happy_emoji.json', repeat: true),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.92,
                                    ),
                                    child: Card(
                                      margin: const EdgeInsets.all(16),
                                      color: Colors.transparent, // Mantém o fundo da timeline
                                      elevation: 0, // Sem sombra extra
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                      child: const _YouthTimeline(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white.withOpacity(0.95),
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          const BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Buscar'),
          const BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), label: 'Novo'),
          const BottomNavigationBarItem(icon: Icon(Icons.ondemand_video), label: 'Reels'),
          BottomNavigationBarItem(
            icon: GestureDetector(
              onTap: () {
                // Se já está no seu perfil, não faz nada
                if (profile != null && profile!['id'] == currentUserId) return;
                // Volta para o seu próprio perfil
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                  (route) => false,
                );
              },
              child: currentUserAvatarUrl != null && currentUserAvatarUrl!.isNotEmpty
                  ? CircleAvatar(radius: 12, backgroundImage: NetworkImage(currentUserAvatarUrl!))
                  : const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 16)),
            ),
            label: 'Perfil',
          ),
        ],
      ),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(68),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Perfil', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.black.withOpacity(0.6),
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                if (_desafioPendente != null)
                  IconButton(
                    icon: const Icon(Icons.sports_esports),
                    tooltip: 'Desafio Pendente',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NotificacaoDesafioPage(
                            desafio: _desafioPendente!,
                            desafiante: _desafioPendente!['challenger'],
                          ),
                        ),
                      ).then((aceito) {
                        if (aceito == true) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DueloQuizPage(duelId: _desafioPendente!['id']),
                            ),
                          );
                        }
                        _verificarDesafioPendente();
                      });
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    Navigator.of(context).pushNamed('/settings');
                  },
                ),
              ],
            ),
            Container(
              height: 2,
              width: double.infinity,
              color: Colors.white,
            ),
            Container(
              height: 10,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF2D2EFF), // azul
                    Color(0xFF7B2FF2), // roxo
                    Color(0xFFE94057), // vermelho
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26, // sombra bem suave
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileActions() {
    final isOtherUser = profile != null && profile!['id'] != null && profile!['id'] != currentUserId;
    final isOwnProfile = profile != null && profile!['id'] == currentUserId;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (isOwnProfile) ...[
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).pushNamed('/vocational_test');
                },
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF2D2EFF),
                        Color(0xFF7B2FF2),
                        Color(0xFFE94057),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Vocacional',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pushNamed('/bible_quiz');
              },
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF2D2EFF),
                      Color(0xFF7B2FF2),
                      Color(0xFFE94057),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Quiz',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const HistoricoDuelosPage(),
                  ),
                );
              },
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF2D2EFF),
                      Color(0xFF7B2FF2),
                      Color(0xFFE94057),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Duelos',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
          if (isOtherUser) ...[
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final userId = Supabase.instance.client.auth.currentUser?.id;
                  final targetId = profile?['id'];
                  if (userId == null || targetId == null) return;
                  // Buscar o quiz padrão aprovado
                  final quiz = await Supabase.instance.client
                      .from('quizzes')
                      .select('id')
                      .eq('aprovado', true)
                      .order('created_at', ascending: false)
                      .limit(1)
                      .maybeSingle();
                  final quizId = quiz?['id'];
                  if (quizId == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nenhum quiz padrão disponível!')),
                      );
                    }
                    return;
                  }
                  // Verifica se já existe um confronto entre os dois usuários para o mesmo quiz
                  final existing = await Supabase.instance.client
                    .from('quiz_duels')
                    .select()
                    .or('and(challenger_id.eq.$userId,opponent_id.eq.$targetId),and(challenger_id.eq.$targetId,opponent_id.eq.$userId)')
                    .eq('quiz_id', quizId)
                    .inFilter('status', ['pendente', 'em_andamento', 'aceito']);
                  if (existing != null && existing.isNotEmpty) {
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          backgroundColor: Colors.white,
                          title: Row(
                            children: const [
                              Icon(Icons.warning_amber_rounded, color: Color(0xFFE94057), size: 32),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Desafio já existe',
                                  style: TextStyle(
                                    color: Color(0xFF2D2EFF),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          content: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Já existe um desafio em andamento entre vocês! Aguarde o término do desafio atual para enviar outro.',
                              style: TextStyle(fontSize: 16, color: Colors.black87),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Color(0xFF2D2EFF),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    }
                    return;
                  }
                  // Cria o desafio
                  final response = await Supabase.instance.client.from('quiz_duels').insert({
                    'challenger_id': userId,
                    'opponent_id': targetId,
                    'quiz_id': quizId,
                    'status': 'pendente',
                    'created_at': DateTime.now().toIso8601String(),
                  }).select().single();
                  // Cria notificação para o usuário desafiado
                  await Supabase.instance.client.from('notifications').insert({
                    'user_id': targetId,
                    'type': 'quiz_duel',
                    'duel_id': response['id'],
                    'created_at': DateTime.now().toIso8601String(),
                    'read': false,
                  });
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        backgroundColor: Colors.white,
                        title: Row(
                          children: const [
                            Icon(Icons.check_circle, color: Color(0xFF2D2EFF), size: 32),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Desafio enviado!',
                                style: TextStyle(
                                  color: Color(0xFF2D2EFF),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        content: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'O desafio foi enviado com sucesso! Aguarde a resposta do outro usuário.',
                            style: TextStyle(fontSize: 16, color: Colors.black87),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Color(0xFF2D2EFF),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                child: const Text('Desafiar'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (profile?['bio'] != null && profile!['bio'].toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              profile!['bio'],
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        if (_desafioPendente != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.notifications_active),
                title: const Text('Desafio Pendente'),
                subtitle: Text('Você tem um desafio pendente de ${_desafioPendente!['challenger_username']}'),
                trailing: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DueloQuizPage(duelId: _desafioPendente!['id']),
                      ),
                    );
                  },
                  child: const Text('Responder'),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> showReflexaoDialog({Map<String, dynamic>? reflexao, int? ordem}) async {
    final isEdit = reflexao != null;
    final controller = TextEditingController(text: reflexao?['conteudo'] ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEdit ? 'Editar Reflexão' : 'Nova Reflexão'),
          content: TextField(
            controller: controller,
            maxLength: 600,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Digite sua reflexão... (máx. 600 caracteres)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) return;
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
    if (result != null && result.isNotEmpty) {
      await saveReflexao(result, ordem: ordem, id: reflexao?['id']);
      await _fetchReflexoes();
      if (mounted) setState(() {}); // força rebuild para atualizar timeline
    }
  }

  Future<void> saveReflexao(String conteudo, {int? ordem, String? id}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    if (id != null) {
      // update
      await Supabase.instance.client
          .from('reflexoes')
          .update({'conteudo': conteudo, 'ordem': ordem ?? 0})
          .eq('id', id);
    } else {
      // insert
      await Supabase.instance.client.from('reflexoes').insert({
        'user_id': user.id,
        'conteudo': conteudo,
        'ordem': ordem ?? 0,
      });
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _ProfileHeader({required this.profile});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 38,
            backgroundImage: profile['avatar_url'] != null && profile['avatar_url'].toString().isNotEmpty
                ? NetworkImage(profile['avatar_url'])
                : null,
            child: (profile['avatar_url'] == null || profile['avatar_url'].toString().isEmpty)
                ? const Icon(Icons.person, size: 38)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(profile['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    const SizedBox(width: 6),
                    if ((profile['username'] ?? '').isNotEmpty)
                      const Icon(Icons.verified, color: Colors.blue, size: 18),
                    const Spacer(),
                    _ProfileMenuButton(),
                  ],
                ),
                const SizedBox(height: 4),
                Text(profile['full_name'] ?? '', style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuButton extends StatelessWidget {
  Future<String?> _getNivel() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    final data = await Supabase.instance.client
        .from('profiles')
        .select('nivel')
        .eq('id', user.id)
        .maybeSingle();
    return data != null ? data['nivel'] as String? : null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getNivel(),
      builder: (context, snapshot) {
        final nivel = snapshot.data;
        final podeVerDashboard = nivel == 'admin' || nivel == 'editor' || nivel == 'moderador';
        return PopupMenuButton<String>(
          icon: const Icon(Icons.menu, color: Color(0xFF2D2EFF), size: 30),
          color: Colors.white.withOpacity(0.97),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 12,
          itemBuilder: (context) => [
            if (podeVerDashboard)
              PopupMenuItem<String>(
                value: 'dashboard',
                child: Row(
                  children: const [
                    Icon(Icons.dashboard, color: Color(0xFF2D2EFF)),
                    SizedBox(width: 12),
                    Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                children: const [
                  Icon(Icons.edit, color: Color(0xFF7B2FF2)),
                  SizedBox(width: 12),
                  Text('Editar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'logout',
              child: Row(
                children: const [
                  Icon(Icons.logout, color: Color(0xFFE94057)),
                  SizedBox(width: 12),
                  Text('Logout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ],
          onSelected: (value) async {
            if (value == 'dashboard') {
              Navigator.of(context).pushNamed('/admin');
            } else if (value == 'logout') {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            } else if (value == 'edit') {
              // Abrir modal de edição de perfil
              final profileState = context.findAncestorStateOfType<_ProfilePageState>();
              if (profileState != null && profileState.profile != null) {
                showDialog(
                  context: context,
                  builder: (_) => EditProfileDialog(profile: profileState.profile!),
                ).then((result) {
                  if (result == true) {
                    profileState._fetchProfile();
                  }
                });
              }
            }
          },
        );
      },
    );
  }
}

class _ProfileStats extends StatelessWidget {
  final int postCount;
  final int followersCount;
  final int followingCount;
  const _ProfileStats({Key? key, required this.postCount, required this.followersCount, required this.followingCount}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatColumn(postCount.toString(), 'posts'),
          _StatColumn(_formatNumber(followersCount), 'seguidores'),
          _StatColumn(_formatNumber(followingCount), 'seguindo'),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) {
      return (n / 1000000).toStringAsFixed(1).replaceAll('.', ',') + ' mi';
    } else if (n >= 1000) {
      return (n / 1000).toStringAsFixed(1).replaceAll('.', ',') + ' mil';
    } else {
      return n.toString();
    }
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;
  const _StatColumn(this.value, this.label, {Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}

class _ProfileBio extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _ProfileBio({required this.profile});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((profile['bio'] ?? '').isNotEmpty)
            Text(profile['bio'], style: const TextStyle(fontWeight: FontWeight.bold)),
          if ((profile['website'] ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(profile['website'], style: const TextStyle(color: Colors.blue)),
            ),
        ],
      ),
    );
  }
}

class _ProfileHighlights extends StatefulWidget {
  @override
  State<_ProfileHighlights> createState() => _ProfileHighlightsState();
}

class _ProfileHighlightsState extends State<_ProfileHighlights> {
  late Future<List<Map<String, dynamic>>> _followersFuture;

  @override
  void initState() {
    super.initState();
    _followersFuture = _fetchFollowers();
  }

  Future<List<Map<String, dynamic>>> _fetchFollowers() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];
    final data = await Supabase.instance.client
        .from('followers')
        .select('follower_user_id, profiles:follower_user_id(id, username, avatar_url)')
        .eq('followed_user_id', user.id)
        .order('created_at', ascending: false);
    // Retorna lista de perfis dos seguidores
    return List<Map<String, dynamic>>.from(data.map((f) => f['profiles'] ?? {}));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _followersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final followers = snapshot.data ?? [];
          if (followers.isEmpty) {
            return const Center(child: Text('Nenhum seguidor ainda.'));
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: followers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final f = followers[i];
              return GestureDetector(
                onTap: () {
                  if (f['id'] != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProfilePage(profileId: f['id']),
                      ),
                    );
                  }
                },
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: f['avatar_url'] != null && f['avatar_url'].toString().isNotEmpty
                          ? NetworkImage(f['avatar_url'])
                          : null,
                      child: (f['avatar_url'] == null || f['avatar_url'].toString().isEmpty)
                          ? const Icon(Icons.person, size: 32)
                          : null,
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 60,
                      child: Text(
                        f['username'] ?? '',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProfileTabs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const MessageListModal(),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black54, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(3),
              child: const Icon(Icons.chat_bubble_outline, size: 22),
            ),
          ),
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const VideoListModal(),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black54, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(3),
              child: const Icon(Icons.video_collection_outlined, size: 22),
            ),
          ),
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const MusicListModal(),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black54, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(3),
              child: const Icon(Icons.library_music, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class VideoListModal extends StatefulWidget {
  const VideoListModal({Key? key}) : super(key: key);

  @override
  State<VideoListModal> createState() => _VideoListModalState();
}

class _VideoListModalState extends State<VideoListModal> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String? _tocandoLink;
  YoutubePlayerController? _playerController;

  @override
  void initState() {
    super.initState();
    _fetchVideos();
    _searchController.addListener(_onSearch);
  }

  void _tocarVideo(String link) {
    if (_tocandoLink == link) return;
    final videoId = YoutubePlayer.convertUrlToId(link) ?? '';
    setState(() {
      _tocandoLink = link;
      _playerController?.dispose();
      _playerController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
      );
    });
  }

  @override
  void dispose() {
    _playerController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchVideos() async {
    setState(() => _loading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final data = await Supabase.instance.client
        .from('videos')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    setState(() {
      _videos = List<Map<String, dynamic>>.from(data);
      _filtered = _videos;
      _loading = false;
    });
  }

  void _onSearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _videos.where((v) => v['titulo'].toString().toLowerCase().contains(query)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(top: Radius.circular(32));
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF7B2FF2), Color(0xFFF357A8), Color(0xFFF2A93B)],
            ),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4))],
          ),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 6,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white54,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar vídeo...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF7B2FF2)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.95),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _filtered.isEmpty
                        ? const Center(child: Text('Nenhum vídeo encontrado.', style: TextStyle(color: Colors.white, fontSize: 18)))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _filtered.length,
                            itemBuilder: (context, i) {
                              final v = _filtered[i];
                              final isTocando = _tocandoLink == v['link'] && _playerController != null;
                              return Column(
                                children: [
                                  Card(
                                    color: Colors.white.withOpacity(0.93),
                                    margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    child: ListTile(
                                      leading: const Icon(Icons.video_collection_outlined, color: Color(0xFF7B2FF2), size: 32),
                                      title: Text(v['titulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text('${v['autor'] ?? ''}  |  ${v['categoria'] ?? ''}'),
                                      trailing: IconButton(
                                        icon: Icon(
                                          isTocando ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                          color: const Color(0xFFF357A8),
                                          size: 32,
                                        ),
                                        onPressed: () {
                                          if (isTocando) {
                                            _playerController?.pause();
                                            setState(() => _tocandoLink = null);
                                          } else {
                                            _tocarVideo(v['link'] ?? '');
                                          }
                                        },
                                      ),
                                      onTap: () {
                                        if (isTocando) {
                                          _playerController?.pause();
                                          setState(() => _tocandoLink = null);
                                        } else {
                                          _tocarVideo(v['link'] ?? '');
                                        }
                                      },
                                    ),
                                  ),
                                  if (isTocando)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                                      child: YoutubePlayer(
                                        controller: _playerController!,
                                        showVideoProgressIndicator: true,
                                        progressIndicatorColor: Colors.pinkAccent,
                                        width: double.infinity,
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MessageListModal extends StatefulWidget {
  const MessageListModal({Key? key}) : super(key: key);

  @override
  State<MessageListModal> createState() => _MessageListModalState();
}

class _MessageListModalState extends State<MessageListModal> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _mensagens = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String? _tocandoLink;
  YoutubePlayerController? _playerController;

  @override
  void initState() {
    super.initState();
    _fetchMensagens();
    _searchController.addListener(_onSearch);
  }

  void _tocarMensagem(String link) {
    if (_tocandoLink == link) return;
    final isYoutube = YoutubePlayer.convertUrlToId(link) != null;
    if (isYoutube) {
      final videoId = YoutubePlayer.convertUrlToId(link) ?? '';
      setState(() {
        _tocandoLink = link;
        _playerController?.dispose();
        _playerController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
        );
      });
    } else {
      setState(() {
        _tocandoLink = link;
        _playerController?.dispose();
        _playerController = null;
      });
    }
  }

  @override
  void dispose() {
    _playerController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMensagens() async {
    setState(() => _loading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final data = await Supabase.instance.client
        .from('mensagens')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    setState(() {
      _mensagens = List<Map<String, dynamic>>.from(data);
      _filtered = _mensagens;
      _loading = false;
    });
  }

  void _onSearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _mensagens.where((m) => m['titulo'].toString().toLowerCase().contains(query)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(top: Radius.circular(32));
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF7B2FF2), Color(0xFFF357A8), Color(0xFFF2A93B)],
            ),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4))],
          ),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 6,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white54,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar mensagem...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF7B2FF2)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.95),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _filtered.isEmpty
                        ? const Center(child: Text('Nenhuma mensagem encontrada.', style: TextStyle(color: Colors.white, fontSize: 18)))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _filtered.length,
                            itemBuilder: (context, i) {
                              final m = _filtered[i];
                              final isTocando = _tocandoLink == m['link'];
                              final isYoutube = YoutubePlayer.convertUrlToId(m['link'] ?? '') != null;
                              final isTexto = !isYoutube && (m['link'] ?? '').isNotEmpty && !(m['link'] ?? '').contains('http');
                              return Column(
                                children: [
                                  Card(
                                    color: Colors.white.withOpacity(0.93),
                                    margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    child: ListTile(
                                      leading: const Icon(Icons.chat_bubble_outline, color: Color(0xFF7B2FF2), size: 32),
                                      title: Text(m['titulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text('${m['autor'] ?? ''}  |  ${m['categoria'] ?? ''}'),
                                      trailing: IconButton(
                                        icon: Icon(
                                          isTocando ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                          color: const Color(0xFFF357A8),
                                          size: 32,
                                        ),
                                        onPressed: () {
                                          if (isTocando) {
                                            _playerController?.pause();
                                            setState(() => _tocandoLink = null);
                                          } else {
                                            _tocarMensagem(m['link'] ?? '');
                                          }
                                        },
                                      ),
                                      onTap: () {
                                        if (isTocando) {
                                          _playerController?.pause();
                                          setState(() => _tocandoLink = null);
                                        } else {
                                          _tocarMensagem(m['link'] ?? '');
                                        }
                                      },
                                    ),
                                  ),
                                  if (isTocando && isYoutube && _playerController != null)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                                      child: YoutubePlayer(
                                        controller: _playerController!,
                                        showVideoProgressIndicator: true,
                                        progressIndicatorColor: Colors.pinkAccent,
                                        width: double.infinity,
                                      ),
                                    ),
                                  if (isTocando && isTexto)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(m['link'], style: const TextStyle(fontSize: 16)),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MusicListModal extends StatefulWidget {
  const MusicListModal({Key? key}) : super(key: key);

  @override
  State<MusicListModal> createState() => _MusicListModalState();
}

class _MusicListModalState extends State<MusicListModal> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _musicas = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String? _tocandoLink;
  YoutubePlayerController? _playerController;

  @override
  void initState() {
    super.initState();
    _fetchMusicas();
    _searchController.addListener(_onSearch);
  }

  void _tocarMusica(String link) {
    if (_tocandoLink == link) return; // já está tocando
    final videoId = YoutubePlayer.convertUrlToId(link) ?? '';
    setState(() {
      _tocandoLink = link;
      _playerController?.dispose();
      _playerController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
      );
    });
  }

  @override
  void dispose() {
    _playerController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMusicas() async {
    setState(() => _loading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final data = await Supabase.instance.client
        .from('musicas')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    setState(() {
      _musicas = List<Map<String, dynamic>>.from(data);
      _filtered = _musicas;
      _loading = false;
    });
  }

  void _onSearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _musicas.where((m) => m['titulo'].toString().toLowerCase().contains(query)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(top: Radius.circular(32));
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF7B2FF2), Color(0xFFF357A8), Color(0xFFF2A93B)],
            ),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4))],
          ),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 6,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white54,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar música...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF7B2FF2)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.95),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _filtered.isEmpty
                        ? const Center(child: Text('Nenhuma música encontrada.', style: TextStyle(color: Colors.white, fontSize: 18)))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _filtered.length,
                            itemBuilder: (context, i) {
                              final m = _filtered[i];
                              final isTocando = _tocandoLink == m['link'] && _playerController != null;
                              return Column(
                                children: [
                                  Card(
                                    color: Colors.white.withOpacity(0.93),
                                    margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    child: ListTile(
                                      leading: const Icon(Icons.library_music, color: Color(0xFF7B2FF2), size: 32),
                                      title: Text(m['titulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text('${m['autor'] ?? ''}  |  ${m['categoria'] ?? ''}'),
                                      trailing: IconButton(
                                        icon: Icon(
                                          isTocando ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                          color: const Color(0xFFF357A8),
                                          size: 32,
                                        ),
                                        onPressed: () {
                                          if (isTocando) {
                                            _playerController?.pause();
                                            setState(() => _tocandoLink = null);
                                          } else {
                                            _tocarMusica(m['link'] ?? '');
                                          }
                                        },
                                      ),
                                      onTap: () {
                                        if (isTocando) {
                                          _playerController?.pause();
                                          setState(() => _tocandoLink = null);
                                        } else {
                                          _tocarMusica(m['link'] ?? '');
                                        }
                                      },
                                    ),
                                  ),
                                  if (isTocando)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                                      child: YoutubePlayer(
                                        controller: _playerController!,
                                        showVideoProgressIndicator: true,
                                        progressIndicatorColor: Colors.pinkAccent,
                                        width: double.infinity,
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DuelCarousel extends StatefulWidget {
  final String profileId;
  const _DuelCarousel({required this.profileId});

  @override
  State<_DuelCarousel> createState() => _DuelCarouselState();
}

class _DuelCarouselState extends State<_DuelCarousel> {
  final _supabase = Supabase.instance.client;
  final PageController _pageController = PageController(viewportFraction: 0.92);
  Timer? _autoplayTimer;
  List<Map<String, dynamic>> _duels = [];
  Map<String, Map<String, dynamic>> _results = {};
  Map<String, int> _totalQuestions = {};
  Map<String, int> _challengerAnswers = {};
  Map<String, int> _opponentAnswers = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchDuels();
    _startAutoplay();
  }

  void _startAutoplay() {
    _autoplayTimer?.cancel();
    _autoplayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_duels.isEmpty || !_pageController.hasClients) return;
      int currentPage = _pageController.page?.round() ?? 0;
      int nextPage = currentPage + 1;
      if (nextPage >= _duels.length) {
        _pageController.jumpToPage(0);
      } else {
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoplayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchDuels() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    // Busca até 10 duelos ativos envolvendo o usuário
    final duels = await _supabase
        .from('quiz_duels')
        .select('*, challenger:challenger_id(id, username, avatar_url), opponent:opponent_id(id, username, avatar_url)')
        .or('challenger_id.eq.${widget.profileId},opponent_id.eq.${widget.profileId}')
        .inFilter('status', ['em_andamento', 'aceito'])
        .order('created_at', ascending: false)
        .limit(10);
    // Para cada duelo, buscar resultados dos dois usuários, total de questões e respostas de cada usuário
    final resultsMap = <String, Map<String, dynamic>>{};
    final totalQuestionsMap = <String, int>{};
    final challengerAnswersMap = <String, int>{};
    final opponentAnswersMap = <String, int>{};
    for (final duel in duels) {
      final duelId = duel['id'];
      final challengerId = duel['challenger_id'];
      final opponentId = duel['opponent_id'];
      final quizId = duel['quiz_id'];
      // Resultados
      final results = await _supabase
          .from('quiz_duel_results')
          .select('user_id, score')
          .eq('duel_id', duelId);
      for (final r in results) {
        resultsMap['${duelId}_${r['user_id']}'] = r;
      }
      // Total de questões do quiz
      int totalQuestions = 0;
      if (quizId != null) {
        final questoes = await _supabase
          .from('quiz_questions')
          .select('id')
          .eq('quiz_id', quizId);
        totalQuestions = questoes.length;
      }
      totalQuestionsMap[duelId] = totalQuestions;
      // Total de respostas do challenger
      int challengerAnswers = 0;
      if (challengerId != null) {
        final respostas = await _supabase
          .from('quiz_answers')
          .select('id')
          .eq('user_id', challengerId)
          .eq('duel_id', duelId);
        challengerAnswers = respostas.length;
      }
      challengerAnswersMap[duelId] = challengerAnswers;
      // Total de respostas do opponent
      int opponentAnswers = 0;
      if (opponentId != null) {
        final respostas = await _supabase
          .from('quiz_answers')
          .select('id')
          .eq('user_id', opponentId)
          .eq('duel_id', duelId);
        opponentAnswers = respostas.length;
      }
      opponentAnswersMap[duelId] = opponentAnswers;
    }
    setState(() {
      _duels = List<Map<String, dynamic>>.from(duels);
      _results = resultsMap;
      _totalQuestions = totalQuestionsMap;
      _challengerAnswers = challengerAnswersMap;
      _opponentAnswers = opponentAnswersMap;
      _loading = false;
    });
    _startAutoplay(); // Reinicia autoplay ao atualizar duelos
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_duels.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('Nenhum duelo em andamento.')),
      );
    }
    final screenHeight = MediaQuery.of(context).size.height;
    final cardHeight = screenHeight * 0.38;
    final double stackTopOffset = cardHeight / 2;
    final double stackBottomOffset = cardHeight / 2;
    return SizedBox(
      height: cardHeight.clamp(240, 340),
      child: PageView.builder(
        itemCount: _duels.length,
        controller: _pageController,
        itemBuilder: (context, index) {
          final duel = _duels[index];
          final duelId = duel['id'];
          final challengerId = duel['challenger_id'];
          final opponentId = duel['opponent_id'];
          final challengerResult = _results['${duelId}_${challengerId}'];
          final opponentResult = _results['${duelId}_${opponentId}'];
          final totalQuestions = _totalQuestions[duelId];
          final challengerAnswers = _challengerAnswers[duelId];
          final opponentAnswers = _opponentAnswers[duelId];
          return _DuelCardView(
            duel: duel,
            challengerResult: challengerResult,
            opponentResult: opponentResult,
            totalQuestions: totalQuestions,
            challengerAnswers: challengerAnswers,
            opponentAnswers: opponentAnswers,
          );
        },
      ),
    );
  }
}

class _DuelCardView extends StatelessWidget {
  final Map<String, dynamic> duel;
  final Map<String, dynamic>? challengerResult;
  final Map<String, dynamic>? opponentResult;
  final int? totalQuestions;
  final int? challengerAnswers;
  final int? opponentAnswers;
  const _DuelCardView({required this.duel, this.challengerResult, this.opponentResult, this.totalQuestions, this.challengerAnswers, this.opponentAnswers});

  @override
  Widget build(BuildContext context) {
    final challenger = duel['challenger'] ?? {};
    final opponent = duel['opponent'] ?? {};
    final challengerScore = (challengerResult?['score'] ?? 0) as int;
    final opponentScore = (opponentResult?['score'] ?? 0) as int;
    final totalQ = totalQuestions ?? 0;
    final challengerProgress = (totalQ > 0) ? (challengerScore / totalQ).clamp(0.0, 1.0) : 0.0;
    final opponentProgress = (totalQ > 0) ? (opponentScore / totalQ).clamp(0.0, 1.0) : 0.0;
    const barHeight = 14.0;
    const barRadius = Radius.circular(8);
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Challenger
                Expanded(
                  child: Column(
                    children: [
                      CircleAvatar(
                        backgroundImage: challenger['avatar_url'] != null ? NetworkImage(challenger['avatar_url']) : null,
                        radius: 28,
                        child: challenger['avatar_url'] == null ? Icon(Icons.person, size: 32) : null,
                      ),
                      const SizedBox(height: 6),
                      Text('@${challenger['username'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      ClipRRect(
                        borderRadius: BorderRadius.all(barRadius),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: challengerProgress),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeInOut,
                          builder: (context, value, child) => Container(
                            height: barHeight,
                            width: double.infinity,
                            color: Colors.grey[300],
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: value,
                                child: Container(
                                  height: barHeight,
                                  decoration: const BoxDecoration(
                                    color: Colors.deepPurple,
                                    borderRadius: BorderRadius.all(barRadius),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${challengerScore} de $totalQ', style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 2),
                      Text('Pontuação', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                      Text('$challengerScore pontos', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Icon(Icons.menu_book, size: 38, color: Colors.black87),
                const SizedBox(width: 18),
                // Opponent
                Expanded(
                  child: Column(
                    children: [
                      CircleAvatar(
                        backgroundImage: opponent['avatar_url'] != null ? NetworkImage(opponent['avatar_url']) : null,
                        radius: 28,
                        child: opponent['avatar_url'] == null ? Icon(Icons.person, size: 32) : null,
                      ),
                      const SizedBox(height: 6),
                      Text('@${opponent['username'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      ClipRRect(
                        borderRadius: BorderRadius.all(barRadius),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: opponentProgress),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeInOut,
                          builder: (context, value, child) => Container(
                            height: barHeight,
                            width: double.infinity,
                            color: Colors.grey[300],
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: value,
                                child: Container(
                                  height: barHeight,
                                  decoration: const BoxDecoration(
                                    color: Colors.deepPurple,
                                    borderRadius: BorderRadius.all(barRadius),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${opponentScore} de $totalQ', style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 2),
                      Text('Pontuação', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                      Text('$opponentScore pontos', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              challengerScore > opponentScore
                  ? '@${challenger['username']} está vencendo!'
                  : opponentScore > challengerScore
                      ? '@${opponent['username']} está vencendo!'
                      : 'Empate!',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final duelId = duel['id'];
                if (duelId != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DueloQuizPage(duelId: duelId),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              child: const Text('Continuar Quiz'),
            ),
          ],
        ),
      ),
    );
  }
}

class FollowButton extends StatefulWidget {
  final String profileId;
  const FollowButton({required this.profileId, Key? key}) : super(key: key);

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  bool? _isFollowing;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _checkFollowing();
  }

  Future<void> _checkFollowing() async {
    final result = await isFollowing(widget.profileId);
    setState(() => _isFollowing = result);
  }

  Future<void> _toggleFollow() async {
    setState(() => _loading = true);
    if (_isFollowing == true) {
      await unfollowUser(widget.profileId);
    } else {
      await followUser(widget.profileId);
    }
    await _checkFollowing();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isFollowing == null) {
      return const SizedBox.shrink();
    }
    return ElevatedButton(
      onPressed: _loading ? null : _toggleFollow,
      child: Text(_isFollowing! ? 'Deixar de seguir' : 'Seguir'),
    );
  }
}

Future<void> followUser(String followedUserId) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return;
  await Supabase.instance.client.from('followers').insert({
    'followed_user_id': followedUserId,
    'follower_user_id': user.id,
  });
}

Future<void> unfollowUser(String followedUserId) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return;
  await Supabase.instance.client
      .from('followers')
      .delete()
      .eq('followed_user_id', followedUserId)
      .eq('follower_user_id', user.id);
}

Future<bool> isFollowing(String followedUserId) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return false;
  final data = await Supabase.instance.client
      .from('followers')
      .select()
      .eq('followed_user_id', followedUserId)
      .eq('follower_user_id', user.id)
      .maybeSingle();
  return data != null;
}

class EditProfileDialog extends StatefulWidget {
  final Map<String, dynamic> profile;
  const EditProfileDialog({required this.profile, Key? key}) : super(key: key);

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController usernameController;
  late TextEditingController fullNameController;
  late TextEditingController avatarUrlController;
  late TextEditingController bioController;
  late TextEditingController websiteController;
  late TextEditingController estadoIdController;
  late TextEditingController dataNascController;
  late TextEditingController emailController;
  bool _saving = false;
  File? _avatarImage;
  bool _uploadingAvatar = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    usernameController = TextEditingController(text: widget.profile['username'] ?? '');
    fullNameController = TextEditingController(text: widget.profile['full_name'] ?? '');
    avatarUrlController = TextEditingController(text: widget.profile['avatar_url'] ?? '');
    bioController = TextEditingController(text: widget.profile['bio'] ?? '');
    websiteController = TextEditingController(text: widget.profile['website'] ?? '');
    estadoIdController = TextEditingController(text: widget.profile['estado_id']?.toString() ?? '');
    dataNascController = TextEditingController(text: widget.profile['data_nasc'] ?? '');
    emailController = TextEditingController(text: widget.profile['email'] ?? '');
  }

  @override
  void dispose() {
    usernameController.dispose();
    fullNameController.dispose();
    avatarUrlController.dispose();
    bioController.dispose();
    websiteController.dispose();
    estadoIdController.dispose();
    dataNascController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selecionar foto'),
        content: const Text('Escolha a origem da foto de perfil:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('Câmera'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('Galeria'),
          ),
        ],
      ),
    );
    if (source == null) return;
    final picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      setState(() {
        _avatarImage = File(picked.path);
        _uploadingAvatar = true;
      });
      await _uploadAvatar(File(picked.path));
      setState(() {
        _uploadingAvatar = false;
      });
    }
  }

  Future<void> _uploadAvatar(File file) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final fileExt = path.extension(file.path);
    final fileName = 'avatar_$userId$fileExt';
    final storage = Supabase.instance.client.storage;
    final bucket = storage.from('avatar');
    try {
      final res = await bucket.upload(
        fileName,
        file,
        fileOptions: const FileOptions(upsert: true),
      );
      if (res != null && res is String) {
        final url = bucket.getPublicUrl(fileName);
        setState(() {
          avatarUrlController.text = url;
        });
      } else {
        _showUploadError();
      }
    } catch (e) {
      _showUploadError();
    } finally {
      setState(() {
        _uploadingAvatar = false;
      });
    }
  }

  void _showUploadError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Erro ao fazer upload da foto. Tente novamente.')),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final updates = {
      'id': widget.profile['id'],
      'username': usernameController.text.trim(),
      'full_name': fullNameController.text.trim(),
      'avatar_url': avatarUrlController.text.trim(),
      'bio': bioController.text.trim(),
      'website': websiteController.text.trim(),
      'estado_id': int.tryParse(estadoIdController.text.trim()),
      'data_nasc': dataNascController.text.trim().isEmpty ? null : dataNascController.text.trim(),
      'email': emailController.text.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    await Supabase.instance.client.from('profiles').upsert(updates);
    setState(() => _saving = false);
    if (context.mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Editar Perfil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ProfilePicturePicker(
                  imageUrl: avatarUrlController.text.isNotEmpty ? avatarUrlController.text : null,
                  onPick: _uploadingAvatar ? null : _pickAvatar,
                ),
                if (_uploadingAvatar)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: CircularProgressIndicator(),
                  ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'Usuário'),
                  validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
                ),
                TextFormField(
                  controller: fullNameController,
                  decoration: const InputDecoration(labelText: 'Nome completo'),
                ),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
                ),
                TextFormField(
                  controller: bioController,
                  decoration: const InputDecoration(labelText: 'Bio'),
                  maxLines: 2,
                ),
                TextFormField(
                  controller: websiteController,
                  decoration: const InputDecoration(labelText: 'Website'),
                ),
                TextFormField(
                  controller: estadoIdController,
                  decoration: const InputDecoration(labelText: 'ID do Estado'),
                  keyboardType: TextInputType.number,
                ),
                TextFormField(
                  controller: dataNascController,
                  decoration: const InputDecoration(labelText: 'Data de Nascimento (YYYY-MM-DD)'),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Salvar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmailDialog extends StatefulWidget {
  final String email;
  final String? username;
  const EmailDialog({required this.email, this.username, Key? key}) : super(key: key);

  @override
  State<EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends State<EmailDialog> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    final subject = Uri.encodeComponent(_subjectController.text);
    final body = Uri.encodeComponent(_messageController.text);
    final mailto = 'mailto:${widget.email}?subject=$subject&body=$body';
    setState(() => _sending = true);
    if (await canLaunchUrl(Uri.parse(mailto))) {
      await launchUrl(Uri.parse(mailto));
      if (context.mounted) Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o app de email.')),
      );
    }
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enviar email para ${widget.username ?? widget.email}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(labelText: 'Assunto'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(labelText: 'Mensagem'),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _sending ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _sending ? null : _sendEmail,
                  child: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Enviar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _YouthTimeline extends StatefulWidget {
  const _YouthTimeline();
  @override
  State<_YouthTimeline> createState() => _YouthTimelineState();
}

class _YouthTimelineState extends State<_YouthTimeline> {
  bool _verMais = false;

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_ProfilePageState>();
    final reflexoes = state?._reflexoes ?? [];
    final isOwnProfile = state?.profile != null && state?.profile!['id'] == state?.currentUserId;

    final mostrarTodas = _verMais;
    final int limite = 3;
    final cardsToShow = isOwnProfile
      ? (mostrarTodas ? reflexoes : reflexoes.take(limite).toList())
      : (mostrarTodas ? reflexoes : reflexoes.take(limite).toList());

    final int cardCount = cardsToShow.length;

    // TRATAMENTO ROBUSTO: se não houver reflexões, não renderiza timeline
    if (cardCount == 0) {
      if (isOwnProfile) {
        // Botão de adicionar reflexão para o próprio perfil
        return Column(
          children: [
            const SizedBox(height: 32),
            Center(
              child: IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 64, color: Color(0xFF2D2EFF)),
                tooltip: 'Adicionar reflexão',
                onPressed: () {
                  final state = context.findAncestorStateOfType<_ProfilePageState>();
                  state?.showReflexaoDialog(ordem: 0);
                },
              ),
            ),
          ],
        );
      } else {
        // Mensagem para outros perfis
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(
              'Nenhuma reflexão ainda.',
              style: const TextStyle(fontSize: 18, color: Colors.black54),
            ),
          ),
        );
      }
    }

    // Parâmetros visuais (mantenha os mesmos do layout anterior)
    const double cardHeight = 210;
    const double cardWidth = 304;
    const double circleRadius = 16;
    const double circleDiameter = circleRadius * 2;
    const double circleSpacing = 60; // Aumente este valor para mais espaçamento, por exemplo 60 para 100
    const double lineWidth = 8;
    final double timelineHeight = (cardCount - 1) * (cardHeight + circleSpacing) + cardCount * circleDiameter;
    final double timelineLeft = circleRadius * 2;
    final double stackTopOffset = cardHeight / 2;
    final double stackBottomOffset = cardHeight / 2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.96,
          height: timelineHeight + 40 + stackTopOffset + stackBottomOffset,
          child: Stack(
            children: [
              // Linha vertical com gradiente e sombra
              Positioned(
                left: circleRadius,
                top: stackTopOffset,
                child: Container(
                  width: lineWidth,
                  height: timelineHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF7B2FF2), // Roxo
                        Color(0xFFFFA726), // Laranja
                        Color(0xFFFFF176), // Amarelo
                      ],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              // Círculos vermelhos com borda branca e sombra
              ...List.generate(cardCount, (i) {
                final double top = stackTopOffset + i * (cardHeight + circleSpacing + circleDiameter);
                return Positioned(
                  left: circleRadius + (lineWidth / 2) - circleRadius,
                  top: top,
                  child: Container(
                    width: circleDiameter,
                    height: circleDiameter,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              // Cards cinza claro, fonte #333333, borda branca
              ...List.generate(cardCount, (i) {
                final double centerY = stackTopOffset + i * (cardHeight + circleSpacing + circleDiameter) + circleRadius;
                final double top = centerY - cardHeight / 2;
                final reflexao = cardsToShow[i];
                return Positioned(
                  top: top,
                  left: timelineLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Linha horizontal
                      Container(
                        width: 28,
                        height: 4,
                        color: Colors.red, // Azul claro
                      ),
                      const SizedBox(width: 8),
                      // Card com fundo cinza claro, borda branca, fonte #333333
                      Container(
                        width: cardWidth,
                        height: cardHeight,
                        decoration: BoxDecoration(
                          color: Color(0xFFF7F7F7), // Cinza bem claro
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.red, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Stack(
                            children: [
                              if (reflexao != null && reflexao['conteudo'] != null)
                                Align(
                                  alignment: Alignment.center,
                                  child: SizedBox(
                                    height: cardHeight - 32, // Limita a altura interna do card
                                    child: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            reflexao['conteudo'].toString().length > 130
                                              ? reflexao['conteudo'].toString().substring(0, 130) + '...'
                                              : reflexao['conteudo'],
                                            style: const TextStyle(
                                              color: Color(0xFF333333), // Cinza escuro
                                              fontSize: 18,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 5,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (reflexao['conteudo'].toString().length > 130) ...[
                                            const SizedBox(height: 16),
                                            SizedBox(
                                              height: 32,
                                              child: TextButton(
                                                onPressed: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (_) => Dialog(
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                                      backgroundColor: Colors.transparent,
                                                      child: Container(
                                                        constraints: const BoxConstraints(maxWidth: 380),
                                                        decoration: BoxDecoration(
                                                          gradient: const LinearGradient(
                                                            colors: [
                                                              Color(0xFF6A85F1),
                                                              Color(0xFFFBC2EB),
                                                              Color(0xFFF9F586),
                                                              Color(0xFFF68084),
                                                            ],
                                                            begin: Alignment.topLeft,
                                                            end: Alignment.bottomRight,
                                                          ),
                                                          borderRadius: BorderRadius.circular(28),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors.black26,
                                                              blurRadius: 24,
                                                              offset: Offset(0, 8),
                                                            ),
                                                          ],
                                                        ),
                                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                                                        child: Column(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Icon(Icons.menu_book, color: Colors.white, size: 48),
                                                            const SizedBox(height: 12),
                                                            const Text(
                                                              'Reflexão Completa',
                                                              style: TextStyle(
                                                                color: Colors.white,
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 22,
                                                                letterSpacing: 0.5,
                                                              ),
                                                              textAlign: TextAlign.center,
                                                            ),
                                                            const SizedBox(height: 18),
                                                            Container(
                                                              padding: const EdgeInsets.all(18),
                                                              decoration: BoxDecoration(
                                                                color: Colors.white.withOpacity(0.97),
                                                                borderRadius: BorderRadius.circular(18),
                                                              ),
                                                              child: SingleChildScrollView(
                                                                child: Text(
                                                                  reflexao['conteudo'],
                                                                  style: const TextStyle(
                                                                    fontSize: 18,
                                                                    color: Color(0xFF2D2EFF),
                                                                    fontWeight: FontWeight.w500,
                                                                  ),
                                                                  textAlign: TextAlign.center,
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(height: 24),
                                                            SizedBox(
                                                              width: double.infinity,
                                                              child: ElevatedButton.icon(
                                                                icon: const Icon(Icons.close, color: Colors.white),
                                                                label: const Text('Fechar', style: TextStyle(fontWeight: FontWeight.bold)),
                                                                style: ElevatedButton.styleFrom(
                                                                  backgroundColor: const Color(0xFF7B2FF2),
                                                                  foregroundColor: Colors.white,
                                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                                                  textStyle: const TextStyle(fontSize: 16),
                                                                ),
                                                                onPressed: () => Navigator.of(context).pop(),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: const Text('Leia Mais', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                style: TextButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  minimumSize: Size(80, 32), // altura menor
                                                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 0),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              // Ícone de editar
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Builder(
                                  builder: (context) {
                                    if (isOwnProfile) {
                                      return IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.black, size: 28),
                                        tooltip: 'Editar reflexão',
                                        onPressed: () {
                                          final state = context.findAncestorStateOfType<_ProfilePageState>();
                                          state?.showReflexaoDialog(reflexao: reflexao, ordem: i);
                                        },
                                      );
                                    } else {
                                      // Visitante: curtir/gostar e compartilhar
                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.thumb_up_alt_outlined, color: Colors.white, size: 26),
                                            tooltip: 'Curtir',
                                            onPressed: () {},
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.share, color: Colors.white, size: 26),
                                            tooltip: 'Compartilhar',
                                            onPressed: () {},
                                          ),
                                        ],
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        // Botão "Carregar Mais" (para ambos, se houver mais de 3 reflexões)
        if (reflexoes.length > limite)
          Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 8),
            child: Center(
              child: TextButton(
                onPressed: () => setState(() => _verMais = !_verMais),
                child: Text(_verMais ? 'Mostrar Menos' : 'Carregar Mais', style: const TextStyle(fontSize: 16)),
              ),
            ),
          ),
        // Botão + grande centralizado para adicionar nova reflexão (apenas para o próprio perfil)
        if (isOwnProfile)
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 8),
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 54, color: Color(0xFF2D2EFF)),
                tooltip: 'Adicionar nova reflexão',
                onPressed: () {
                  final state = context.findAncestorStateOfType<_ProfilePageState>();
                  state?.showReflexaoDialog(ordem: reflexoes.length);
                },
              ),
            ),
          ),
      ],
    );
  }
}