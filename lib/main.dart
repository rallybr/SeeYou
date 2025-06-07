import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/pages/login_page.dart';
import 'features/auth/pages/register_flow_page.dart';
import 'features/feed/feed_page.dart';
import 'features/admin/dashboard_page.dart';
import 'features/bible_quiz/bible_quiz_page.dart';
import 'features/admin/cadastrar_musica_page.dart';
import 'features/admin/cadastrar_video_page.dart';
import 'features/admin/cadastrar_mensagem_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/env.txt');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> _isLoggedIn() async {
    final session = Supabase.instance.client.auth.currentSession;
    return session != null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SeeYou',
      debugShowCheckedModeBanner: false,
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('pt', 'BR'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: FutureBuilder<bool>(
        future: _isLoggedIn(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.data == true) {
            return const FeedPage();
          } else {
            return const LoginPage();
          }
        },
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterFlowPage(),
        '/feed': (context) => const FeedPage(),
        '/admin': (context) => const DashboardPage(),
        '/bible_quiz': (context) => const BibleQuizPage(),
        '/admin/musicas': (context) => const CadastrarMusicaPage(),
        '/admin/videos': (context) => const CadastrarVideoPage(),
        '/admin/mensagens': (context) => const CadastrarMensagemPage(),
      },
    );
  }
}
