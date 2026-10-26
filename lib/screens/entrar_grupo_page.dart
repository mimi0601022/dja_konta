import 'package:flutter/material.dart';
import 'package:dja_konta/services/group_service.dart';
import 'package:dja_konta/screens/scanner_page.dart';

// Ecrã para entrar num grupo com um código de convite
class EntrarGrupoPage extends StatefulWidget {
  const EntrarGrupoPage({super.key});

  @override
  EntrarGrupoPageState createState() => EntrarGrupoPageState();
}

class EntrarGrupoPageState extends State<EntrarGrupoPage> {
  final _codigoController = TextEditingController();

  bool _isLoading = false;
  String? _erro; // aparece no próprio campo (wireframe)

  @override
  void initState() {
    super.initState();
    // Limpa o erro quando o utilizador muda o código
    _codigoController.addListener(() {
      if (_erro != null) setState(() => _erro = null);
    });
  }

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    setState(() {
      _isLoading = true;
      _erro = null;
    });

    final erro = await GroupService.entrarComCodigo(
      cod: _codigoController.text,
    );

    if (!mounted) return;

    if (erro == null) {
      Navigator.of(context)
          .pop(true); // avisa a lista de grupos (true = entrou)
    } else {
      setState(() {
        _isLoading = false;
        _erro = erro;
      });
    }
  }

  // Abre o scanner e, se ler um código, preenche o campo e tenta entrar
  Future<void> _lerQr() async {
    final lido = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const ScannerPage(
          titulo: 'Ler QR do convite',
          instrucao: 'Aponte para o QR do convite',
        ),
      ),
    );
    if (lido == null || !mounted) return;

    _codigoController.text = lido;
    _entrar();
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;

    return Scaffold(
      // Seta para trás (aparece sozinha), como no wireframe
      appBar: AppBar(title: const Text('Entrar com código')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  // Texto de explicação
                  Text(
                    'Peça o código de convite a um membro staff do grupo.',
                    style: TextStyle(
                      fontSize: 14,
                      color: cores.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Campo do código (letras grandes e espaçadas, erro no próprio campo)
                  TextField(
                    controller: _codigoController,
                    autofocus: true,
                    maxLength: 9, // ex.: K7Q-2MZ
                    textCapitalization:
                        TextCapitalization.characters, // teclado em maiúsculas
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (!_isLoading) _entrar();
                    },
                    style: const TextStyle(
                      fontSize: 24,
                      fontFamily: 'monospace',
                      letterSpacing: 4,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Código de convite',
                      border: const OutlineInputBorder(),
                      counterText: '', // esconde o contador
                      errorText: _erro, // «Código inválido ou expirado»
                      suffixIcon: _erro != null
                          ? Icon(Icons.error_outline, color: cores.error)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botão "Ler QR do convite"
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Ler QR do convite'),
                      onPressed: _isLoading ? null : _lerQr,
                    ),
                  ),
                ],
              ),
            ),

            // Botão "Entrar no grupo" fixo em baixo
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _isLoading ? null : _entrar,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Entrar no grupo'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
