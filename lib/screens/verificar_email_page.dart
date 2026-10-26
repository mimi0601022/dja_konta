import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dja_konta/services/auth_service.dart';

// Aparece quando há sessão mas o email ainda não foi verificado.
// Quando fica verificado, o main.dart troca de ecrã sozinho (userChanges).
class VerificarEmailPage extends StatefulWidget {
  const VerificarEmailPage({super.key});

  @override
  VerificarEmailPageState createState() => VerificarEmailPageState();
}

class VerificarEmailPageState extends State<VerificarEmailPage> {
  bool _aVerificar = false;
  bool _aEnviar = false;

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  // "Já verifiquei": vai buscar o estado mais recente ao servidor
  Future<void> _jaVerifiquei() async {
    setState(() {
      _aVerificar = true;
    });

    await FirebaseAuth.instance.currentUser?.reload();

    // Se ficou verificado, o main.dart já trocou de ecrã e este deixou de existir
    if (!mounted) return;

    setState(() {
      _aVerificar = false;
    });

    if (!(FirebaseAuth.instance.currentUser?.emailVerified ?? false)) {
      _aviso('O email ainda não foi verificado.');
    }
  }

  // Reenviar o email de verificação
  Future<void> _reenviar() async {
    setState(() {
      _aEnviar = true;
    });

    try {
      await AuthService.verifyEmail();
      if (!mounted) return;
      _aviso('Email reenviado.');
    } catch (e) {
      // O Firebase limita reenvios seguidos (too-many-requests)
      if (!mounted) return;
      _aviso('Aguarde um pouco antes de reenviar.');
    }

    if (!mounted) return;
    setState(() {
      _aEnviar = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.mark_email_unread_outlined, size: 72, color: cores.primary),
              const SizedBox(height: 24),
              const Text(
                'Verifique o seu email',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                'Enviámos um link para «$email». Abra-o e depois volte aqui.\n'
                'Se não o encontrar, veja também a pasta de spam.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: cores.onSurfaceVariant),
              ),
              const Spacer(),

              // Já verifiquei
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _aVerificar ? null : _jaVerifiquei,
                child: _aVerificar
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Já verifiquei'),
              ),
              const SizedBox(height: 12),

              // Reenviar
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _aEnviar ? null : _reenviar,
                child: const Text('Reenviar email'),
              ),
              const SizedBox(height: 8),

              // Sair (para quem se enganou no email)
              TextButton(
                onPressed: () => AuthService.signOut(),
                child: const Text('Terminar sessão'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}