import 'package:flutter/material.dart';
import '../profile/profile_page.dart';
import '../create_post/create_post_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'dart:async';
import '../bible_quiz/lista_quizzes_page.dart';
import '../equipe/lista_equipes_page.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({Key? key}) : super(key: key);

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  int _selectedIndex = 0;
  String? avatarUrl;
  final Map<String, int> commentCounts = {};
  bool hasLikeNotification = false;
  bool hasCommentNotification = false;
  StreamSubscription<List<Map<String, dynamic>>>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _fetchAvatar();
    _checkNotifications();
    _listenNotifications();
  }

  Future<void> _fetchAvatar() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final data = await Supabase.instance.client
        .from('profiles')
        .select('avatar_url')
        .eq('id', user.id)
        .maybeSingle();
    setState(() {
      avatarUrl = data != null ? data['avatar_url'] as String? : null;
    });
  }

  Future<void> _checkNotifications() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    // Buscar notificações não lidas do usuário logado
    final notifications = await Supabase.instance.client
        .from('notifications')
        .select('type')
        .eq('user_id', user.id)
        .eq('read', false);
    setState(() {
      hasLikeNotification = notifications.any((n) => n['type'] == 'like');
      hasCommentNotification = notifications.any((n) => n['type'] == 'comment');
    });
  }

  Future<void> _markNotificationsAsRead(String type) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    await Supabase.instance.client
        .from('notifications')
        .update({'read': true})
        .eq('user_id', user.id)
        .eq('type', type)
        .eq('read', false);
    _checkNotifications();
  }

  void _onItemTapped(int index) {
    if (index == 4) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfilePage()),
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

  void _listenNotifications() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    // Cancela a subscription anterior se já existir
    _notificationSubscription?.cancel();
    _notificationSubscription = Supabase.instance.client
        .from('notifications:user_id=eq.${user.id}')
        .stream(primaryKey: ['id'])
        .listen((event) {
          _checkNotifications();
        });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6A85F1), // azul
              Color(0xFFFBC2EB), // rosa claro
              Color(0xFFF9F586), // amarelo claro
              Color(0xFFF68084), // rosa
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _FeedAppBar(
                hasLikeNotification: hasLikeNotification,
                hasCommentNotification: hasCommentNotification,
                onLikePressed: () {
                  _markNotificationsAsRead('like');
                  // Aqui você pode abrir um modal de curtidas se desejar
                },
                onCommentPressed: hasCommentNotification
                    ? () {
                        _markNotificationsAsRead('comment');
                        // Chama o modal de comentários
                        final appBar = _FeedAppBar(
                          hasLikeNotification: hasLikeNotification,
                          hasCommentNotification: hasCommentNotification,
                        );
                        appBar._showCommentsNotificationModal(context);
                      }
                    : null,
              ),
              _StoriesBar(),
              const Divider(height: 1),
              Expanded(child: _FeedList()),
            ],
          ),
        ),
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
            icon: avatarUrl != null && avatarUrl!.isNotEmpty
                ? CircleAvatar(radius: 12, backgroundImage: NetworkImage(avatarUrl!))
                : const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 16)),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class _FeedAppBar extends StatelessWidget {
  final bool hasLikeNotification;
  final bool hasCommentNotification;
  final void Function()? onLikePressed;
  final void Function()? onCommentPressed;

  const _FeedAppBar({
    required this.hasLikeNotification,
    required this.hasCommentNotification,
    this.onLikePressed,
    this.onCommentPressed,
    Key? key,
  }) : super(key: key);

  void _showCommentsNotificationModal(BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    // Buscar posts do usuário logado
    final posts = await Supabase.instance.client
        .from('posts')
        .select('id, content_text')
        .eq('user_id', user.id);
    final postIds = posts.map((p) => p['id']).toList();
    if (postIds.isEmpty) return;
    // Buscar comentários recebidos
    final comments = await Supabase.instance.client
        .from('comments')
        .select('*, profiles!user_id(id, username, avatar_url)')
        .inFilter('post_id', postIds)
        .order('created_at', ascending: false)
        .limit(50);
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: comments.isEmpty
              ? const Center(child: Text('Nenhum comentário novo.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, i) {
                    final c = comments[i];
                    final profile = c['profiles'] ?? {};
                    final post = posts.firstWhere(
                      (p) => p['id'] == c['post_id'],
                      orElse: () => {'id': '', 'content_text': ''},
                    );
                    return ListTile(
                      leading: (profile['avatar_url'] != null && profile['avatar_url'].toString().isNotEmpty)
                          ? CircleAvatar(backgroundImage: NetworkImage(profile['avatar_url']))
                          : const CircleAvatar(child: Icon(Icons.person, size: 20)),
                      title: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          if (profile['id'] != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProfilePage(profileId: profile['id']),
                              ),
                            );
                          }
                        },
                        child: Text(
                          profile['username'] ?? 'Usuário',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c['content'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                          if (post['content_text'] != null)
                            Text('No post: ${post['content_text']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          Text(c['created_at'] != null ? c['created_at'].toString().substring(0, 16).replaceFirst('T', ' ') : '',
                              style: const TextStyle(fontSize: 11, color: Colors.black38)),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
        );
      },
    );
  }

  void _showLikesNotificationModal(BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    // Buscar notificações de curtidas não lidas e lidas do usuário logado
    final notifications = await Supabase.instance.client
        .from('notifications')
        .select('*, profiles:source_user_id(id, username, avatar_url), posts(id, content_text)')
        .eq('user_id', user.id)
        .eq('type', 'like')
        .order('created_at', ascending: false)
        .limit(50);
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: notifications.isEmpty
              ? const Center(child: Text('Nenhuma curtida nova.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, i) {
                    final n = notifications[i];
                    final profile = n['profiles'] ?? {};
                    final post = n['posts'] ?? {};
                    return ListTile(
                      leading: (profile['avatar_url'] != null && profile['avatar_url'].toString().isNotEmpty)
                          ? CircleAvatar(backgroundImage: NetworkImage(profile['avatar_url']))
                          : const CircleAvatar(child: Icon(Icons.person, size: 20)),
                      title: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          if (profile['id'] != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProfilePage(profileId: profile['id']),
                              ),
                            );
                          }
                        },
                        child: Text(
                          profile['username'] ?? 'Usuário',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Curtiu seu post', style: const TextStyle(fontSize: 14)),
                          if (post['content_text'] != null)
                            Text('No post: ${post['content_text']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          Text(n['created_at'] != null ? n['created_at'].toString().substring(0, 16).replaceFirst('T', ' ') : '',
                              style: const TextStyle(fontSize: 11, color: Colors.black38)),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Image.asset(
            'assets/images/logofju.png',
            height: 45,
          ),
          Row(
            children: [
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.favorite_border),
                    onPressed: () async {
                      await (context.findAncestorStateOfType<_FeedPageState>()?._markNotificationsAsRead('like'));
                      _showLikesNotificationModal(context);
                    },
                  ),
                  if (hasLikeNotification)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                      ),
                    ),
                ],
              ),
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.messenger_outline),
                    onPressed: () async {
                      await (context.findAncestorStateOfType<_FeedPageState>()?._markNotificationsAsRead('comment'));
                      _showCommentsNotificationModal(context);
                    },
                  ),
                  if (hasCommentNotification)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.blue, // azul para comentários
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 2.5),
                        ),
                      ),
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

class _StoriesBar extends StatefulWidget {
  @override
  State<_StoriesBar> createState() => _StoriesBarState();
}

class _StoriesBarState extends State<_StoriesBar> {
  late Future<List<Map<String, dynamic>>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _fetchUsers();
  }

  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    final data = await Supabase.instance.client
        .from('profiles')
        .select('id, username, avatar_url')
        .order('updated_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(data);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return const Center(child: Text('Nenhum usuário encontrado.'));
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, i) {
              final user = users[i];
              return Column(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB2FEFA), Color(0xFF6A85F1), Color(0xFF8F5CFF), Color(0xFF6A1B9A)],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3.0),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundImage: user['avatar_url'] != null && user['avatar_url'].toString().isNotEmpty
                            ? NetworkImage(user['avatar_url'])
                            : null,
                        child: (user['avatar_url'] == null || user['avatar_url'].toString().isEmpty)
                            ? const Icon(Icons.person, size: 30)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 70,
                    child: Text(
                      user['username'] ?? '',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _FeedList extends StatefulWidget {
  @override
  State<_FeedList> createState() => _FeedListState();
}

class _FeedListState extends State<_FeedList> {
  late Future<List<Map<String, dynamic>>> _postsFuture;
  final Map<String, bool> _likedPosts = {};
  final Map<String, int> _likeCounts = {};
  final Map<String, int> commentCounts = {};

  Future<Map<String, dynamic>?> _fetchQuizDestaque() async {
    final quiz = await Supabase.instance.client
        .from('quizzes')
        .select('id, title')
        .eq('destaque', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return quiz;
  }

  @override
  void initState() {
    super.initState();
    _postsFuture = _fetchPosts();
  }

  Future<List<Map<String, dynamic>>> _fetchPosts() async {
    final data = await Supabase.instance.client
        .from('posts')
        .select('*, profiles!user_id(id, username, avatar_url)')
        .order('created_at', ascending: false);
    // Para cada post, buscar se o usuário curtiu
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      for (final post in data) {
        final likeData = await Supabase.instance.client
            .from('likes')
            .select()
            .eq('user_id', user.id)
            .eq('post_id', post['id'])
            .maybeSingle();
        _likedPosts[post['id']] = likeData != null;
        // Contar likes
        final likeCountData = await Supabase.instance.client
            .from('likes')
            .select()
            .eq('post_id', post['id']);
        _likeCounts[post['id']] = likeCountData.length;
      }
    }
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> _toggleLike(String postId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final alreadyLiked = _likedPosts[postId] ?? false;
    setState(() {
      _likedPosts[postId] = !alreadyLiked;
      _likeCounts[postId] = (_likeCounts[postId] ?? 0) + (alreadyLiked ? -1 : 1);
    });
    if (alreadyLiked) {
      await Supabase.instance.client
          .from('likes')
          .delete()
          .eq('user_id', user.id)
          .eq('post_id', postId);
    } else {
      await Supabase.instance.client.from('likes').insert({
        'user_id': user.id,
        'post_id': postId,
      });
      // Buscar o dono do post
      final post = await Supabase.instance.client
          .from('posts')
          .select('user_id')
          .eq('id', postId)
          .maybeSingle();
      final postOwnerId = post != null ? post['user_id'] as String? : null;
      if (postOwnerId != null && postOwnerId != user.id) {
        await Supabase.instance.client.from('notifications').insert({
          'user_id': postOwnerId,
          'type': 'like',
          'source_user_id': user.id,
          'post_id': postId,
          'read': false,
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchComments(String postId) async {
    final data = await Supabase.instance.client
        .from('comments')
        .select('*, profiles!user_id(id, username, avatar_url)')
        .eq('post_id', postId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<int> _fetchCommentCount(String postId) async {
    if (commentCounts.containsKey(postId)) {
      return commentCounts[postId]!;
    }
    final data = await Supabase.instance.client
        .from('comments')
        .select()
        .eq('post_id', postId);
    commentCounts[postId] = data.length;
    return data.length;
  }

  Future<void> _addComment(String postId, String content) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final insertResult = await Supabase.instance.client.from('comments').insert({
      'user_id': user.id,
      'post_id': postId,
      'content': content,
    }).select();
    setState(() {
      commentCounts[postId] = (commentCounts[postId] ?? 0) + 1;
    });
    // Buscar o dono do post
    final post = await Supabase.instance.client
        .from('posts')
        .select('user_id')
        .eq('id', postId)
        .maybeSingle();
    final postOwnerId = post != null ? post['user_id'] as String? : null;
    // Pega o id do comentário recém criado
    final commentId = insertResult != null && insertResult is List && insertResult.isNotEmpty ? insertResult[0]['id'] : null;
    if (postOwnerId != null && postOwnerId != user.id && commentId != null) {
      await Supabase.instance.client.from('notifications').insert({
        'user_id': postOwnerId,
        'type': 'comment',
        'source_user_id': user.id,
        'post_id': postId,
        'comment_id': commentId,
        'read': false,
      });
    }
  }

  void _showCommentsModal(BuildContext context, String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final TextEditingController _commentController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<List<Map<String, dynamic>>> _fetchCommentsLocal() async {
              final data = await Supabase.instance.client
                  .from('comments')
                  .select('*, profiles!user_id(id, username, avatar_url)')
                  .eq('post_id', postId)
                  .order('created_at', ascending: true);
              return List<Map<String, dynamic>>.from(data);
            }
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  children: [
                    const Text('Comentários', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: _fetchCommentsLocal(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final comments = snapshot.data ?? [];
                          if (comments.isEmpty) {
                            return const Center(child: Text('Nenhum comentário ainda.'));
                          }
                          return ListView.builder(
                            itemCount: comments.length,
                            itemBuilder: (context, i) {
                              final c = comments[i];
                              final user = c['profiles'] ?? {};
                              return ListTile(
                                leading: (user['avatar_url'] != null && user['avatar_url'].toString().isNotEmpty)
                                    ? CircleAvatar(backgroundImage: NetworkImage(user['avatar_url']))
                                    : const CircleAvatar(child: Icon(Icons.person, size: 20)),
                                title: GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context);
                                    if (user['id'] != null) {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ProfilePage(profileId: user['id']),
                                        ),
                                      );
                                    }
                                  },
                                  child: Text(
                                    user['username'] ?? 'Usuário',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                                ),
                                subtitle: Text(c['content'] ?? ''),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: const InputDecoration(hintText: 'Adicione um comentário...'),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: () async {
                            final text = _commentController.text.trim();
                            if (text.isNotEmpty) {
                              await _addComment(postId, text);
                              _commentController.clear();
                              setModalState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPostOptionsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _OptionButton(icon: Icons.bookmark_border, label: 'Salvar', onTap: () {}),
                  _OptionButton(icon: Icons.qr_code, label: 'QR code', onTap: () {}),
                ],
              ),
              const SizedBox(height: 8),
              _OptionTile(icon: Icons.star_border, label: 'Remover dos Favoritos', onTap: () {}),
              _OptionTile(icon: Icons.person_outline, label: 'Sobre esta conta', onTap: () {}),
              _OptionTile(icon: Icons.translate, label: 'Traduções', onTap: () {}),
              _OptionTile(icon: Icons.closed_caption_outlined, label: 'Legendas ocultas', onTap: () {}),
              _OptionTile(icon: Icons.info_outline, label: 'Por que você está vendo esse post', onTap: () {}),
              _OptionTile(icon: Icons.visibility_off_outlined, label: 'Ocultar', onTap: () {}),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.report_gmailerrorred, color: Colors.red),
                title: const Text('Denunciar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () {},
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _postsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Nenhuma postagem ainda.'));
        }
        final posts = snapshot.data!;
        return FutureBuilder<Map<String, dynamic>?>(
          future: _fetchQuizDestaque(),
          builder: (context, quizSnapshot) {
            final quizDestaque = quizSnapshot.data;
            return ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: posts.length + (quizDestaque != null ? 1 : 0) + 1,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final totalPosts = posts.length;
                final hasQuizDestaque = quizDestaque != null;
                final bannerIndex = hasQuizDestaque ? 2 : 1;

                if (hasQuizDestaque && i == 0) {
                  // Banner do Bible Quiz
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ListaQuizzesPage()),
                      );
                    },
                    child: Container(
                      height: 100,
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2D2EFF), Color(0xFF7B2FF2), Color(0xFFE94057)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          const Icon(Icons.star, color: Colors.yellow, size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Participe do Bible Quiz!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  quizDestaque['title'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ),
                  );
                }
                if (i == bannerIndex) {
                  // Banner do Campeonato Quiz
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ListaEquipesPage()),
                      );
                    },
                    child: Container(
                      height: 100,
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7B2FF2), Color(0xFF2D2EFF), Color(0xFFE94057)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          const Icon(Icons.emoji_events, color: Colors.amber, size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Participe do Campeonato Quiz!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Escolha uma Equipe',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ),
                  );
                }

                // Ajuste de índice para posts reais
                int postIndex = i;
                if (hasQuizDestaque) postIndex -= 1;
                if (i > bannerIndex) postIndex -= 1;
                if (postIndex < 0 || postIndex >= totalPosts) {
                  return const SizedBox.shrink();
                }
                final post = posts[postIndex];
                final user = post['profiles'] ?? {};
                dynamic mediaUrls = post['media_urls'];
                List<dynamic> images = [];
                if (mediaUrls is List) {
                  if (mediaUrls.isNotEmpty && mediaUrls[0] is List) {
                    images = List<String>.from(mediaUrls[0]);
                  } else {
                    images = List<String>.from(mediaUrls);
                  }
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: GestureDetector(
                        onTap: () {
                          if (user['id'] != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProfilePage(profileId: user['id']),
                              ),
                            );
                          }
                        },
                        child: (user['avatar_url'] != null && user['avatar_url'].toString().isNotEmpty)
                            ? CircleAvatar(backgroundImage: NetworkImage(user['avatar_url']))
                            : const CircleAvatar(child: Icon(Icons.person, size: 20)),
                      ),
                      title: GestureDetector(
                        onTap: () {
                          if (user['id'] != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProfilePage(profileId: user['id']),
                              ),
                            );
                          }
                        },
                        child: Text(user['username'] ?? 'Usuário', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      subtitle: Text(post['created_at'] != null ? post['created_at'].toString().substring(0, 16).replaceFirst('T', ' ') : ''),
                      trailing: (post['user_id'] != Supabase.instance.client.auth.currentUser?.id)
                          ? IconButton(
                              icon: const Icon(Icons.more_horiz),
                              onPressed: () => _showPostOptionsModal(context),
                            )
                          : null,
                    ),
                    if (images.isNotEmpty)
                      PostImageCarousel(images: List<String>.from(images)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  (_likedPosts[post['id']] ?? false)
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: (_likedPosts[post['id']] ?? false)
                                      ? Colors.red
                                      : null,
                                  size: 30,
                                ),
                                onPressed: () => _toggleLike(post['id']),
                                iconSize: 30,
                              ),
                              Text(
                                (_likeCounts[post['id']] ?? 0).toString(),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          FutureBuilder<int>(
                            future: _fetchCommentCount(post['id']),
                            builder: (context, snapshot) {
                              final count = snapshot.data ?? 0;
                              return Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.mode_comment_outlined, size: 30,),
                                    onPressed: () => _showCommentsModal(context, post['id']),
                                    iconSize: 30,
                                  ),
                                  Text(
                                    count.toString(),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.send_outlined, size: 30,),
                                onPressed: () {
                                  final content = post['content_text'] ?? '';
                                  Share.share(content.isNotEmpty ? content : 'Veja este post!');
                                },
                                iconSize: 30,
                              ),
                              Text(
                                '0', // Compartilhamentos (fixo por enquanto)
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ],
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.bookmark_border, size: 30,),
                            onPressed: () {},
                            iconSize: 30,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        post['content_text'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class PostImageCarousel extends StatefulWidget {
  final List<String> images;
  const PostImageCarousel({required this.images});

  @override
  State<PostImageCarousel> createState() => PostImageCarouselState();
}

class PostImageCarouselState extends State<PostImageCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = MediaQuery.of(context).size.height * 0.5;
        return Column(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxHeight,
              ),
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.images.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, i) {
                  return Image.network(
                    widget.images[i],
                    fit: BoxFit.cover,
                  );
                },
              ),
            ),
            if (widget.images.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SmoothPageIndicator(
                  controller: _pageController,
                  count: widget.images.length,
                  effect: const WormEffect(
                    dotHeight: 8,
                    dotWidth: 8,
                    activeDotColor: Colors.blue,
                    dotColor: Colors.black26,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _OptionButton({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(12),
            child: Icon(icon, size: 28),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _OptionTile({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }
} 