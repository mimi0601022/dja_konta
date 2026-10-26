import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dja_konta/models/grupo.dart';
import 'package:dja_konta/models/item.dart';
import 'package:dja_konta/services/item_service.dart';
import 'package:dja_konta/screens/scanner_page.dart';
import 'package:dja_konta/utils/validator.dart';
import 'package:dja_konta/utils/tempo.dart';
import 'package:dja_konta/services/membro_service.dart';

// Formulário de item: cria (item == null) ou edita (item != null)
// Devolve 'criado', 'guardado' ou 'removido' no pop
class ItemFormPage extends StatefulWidget {
  final Grupo grupo;
  final Item? item; // quando é para editar
  final String? codigo; // vem do scanner
  

  const ItemFormPage({
    super.key,
    required this.grupo,
    this.item,
    this.codigo,
  });

  @override
  ItemFormPageState createState() => ItemFormPageState();
}

class ItemFormPageState extends State<ItemFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _codigoController = TextEditingController();
  final _nomeController = TextEditingController();
  final _quantidadeController = TextEditingController();
  final _minimoController = TextEditingController();

  bool _aGravar = false;
  String? _erro; // erro geral (caixa no topo)
  String? _erroCodigo; // "Já existe um item com este código."
  Future<String?>? _futureNome;

  // Para não repetir widget.item != null por todo o lado
  bool get _editar => widget.item != null;

  String get _palavra => widget.grupo.tipo == 'stock' ? 'produto' : 'item';


  @override
  void initState() {
    super.initState();

    final item = widget.item;
    if (item != null) {
      // Edição: preenche tudo com os dados do item
      _codigoController.text = item.codigo;
      _nomeController.text = item.nome;
      _quantidadeController.text = item.quantidade.toString();
      _minimoController.text = item.quantidadeMinima?.toString() ?? '';

      //
      _futureNome = MembroService.lerNome(grupoId: widget.grupo.id, uid: item.atualizadoPor);
    } else {
      // Criação: só o código, se veio do scanner
      _codigoController.text = widget.codigo ?? '';
    }
  }

  @override
  void dispose() {
    _codigoController.dispose();
    _nomeController.dispose();
    _quantidadeController.dispose();
    _minimoController.dispose();
    super.dispose();
  }

  // Lê o código com a câmara e põe-no no campo
  Future<void> _lerCodigo() async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ScannerPage(
          titulo: 'Ler código',
          instrucao: 'Aponte para o código de barras',
        ),
      ),
    );
    if (codigo == null || !mounted) return;
    setState(() {
      _codigoController.text = codigo;
      _erroCodigo = null;
    });
  }

  // Criar ou guardar alterações
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _aGravar = true;
      _erro = null;
      _erroCodigo = null;
    });

    final codigo = _codigoController.text.trim();
    final nome = _nomeController.text.trim();
    final quantidade = int.parse(_quantidadeController.text);
    // Mínimo: só nos grupos de stock, e só se estiver preenchido
    final textoMinimo = _minimoController.text;
    final minimo = (widget.grupo.tipo != 'stock' || textoMinimo.isEmpty)
        ? null
        : int.parse(textoMinimo);

    final erro = _editar
        ? await ItemService.editarItem(
            grupoId: widget.grupo.id,
            codigo: codigo,
            nome: nome,
            quantidade: quantidade,
            quantidadeMinima: minimo,
          )
        : await ItemService.criarItem(
            grupoId: widget.grupo.id,
            codigo: codigo,
            nome: nome,
            quantidade: quantidade,
            quantidadeMinima: minimo,
          );

    if (!mounted) return;

    if (erro != null) {
      setState(() {
        // "Já existe..." aparece no próprio campo do código
        if (erro.startsWith('Já existe')) {
          _erroCodigo = erro;
        } else {
          _erro = erro;
        }
        _aGravar = false;
      });
      return;
    }

    Navigator.pop(context, _editar ? 'guardado' : 'criado');
  }

  // Remover, com confirmação
  Future<void> _remover() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (contextDialogo) => AlertDialog(
        title: Text('Remover $_palavra?'),
        content: const Text('Esta ação não pode ser anulada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contextDialogo, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(contextDialogo, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() {
      _aGravar = true;
      _erro = null;
    });

    final erro = await ItemService.removerItem(
      grupoId: widget.grupo.id,
      codigo: widget.item!.codigo,
    );

    if (!mounted) return;

    if (erro != null) {
      setState(() {
        _erro = erro;
        _aGravar = false;
      });
      return;
    }

    Navigator.pop(context, 'removido');
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;

    // Texto por baixo do código: edição, scanner ou nada
    final veioDoScanner = !_editar && widget.codigo != null;
    String? ajudaCodigo;
    if (_editar) {
      ajudaCodigo = 'O código não pode ser alterado';
    } else if (veioDoScanner) {
      ajudaCodigo = 'Lido pelo scanner';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_editar ? 'Editar $_palavra' : 'Novo $_palavra'),
      ),
      body: Column(
        children: [
          // Campos (com scroll, para o teclado não tapar)
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Caixa de erro geral
                  if (_erro != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cores.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: cores.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_erro!,
                                style: TextStyle(color: cores.onErrorContainer)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if(!_editar && widget.codigo != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cores.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.qr_code_2),
                          Expanded(
                            child: Text('Código não existe neste grupo. Preencha os dados para o adicionar.',
                                style: TextStyle(color: cores.onErrorContainer)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Código (bloqueado na edição: é a chave no Firebase)
                  TextFormField(
                    controller: _codigoController,
                    enabled: !_editar,
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      labelText: 'Código',
                      border: const OutlineInputBorder(),
                      helperText: ajudaCodigo,
                      errorText: _erroCodigo,
                      filled: _editar || veioDoScanner, // cinzento quando já vem preenchido
                      fillColor: cores.surfaceContainerHighest,
                      suffixIcon: _editar
                          ? null
                          : IconButton(
                              tooltip: 'Ler código',
                              icon: const Icon(Icons.qr_code_scanner),
                              onPressed: _lerCodigo,
                            ),
                    ),
                    validator: (valor) {
                      final texto = valor?.trim() ?? '';
                      if (texto.isEmpty) return 'Obrigatório';
                      // Chaves do Firebase não aceitam . $ # [ ] /
                      if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(texto)) {
                        return 'Só letras e números';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Nome
                  TextFormField(
                    controller: _nomeController,
                    textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                      labelText: 'Nome *',
                      hintText: 'ex.: Feijão Pedra 1 kg',
                      border: OutlineInputBorder(),
                    ),
                    validator: (valor) => Validator.validateName(name: valor),
                  ),
                  const SizedBox(height: 16),

                  // Quantidade + Stock mínimo lado a lado
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _quantidadeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: 'Quantidade *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (valor) =>
                              (valor == null || valor.isEmpty) ? 'Obrigatório' : null,
                        ),
                      ),
                      // Mínimo só faz sentido em stock
                      if (widget.grupo.tipo == 'stock') ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _minimoController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              labelText: 'Stock mínimo',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  if(!_editar && widget.grupo.tipo == 'stock') ...[
                    const SizedBox(height: 8),
                    Text(
                     '«Stock baixo» quando a quantidade for igual ou inferior ao mínimo.',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: cores.onSurfaceVariant,
                      ),
                    ),
                  ],

                  // Última alteração (só na edição)
                  if (_editar) ...[
                    const SizedBox(height: 16),
                    FutureBuilder<String?>(
                      future: _futureNome,
                      builder: (context, snapNome) {
                        final quando = tempoDesde(widget.item!.dataAtualizacao);
                        final quem = snapNome.data != null ? '${snapNome.data} · ' : '';
                        return Text(
                          'Última alteração: $quem$quando',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: cores.onSurfaceVariant,
                          ),
                        );
                      },
                    ),
                  ],
                  
                ],
              ),
            ),
          ),

          // Botões em baixo
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    onPressed: _aGravar ? null : _guardar,
                    child: _aGravar
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_editar ? 'Guardar alterações' : 'Guardar $_palavra'),
                  ),
                  if (_editar) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        foregroundColor: cores.error,
                        side: BorderSide(color: cores.error),
                      ),
                      onPressed: _aGravar ? null : _remover,
                      icon: const Icon(Icons.delete_outline),
                      label: Text('Remover $_palavra'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}