import 'package:dja_konta/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:dja_konta/utils/validator.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  // Controladores dos campos de texto
  final _emailTextController = TextEditingController();
  final _passwordTextController = TextEditingController();

  bool _obscurePassword = true; // esconder/mostrar palavra-passe
  bool _isLoading = false;      // a autenticar
  String? _loginError;          // mensagem da caixa de alerta (wireframe 1b)

  @override
  void initState() {
    super.initState();
    // Redesenha o ecrã quando o texto muda (para ativar/desativar o botão)
    _emailTextController.addListener(() => setState(() {}));
    _passwordTextController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailTextController.dispose();
    _passwordTextController.dispose();
    super.dispose();
  }

  // O botão só fica ativo com os dois campos preenchidos
  bool get _canSubmit =>
      _emailTextController.text.trim().isNotEmpty &&
      _passwordTextController.text.isNotEmpty &&
      !_isLoading;

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _loginError = null;
    });

    final erro = await AuthService.signInUsingEmailPassword(
      email: _emailTextController.text.trim(),
      password: _passwordTextController.text,
    );

    if (!mounted) return; // o ecrã pode já ter sido fechado

    setState(() {
      _isLoading = false;
      _loginError = erro;
    });

    // Em caso de erro, limpa a palavra-passe e mantém o email
    if (erro != null) _passwordTextController.clear();
    // Se correu bem, o StreamBuilder do main.dart muda de ecrã sozinho
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                // Ocupa o espaço que sobra do ecrã (para o link ir para o fundo)
                sliver: SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    // Estica os filhos na largura (o ListView fazia isto sozinho)
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logótipo (por agora, um quadrado no lugar da imagem)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: cores.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'DK?',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: cores.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Título e subtítulo
                      const Text(
                        'Dja Konta?',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Entre para gerir o inventário do seu negócio.',
                        style: TextStyle(fontSize: 14, color: cores.onSurfaceVariant),
                      ),
                      const SizedBox(height: 24),

                      // Caixa de alerta (wireframe 1b), só aparece quando há erro
                      if (_loginError != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: cores.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.error_outline, color: cores.error, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _loginError!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: cores.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Campo do email
                      TextFormField(
                        controller: _emailTextController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        validator: (value) => Validator.validateEmail(email: value),
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Campo da palavra-passe, com o olho para mostrar/esconder
                      TextFormField(
                        controller: _passwordTextController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (_canSubmit) _signIn();
                        },
                        validator: (value) =>
                            (value == null || value.isEmpty) ? 'Obrigatório' : null,
                        decoration: InputDecoration(
                          labelText: 'Palavra-passe',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Mostrar palavra-passe'
                                : 'Esconder palavra-passe',
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () =>
                                setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Botão Entrar (desativado até os dois campos estarem preenchidos)
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _canSubmit ? _signIn : null,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Entrar'),
                        ),
                      ),

                      // Empurra o link para o fundo do ecrã
                      const Spacer(),
                      const SizedBox(height: 16), // espaço mínimo em ecrãs pequenos

                      // Link para criar conta (fica no fundo)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Ainda não tem conta?',
                            style: TextStyle(fontSize: 14, color: cores.onSurfaceVariant),
                          ),
                          TextButton(
                            onPressed: () {
                              // Abre o ecrã de registo
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const RegisterPage()),
                              );
                            },
                            child: const Text(
                              'Criar conta',
                              style: TextStyle(decoration: TextDecoration.underline),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}