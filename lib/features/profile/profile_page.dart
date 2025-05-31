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

class ProfilePage extends StatefulWidget {
  final String? profileId; // Se nulo, mostra o perfil do logado
  const ProfilePage({Key? key, this.profileId}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? profile;
  bool loading = true;
  int _selectedIndex = 4;
  String? currentUserId;
  String? currentUserAvatarUrl;
  int postCount = 0;
  int followersCount = 0;
  int followingCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _fetchCurrentUserAvatar();
    _fetchStats();
  }

  Future<void> _fetchProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    currentUserId = user.id;
    final idToFetch = widget.profileId ?? user.id;
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
      extendBody: true,
      body: Container(
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
        child: SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator())
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
                      _ProfileActions(),
                      _ProfileHighlights(),
                      const Divider(height: 1),
                      _ProfileTabs(),
                      _ProfileGridPosts(),
                    ],
                  ),
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
            icon: currentUserAvatarUrl != null && currentUserAvatarUrl!.isNotEmpty
                ? CircleAvatar(radius: 12, backgroundImage: NetworkImage(currentUserAvatarUrl!))
                : const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 16)),
            label: 'Perfil',
          ),
        ],
      ),
    );
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
              // Navegação para tela de edição de perfil (implementar depois)
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

class _ProfileActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final profileState = context.findAncestorStateOfType<_ProfilePageState>();
    final profile = profileState?.profile;
    final profileId = profile?['id'] ?? '';
    final username = profile?['username'] ?? '';
    final profileUrl = 'https://seeyou.com/perfil/$profileId';
    final email = profile?['email'] ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/bible_quiz');
              },
              child: const Text('Quiz'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: profile == null
                  ? null
                  : () async {
                      final result = await showDialog(
                        context: context,
                        builder: (_) => EditProfileDialog(profile: profile),
                      );
                      if (result == true) {
                        await profileState?._fetchProfile();
                      }
                    },
              child: const Text('Editar'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: profile == null
                  ? null
                  : () async {
                      final selected = await showMenu<String>(
                        context: context,
                        position: RelativeRect.fromLTRB(1000, 200, 0, 0),
                        items: [
                          const PopupMenuItem<String>(
                            value: 'copy',
                            child: Text('Copiar link do perfil'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'share',
                            child: Text('Compartilhar'),
                          ),
                        ],
                      );
                      if (selected == 'copy') {
                        await Clipboard.setData(ClipboardData(text: profileUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link do perfil copiado!')),
                        );
                      } else if (selected == 'share') {
                        await Share.share('Veja o perfil @$username: $profileUrl');
                      }
                    },
              child: const Text('Compartilhar'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: (profile == null || email.isEmpty)
                  ? null
                  : () async {
                      await showDialog(
                        context: context,
                        builder: (_) => EmailDialog(email: email, username: username),
                      );
                    },
              child: const Text('Email'),
            ),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: const [
        Icon(Icons.grid_on, size: 28),
        Icon(Icons.video_collection_outlined, size: 28),
        Icon(Icons.person_pin_outlined, size: 28),
      ],
    );
  }
}

class _ProfileGridPosts extends StatefulWidget {
  @override
  State<_ProfileGridPosts> createState() => _ProfileGridPostsState();
}

class _ProfileGridPostsState extends State<_ProfileGridPosts> {
  late Future<List<Map<String, dynamic>>> _userPostsFuture;

  @override
  void initState() {
    super.initState();
    _userPostsFuture = _fetchUserPosts();
  }

  Future<List<Map<String, dynamic>>> _fetchUserPosts() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];
    // Busca o id do perfil visitado (ou do logado se for o próprio perfil)
    final profileId = (context.findAncestorStateOfType<_ProfilePageState>()?.profile?['id']) ?? user.id;
    final data = await Supabase.instance.client
        .from('posts')
        .select('id, media_urls, content_text, created_at, user_id, profiles:user_id(id, username, avatar_url), views')
        .eq('user_id', profileId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _userPostsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Nenhuma postagem ainda.'));
        }
        final posts = snapshot.data!;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: posts.length,
          itemBuilder: (context, i) {
            final post = posts[i];
            dynamic urls = post['media_urls'];
            List<String> images = [];
            if (urls is List) {
              if (urls.isNotEmpty && urls[0] is List) {
                images.addAll(List<String>.from(urls[0]));
              } else {
                images.addAll(List<String>.from(urls));
              }
            }
            if (images.isEmpty) {
              return const SizedBox.shrink(); // Não mostra posts sem imagem
            }
            return GestureDetector(
              onTap: () async {
                // Incrementa o número de visualizações de forma atômica no banco
                await Supabase.instance.client
                  .rpc('increment_post_views', params: {'post_id': post['id']});
                await showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    insetPadding: const EdgeInsets.all(16),
                    child: _PostDetailView(post: post, imageUrl: images[0]),
                  ),
                );
                setState(() {}); // Recarrega o grid para mostrar o novo valor
              },
              child: Stack(
                children: [
                  Image.network(images[0], fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                  if (images.length > 1)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(2),
                        child: const Icon(Icons.collections, color: Colors.white, size: 20),
                      ),
                    ),
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.remove_red_eye, color: Colors.white, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            (post['views'] ?? 0).toString(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PostDetailView extends StatefulWidget {
  final Map<String, dynamic> post;
  final String? imageUrl;
  const _PostDetailView({required this.post, this.imageUrl});

  @override
  State<_PostDetailView> createState() => _PostDetailViewState();
}

class _PostDetailViewState extends State<_PostDetailView> {
  bool _liked = false;
  bool _loadingLike = false;

  @override
  void initState() {
    super.initState();
    _checkLiked();
  }

  Future<void> _checkLiked() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final data = await Supabase.instance.client
        .from('likes')
        .select()
        .eq('user_id', user.id)
        .eq('post_id', widget.post['id'])
        .maybeSingle();
    setState(() {
      _liked = data != null;
    });
  }

  Future<void> _toggleLike() async {
    setState(() => _loadingLike = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    if (_liked) {
      await Supabase.instance.client
          .from('likes')
          .delete()
          .eq('user_id', user.id)
          .eq('post_id', widget.post['id']);
    } else {
      await Supabase.instance.client.from('likes').insert({
        'user_id': user.id,
        'post_id': widget.post['id'],
      });
    }
    await _checkLiked();
    setState(() => _loadingLike = false);
  }

  void _showCommentsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final TextEditingController _commentController = TextEditingController();
        // Adiciona um Future de estado para atualizar os comentários
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<List<Map<String, dynamic>>> _fetchComments() async {
              final data = await Supabase.instance.client
                  .from('comments')
                  .select('*, profiles!user_id(id, username, avatar_url)')
                  .eq('post_id', widget.post['id'])
                  .order('created_at', ascending: true);
              return List<Map<String, dynamic>>.from(data);
            }
            // Variável de estado para o future
            late Future<List<Map<String, dynamic>>> commentsFuture = _fetchComments();
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
                        future: commentsFuture,
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
                                title: Text(user['username'] ?? 'Usuário', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                              final user = Supabase.instance.client.auth.currentUser;
                              if (user == null) return;
                              await Supabase.instance.client.from('comments').insert({
                                'user_id': user.id,
                                'post_id': widget.post['id'],
                                'content': text,
                              });
                              _commentController.clear();
                              setModalState(() {
                                commentsFuture = _fetchComments();
                              });
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

  @override
  Widget build(BuildContext context) {
    final user = widget.post['profiles'] ?? {};
    dynamic urls = widget.post['media_urls'];
    List<String> images = [];
    if (urls is List) {
      if (urls.isNotEmpty && urls[0] is List) {
        images.addAll(List<String>.from(urls[0]));
      } else {
        images.addAll(List<String>.from(urls));
      }
    }
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (images.isNotEmpty)
                PostImageCarousel(images: images),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    (user['avatar_url'] != null && user['avatar_url'].toString().isNotEmpty)
                        ? CircleAvatar(backgroundImage: NetworkImage(user['avatar_url']))
                        : const CircleAvatar(child: Icon(Icons.person, size: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['username'] ?? 'Usuário',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            widget.post['created_at'] != null
                                ? widget.post['created_at'].toString().substring(0, 16).replaceFirst('T', ' ')
                                : '',
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _liked ? Icons.favorite : Icons.favorite_border,
                        color: _liked ? Colors.red : null,
                        size: 28,
                      ),
                      onPressed: _loadingLike ? null : _toggleLike,
                    ),
                    IconButton(
                      icon: const Icon(Icons.mode_comment_outlined, size: 28),
                      onPressed: () => _showCommentsModal(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send_outlined, size: 28),
                      onPressed: () {
                        final content = widget.post['content_text'] ?? '';
                        Share.share(content.isNotEmpty ? content : 'Veja este post!');
                      },
                    ),
                  ],
                ),
              ),
              if ((widget.post['content_text'] ?? '').toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    widget.post['content_text'],
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.left,
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
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