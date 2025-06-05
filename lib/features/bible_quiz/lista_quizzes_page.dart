import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'bible_quiz_page.dart';

class ListaQuizzesPage extends StatefulWidget {
  const ListaQuizzesPage({Key? key}) : super(key: key);

  @override
  State<ListaQuizzesPage> createState() => _ListaQuizzesPageState();
}

class _ListaQuizzesPageState extends State<ListaQuizzesPage> {
  List<Map<String, dynamic>> quizzes = [];
  Map<String, String> categorias = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => loading = true);
    final quizzesData = await Supabase.instance.client
        .from('quizzes')
        .select('id, title, category_id, championship_id')
        .eq('aprovado', true)
        .order('created_at', ascending: false);
    final categoriasData = await Supabase.instance.client
        .from('quiz_categories')
        .select('id, name');
    final catMap = <String, String>{};
    for (final cat in categoriasData) {
      catMap[cat['id']] = cat['name'];
    }
    setState(() {
      quizzes = List<Map<String, dynamic>>.from(quizzesData);
      categorias = catMap;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D2EFF),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Quizzes Disponíveis', style: TextStyle(color: Colors.white)),
      ),
      body: Container(
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
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: quizzes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, i) {
            final quiz = quizzes[i];
            final categoriaNome = categorias[quiz['category_id']] ?? '---';
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => BibleQuizPage(quizId: quiz['id']),
                ));
              },
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 6,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.quiz, color: Color(0xFF2D2EFF), size: 32),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              quiz['title'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 19,
                                color: Color(0xFF2D2EFF),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.category, color: Color(0xFFE94057), size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  'Categoria: ',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                ),
                                Flexible(
                                  child: Text(
                                    categoriaNome,
                                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: Color(0xFF7B2FF2)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Color(0xFF2D2EFF)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
} 