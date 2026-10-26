import 'package:flutter/material.dart';
import 'package:dja_konta/services/auth_service.dart';
import 'package:dja_konta/utils/validator.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  RegisterPageState createState() => RegisterPageState();
}

class RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  // Controladores dos campos de texto
  final _nomeTextController = TextEditingController();
  final _apelidoTextController = TextEditingController();
  final _emailTextController = TextEditingController();
  final _passwordTextController = TextEditingController();
  final _passwordConfirmTextController = TextEditingController();

  bool _obscurePassword = true; // esconder/mostrar palavra-passe
  bool _isLoading = false; // a registar
  bool _submitted =
      false; // já tentou criar conta? (para mostrar os ícones de erro)
  String? _registerError; // erro geral (caixa de alerta)
  String? _emailError; // erro no campo Email («Este email já tem conta»)

  @override
  void initState() {
    super.initState();
    // Redesenha o ecrã quando o texto muda (para ativar/desativar o botão)
    _nomeTextController.addListener(() => setState(() {}));
    _apelidoTextController.addListener(() => setState(() {}));
    _passwordTextController.addListener(() => setState(() {}));
    _passwordConfirmTextController.addListener(() => setState(() {}));
    // No email, também limpa o erro «Este email já tem conta» quando o texto muda
    _emailTextController.addListener(() => setState(() => _emailError = null));
  }

  // Liberta a memória que os controladores ocupam quando o ecrã é fechado
  @override
  void dispose() {
    _nomeTextController.dispose();
    _apelidoTextController.dispose();
    _emailTextController.dispose();
    _passwordTextController.dispose();
    _passwordConfirmTextController.dispose();
    super.dispose();
  }

  // O botão só fica ativo com todos os campos preenchidos
  bool get _canSubmit =>
      _nomeTextController.text.trim().isNotEmpty &&
      _apelidoTextController.text.trim().isNotEmpty &&
      _emailTextController.text.trim().isNotEmpty &&
      _passwordTextController.text.isNotEmpty &&
      _passwordConfirmTextController.text.isNotEmpty &&
      !_isLoading;

  // Ícone (!) para campos com erro, como no wireframe
  Widget? _errorIcon(String? erro) {
    if (!_submitted || erro == null) return null;
    return Icon(
      Icons.error_outline,
      color: Theme.of(context).colorScheme.error,
    );
  }

  Future<void> _signUp() async {
    // Marca a tentativa ANTES de validar, para os ícones aparecerem logo
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _registerError = null;
      _emailError = null;
    });

    final erro = await AuthService.registerUsingEmailPassword(
      name: _nomeTextController.text.trim(),
      apelido: _apelidoTextController.text.trim(),
      email: _emailTextController.text.trim(),
      password: _passwordTextController.text, // a palavra-passe nunca leva trim
    );

    if (!mounted) return; // o ecrã pode já ter sido fechado

    if (erro == null) {
      // Conta criada: fecha o registo e o StreamBuilder do main.dart mostra o perfil
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isLoading = false;
      // «Este email já tem conta» aparece no campo Email (como no wireframe)
      if (erro == 'Este email já tem conta') {
        _emailError = erro;
      } else {
        _registerError = erro;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          // Depois da 1.ª tentativa, valida enquanto o utilizador corrige
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
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
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Venha gerir o inventário do seu negócio.',
                        style: TextStyle(
                          fontSize: 14,
                          color: cores.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Caixa de alerta, só aparece quando há erro geral
                      if (_registerError != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: cores.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: cores.error,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _registerError!,
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

                      // Nome e apelido na mesma linha
                      Row(
                        crossAxisAlignment: CrossAxisAlignment
                            .start, // alinha pelo topo quando há erro
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _nomeTextController,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              validator: (value) =>
                                  Validator.validateName(name: value),
                              decoration: InputDecoration(
                                labelText: 'Nome',
                                border: const OutlineInputBorder(),
                                suffixIcon: _errorIcon(
                                  Validator.validateName(
                                    name: _nomeTextController.text,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _apelidoTextController,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              validator: (value) =>
                                  Validator.validateName(name: value),
                              decoration: InputDecoration(
                                labelText: 'Apelido',
                                border: const OutlineInputBorder(),
                                suffixIcon: _errorIcon(
                                  Validator.validateName(
                                    name: _apelidoTextController.text,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Campo do email
                      TextFormField(
                        controller: _emailTextController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            Validator.validateEmail(email: value),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          border: const OutlineInputBorder(),
                          errorText: _emailError, // «Este email já tem conta»
                          suffixIcon: _errorIcon(
                            _emailError ??
                                Validator.validateEmail(
                                  email: _emailTextController.text,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Campo da palavra-passe (o olho fica no lugar do ícone de erro)
                      TextFormField(
                        controller: _passwordTextController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            Validator.validatePassword(password: value),
                        decoration: InputDecoration(
                          labelText: 'Palavra-passe',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Mostrar palavra-passe'
                                : 'Esconder palavra-passe',
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Campo confirmar palavra-passe
                      TextFormField(
                        controller: _passwordConfirmTextController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (_canSubmit) _signUp();
                        },
                        validator: (value) =>
                            Validator.validateConfirmarPassword(
                              password: _passwordTextController.text,
                              confirmarPassword: value,
                            ),
                        decoration: InputDecoration(
                          labelText: 'Confirmar palavra-passe',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Mostrar palavra-passe'
                                : 'Esconder palavra-passe',
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Botão Criar conta (desativado até todos os campos estarem preenchidos)
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _canSubmit ? _signUp : null,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Criar conta'),
                        ),
                      ),
                      // Empurra o link para o fundo do ecrã
                      const Spacer(),
                      const SizedBox( height: 16), // espaço mínimo em ecrãs pequenos

                      // Link para voltar ao login
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Já tem conta?',
                            style: TextStyle(
                              fontSize: 14,
                              color: cores.onSurfaceVariant,
                            ),
                          ),
                          TextButton(
                            // Volta ao login (que já está por baixo), em vez de abrir outro
                            onPressed: () => Navigator.of(context)
                                .pop(), //ir para o ecra antes que é o login
                            child: const Text(
                              'Entrar',
                              style: TextStyle(
                                decoration: TextDecoration.underline,
                              ),
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
