import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';


// Serviço de autenticação: comunica com o Firebase Authentication
class AuthService {
  // Regista um novo utilizador. Devolve null se correu bem, ou a mensagem de erro
  static Future<String?> registerUsingEmailPassword({
    required String name,
    required String apelido,
    required String email,
    required String password,

  }) async {

    try {
      // Cria a conta no Firebase
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      
      final user = userCredential.user!;

      // Guarda o nome completo no perfil do utilizador
      await userCredential.user!.updateDisplayName('$name $apelido');

      await FirebaseDatabase.instance.ref('utilizadores/${user.uid}').set({
        'nome': name,
        'apelido': apelido,
        'email': user.email // o email da conta (igual ao que a regra verifica)
      });
    
      await verifyEmail();
      return null; // sucesso

    } on FirebaseAuthException catch (e) {
      // Os códigos do Firebase são fixos, em inglês
      switch (e.code) {
        case 'email-already-in-use':
          return 'Este email já tem conta';
        case 'invalid-email':
          return 'Introduza um email válido';
        case 'weak-password':
          return 'Mínimo de 8 caracteres';
        case 'network-request-failed':
          return 'Sem ligação à internet. Tente novamente.';
        default:
          return 'Não foi possível criar a conta. Tente novamente.';
      }
    } catch (e) {
      // Outros erros inesperados
      return 'Ocorreu um erro inesperado. Tente novamente.';
    }
  }

  // Autentica um utilizador já registado. Devolve null se correu bem, ou a mensagem de erro
  static Future<String?> signInUsingEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      return null; // sucesso
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        // Mensagem genérica: não revela qual dos campos falhou
        case 'invalid-credential':
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-email':
          return 'Email ou palavra-passe incorretos. Verifique os dados e tente novamente.';
        case 'too-many-requests':
          return 'Demasiadas tentativas. Aguarde um pouco e tente novamente.';
        case 'network-request-failed':
          return 'Sem ligação à internet. Tente novamente.';
        default:
          return 'Não foi possível entrar. Tente novamente.';
      }
    } catch (e) {
      return 'Ocorreu um erro inesperado. Tente novamente.';
    }
  }

  // Termina a sessão
  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  // Envia um email de verificação ao utilizador com sessão iniciada
  static Future<void> verifyEmail() async {
    await FirebaseAuth.instance.currentUser?.sendEmailVerification();
  }

}


