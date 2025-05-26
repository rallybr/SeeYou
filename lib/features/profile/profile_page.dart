import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../feed/feed_page.dart';
import '../create_post/create_post_page.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _fetchCurrentUserAvatar();
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
                      _ProfileStats(),
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
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu),
      onSelected: (value) async {
        if (value == 'logout') {
          await Supabase.instance.client.auth.signOut();
          if (context.mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          }
        } else if (value == 'edit') {
          // Navegação para tela de edição de perfil (implementar depois)
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'edit',
          child: Text('Editar'),
        ),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Text('Logout'),
        ),
      ],
    );
  }
}

class _ProfileStats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatColumn('3.382', 'posts'),
          _StatColumn('41,6 mil', 'seguidores'),
          _StatColumn('1.051', 'seguindo'),
        ],
      ),
    );
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {},
              child: const Text('Editar'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () {},
              child: const Text('Compartilhar'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () {},
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
        .select('id, media_urls, content_text, created_at, user_id, profiles:user_id(id, username, avatar_url)')
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
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    insetPadding: const EdgeInsets.all(16),
                    child: _PostDetailView(post: post, imageUrl: images[0]),
                  ),
                );
              },
              child: Image.network(images[0], fit: BoxFit.cover),
            );
          },
        );
      },
    );
  }
}

class _PostDetailView extends StatelessWidget {
  final Map<String, dynamic> post;
  final String? imageUrl;
  const _PostDetailView({required this.post, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final user = post['profiles'] ?? {};
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imageUrl != null)
          AspectRatio(
            aspectRatio: 1,
            child: Image.network(imageUrl!, fit: BoxFit.cover),
          ),
        ListTile(
          leading: (user['avatar_url'] != null && user['avatar_url'].toString().isNotEmpty)
              ? CircleAvatar(backgroundImage: NetworkImage(user['avatar_url']))
              : const CircleAvatar(child: Icon(Icons.person, size: 20)),
          title: Text(user['username'] ?? 'Usuário', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(post['created_at'] != null ? post['created_at'].toString().substring(0, 16).replaceFirst('T', ' ') : ''),
          trailing: IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () {
              // Aqui você pode implementar a lógica de curtir
            },
          ),
        ),
        if ((post['content_text'] ?? '').toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(post['content_text'], style: const TextStyle(fontSize: 16)),
          ),
        const SizedBox(height: 8),
      ],
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