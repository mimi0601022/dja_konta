import 'package:flutter/material.dart';
import 'package:dja_konta/services/group_service.dart';
import 'package:dja_konta/utils/validator.dart';

// Ecrã para criar um novo grupo (inventário)
class CriarGrupoPage extends StatefulWidget {
  const CriarGrupoPage({super.key});

  @override
  CriarGrupoPageState createState() => CriarGrupoPageState();
}

class CriarGrupoPageState extends State<CriarGrupoPage> {
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _localizacaoController = TextEditingController();
  String _tipo = 'stock'; // 'stock' ou 'sala'

  bool _isLoading = false; // a criar o grupo
  String? _erro;           // erro devolvido pelo serviço

  @override
  void dispose() {
    _nomeController.dispose();
    _localizacaoController.dispose();
    super.dispose();
  }

  Future<void> _criar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _erro = null;
    });

    final erro = await GroupService.criarGrupo(
      nome: _nomeController.text.trim(),
      tipo: _tipo,
      localizacao: _localizacaoController.text, // o serviço trata do vazio
    );

    if (!mounted) return; // o ecrã pode já ter sido fechado

    if (erro == null) {
      // Sucesso: fecha o ecrã e avisa a lista de grupos (true = criado)
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isLoading = false;
        _erro = erro;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        // X para fechar (em vez da seta para trás)
        leading: IconButton(
          tooltip: 'Fechar',
          icon: const Icon(Icons.close),
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
        ),
        title: const Text('Criar grupo'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Conteúdo com scroll
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  children: [
                    // Texto de explicação
                    Text(
                      'Dê um nome ao inventário. Pode ser a loja, o armazém ou a secção.',
                      style: TextStyle(fontSize: 14, color: cores.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),

                    // Caixa de erro, só se existir
                    if (_erro != null) ...[
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
                                _erro!,
                                style: TextStyle(fontSize: 14, color: cores.onErrorContainer),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Nome do grupo (obrigatório, máx. 40 caracteres, com contador)
                    TextFormField(
                      controller: _nomeController,
                      autofocus: true,
                      maxLength: 40, // mostra o contador "14/40" sozinho
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!_isLoading) _criar();
                      },
                      validator: (value) => Validator.validateName(name: value),
                      decoration: const InputDecoration(
                        labelText: 'Nome do grupo',
                        helperText: 'Visível para todos os membros',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'stock',
                          label: Text('Stock'),
                          icon: Icon(Icons.storefront_outlined),
                        ),
                        ButtonSegment(
                          value: 'sala',
                          label: Text('Sala'),
                          icon: Icon(Icons.meeting_room_outlined),
                        ),
                      ],
                      selected: {_tipo},
                      onSelectionChanged: (escolha) =>
                          setState(() => _tipo = escolha.first),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _localizacaoController,
                      maxLength: 100,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Localização (opcional)',
                        hintText: 'Ex.: Edifício B, piso 1',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                   

                    // Caixa de informação sobre o papel staff
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cores.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.shield_outlined, size: 20, color: cores.onSurfaceVariant),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                style: TextStyle(fontSize: 14, color: cores.onSurface),
                                children: const [
                                  TextSpan(text: 'Ficará como '),
                                  TextSpan(
                                    text: 'staff',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  TextSpan(
                                    text: ' deste grupo e poderá convidar outros membros.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Botão "Criar grupo" fixo em baixo (sobe com o teclado)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _criar,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Criar grupo'),
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