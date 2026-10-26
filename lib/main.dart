import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/groups_page.dart';
import 'screens/login_page.dart';
import 'screens/verificar_email_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dja Konta?',
      debugShowCheckedModeBanner: false, // tira a faixa "DEBUG"
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB8501A),
          primary: const Color(0xFFB8501A), // cor exata dos wireframes
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF1C1C1C), width: 2),
          ),
        ),
      ),

      // userChanges (e não authStateChanges): também avisa quando os dados
      // do utilizador mudam, por ex. depois de verificar o email + reload()
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.userChanges(),
        builder: (context, snapshot) {
          // Enquanto o Firebase verifica se há sessão guardada
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final user = snapshot.data;

          // Sem sessão -  login
          if (user == null) return const LoginPage();

          // Com sessão mas email por verificar . ecrã de verificação
          if (!user.emailVerified) return const VerificarEmailPage();

          // Tudo certo - os meus grupos
          return const GroupsPage();
        },
      ),
    );
  }
}