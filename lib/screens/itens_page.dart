import 'package:dja_konta/screens/item_form_page.dart';
import 'package:dja_konta/widgets/faixa_sincronizacao.dart';
import 'package:dja_konta/widgets/item_sheet.dart';
import 'package:flutter/material.dart';
import 'package:dja_konta/models/grupo.dart';
import 'package:dja_konta/models/item.dart';
import 'package:dja_konta/services/item_service.dart';
import 'package:dja_konta/screens/scanner_page.dart';
import 'package:dja_konta/screens/gestao_grupo_page.dart';

import 'profile_page.dart';

// Ecrã com os itens de um grupo (em tempo real)
class ItensPage extends StatefulWidget {
  final Grupo grupo;
  const ItensPage({super.key, required this.grupo});

  @override
  ItensPageState createState() => ItensPageState();
}

class ItensPageState extends State<ItensPage> {
  late final Stream<List<Item>> _streamItens;
  final _pesquisaController = TextEditingController();
  String _pesquisa = '';

  List<Item> _itens = []; // últimos itens recebidos (para o scanner procurar)

  @override
  void initState() {
    super.initState();
    // Começa a ouvir uma única vez (não dentro do build)
    _streamItens = ItemService.ouvirItens(widget.grupo.id);
    _pesquisaController.addListener(() {
      setState(() => _pesquisa = _pesquisaController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _pesquisaController.dispose();
    super.dispose();
  }

  // "produtos" nos grupos de stock, "itens" nas salas
  String _palavra(int n) {
    if (widget.grupo.tipo == 'stock') return n == 1 ? 'produto' : 'produtos';
    return n == 1 ? 'item' : 'itens';
  }

  // Filtra os itens pelo texto da pesquisa (nome ou código)
  List<Item> _filtrar(List<Item> itens) {
    if (_pesquisa.isEmpty) return itens;
    return itens
        .where(
          (i) =>
              i.nome.toLowerCase().contains(_pesquisa) ||
              i.codigo.toLowerCase().contains(_pesquisa),
        )
        .toList();
  }

  // Abre o scanner e procura o código lido neste grupo
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

    final existentes = _itens.where((i) => i.codigo == codigo);
    if (existentes.isNotEmpty) {
      _abrirItem(existentes.first, doScanner: true);
    } else if (widget.grupo.isStaff) {
      _novoItem(codigo: codigo);
    } else {
      _aviso('Este código não existe neste grupo.');
    }
  }

  // Abre a folha do item; reage ao que ela devolve ('ler' ou 'editar')
  Future<void> _abrirItem(Item item, {bool doScanner = false}) async {
    final acao = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) =>
          ItemSheet(grupo: widget.grupo, item: item, doScanner: doScanner),
    );

    if (!mounted) return;

    if (acao == 'ler') {
      _lerCodigo();
    } else if (acao == 'editar') {
      // Versão mais recente do item (pode ter mudado com +1/−1)
      final atuais = _itens.where((i) => i.codigo == item.codigo);
      if (atuais.isEmpty) return; // foi removido entretanto

      final resultado = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => ItemFormPage(grupo: widget.grupo, item: atuais.first),
        ),
      );

      if (!mounted) return;

      if (resultado == 'guardado') {
        _aviso('Alterações guardadas.');
      } else if (resultado == 'removido') {
        _aviso('Item removido.');
      }
    }
  }

  // Abre o formulário para criar (com o código do scanner, se houver)
  Future<void> _novoItem({String? codigo}) async {
    final resultado = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true, // abre de baixo para cima, com o X
        builder: (_) => ItemFormPage(grupo: widget.grupo, codigo: codigo),
      ),
    );

    if (!mounted) return;

    if (resultado == 'criado') {
      _aviso('Item adicionado.');
    }
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  // Abre a gestão; se o utilizador saiu, volta também à lista de grupos
  Future<void> _abrirGestao() async {
    final resultado = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => GestaoGrupoPage(grupo: widget.grupo)),
    );
    if (!mounted) return;
    if (resultado == 'saiu') Navigator.pop(context, 'saiu');
  }

  // Abre o perfil com este grupo como "ativo"
  Future<void> _abrirPerfil() async {
    final resultado = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => ProfilePage(grupo: widget.grupo)),
    );
    if (!mounted) return;
    if (resultado == 'saiu') Navigator.pop(context, 'saiu');
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;

    // O StreamBuilder fica por fora do Scaffold para os botões
    // também saberem se a lista está vazia
    return StreamBuilder<List<Item>>(
      stream: _streamItens,
      builder: (context, snapshot) {
        _itens = snapshot.data ?? [];

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.grupo.nome),
                const SizedBox(height: 2),
                // Papel do utilizador neste grupo
                Text(
                  widget.grupo.isStaff
                      ? 'Staff · pode editar'
                      : 'Viewer · só consulta',
                  style: TextStyle(fontSize: 12, color: cores.onSurfaceVariant),
                ),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                onSelected: (opcao) {
                  if (opcao == 'gestao') {
                    _abrirGestao();
                  } else if (opcao == 'perfil') {
                    _abrirPerfil();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'gestao',
                    child: Text(
                      widget.grupo.isStaff ? 'Gestão do grupo' : 'Membros',
                    ),
                  ),
                  const PopupMenuItem(value: 'perfil', child: Text('Perfil')),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              const FaixaSincronizacao(),
              _pesquisaCampo(cores),
              Expanded(child: _conteudo(snapshot, cores)),
            ],
          ),
          floatingActionButton: _botoes(cores),
        );
      },
    );
  }

  // Campo de pesquisa (X para limpar, ou scanner quando está vazio)
  Widget _pesquisaCampo(ColorScheme cores) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _pesquisaController,
        decoration: InputDecoration(
          hintText: 'Pesquisar nome ou código',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _pesquisa.isNotEmpty
              ? IconButton(
                  tooltip: 'Limpar',
                  icon: const Icon(Icons.close),
                  onPressed: _pesquisaController.clear,
                )
              : IconButton(
                  tooltip: 'Ler código',
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _lerCodigo,
                ),
          filled: true,
          fillColor: cores.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // Conteúdo: a carregar, erro, vazio ou lista
  Widget _conteudo(AsyncSnapshot<List<Item>> snapshot, ColorScheme cores) {
    if (snapshot.hasError) {
      return const Center(child: Text('Não foi possível carregar os itens.'));
    }
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_itens.isEmpty) return _estadoVazio(cores);

    final visiveis = _filtrar(_itens);
    final baixos = _itens.where((i) => i.stockBaixo).length;
    final estiloContagem = TextStyle(
      fontSize: 12,
      fontFamily: 'monospace',
      color: cores.onSurfaceVariant,
    );

    return Column(
      children: [
        // Contagem: "7 produtos" ... "3 com stock baixo"
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: [
              Text(
                '${_itens.length} ${_palavra(_itens.length)}',
                style: estiloContagem,
              ),
              const Spacer(),
              if (baixos > 0)
                Text('$baixos com stock baixo', style: estiloContagem),
            ],
          ),
        ),

        // A lista (ou "sem resultados" na pesquisa)
        Expanded(
          child: visiveis.isEmpty
              ? Center(
                  child: Text(
                    'Nenhum item encontrado',
                    style: TextStyle(color: cores.onSurfaceVariant),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(
                    bottom: 170,
                  ), // espaço para os botões
                  itemCount: visiveis.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) => _linhaItem(visiveis[i], cores),
                ),
        ),
      ],
    );
  }

  // Grupo sem itens
  Widget _estadoVazio(ColorScheme cores) {
    return Align(
      alignment: const Alignment(0, -0.5),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ilustração (caixa vazia)
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: cores.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 56,
                color: cores.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Ainda não há itens',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              widget.grupo.isStaff
                  ? 'Leia o código de barras de um produto para o adicionar ao inventário.'
                  : 'Os itens aparecem aqui quando o staff os adicionar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cores.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // Botões flutuantes: "+" (só staff, e só com itens) e "Ler código"
  Widget _botoes(ColorScheme cores) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.grupo.isStaff) ...[
          FloatingActionButton.small(
            heroTag: 'novo',
            tooltip: 'Adicionar item',
            onPressed: _novoItem,
            backgroundColor: cores.surface,
            foregroundColor: cores.onSurface,
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 12),
        ],
        // Quadrado, com o ícone por cima do texto
        FloatingActionButton.large(
          heroTag: 'ler',
          tooltip: 'Ler código',
          onPressed: _lerCodigo,
          backgroundColor: cores.primary,
          foregroundColor: cores.onPrimary,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_scanner, size: 32),
              SizedBox(height: 4),
              Text(
                'Ler código',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Uma linha da lista
  Widget _linhaItem(Item item, ColorScheme cores) {
    return ListTile(
      onTap: () => _abrirItem(item),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cores.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.inventory_2_outlined, color: cores.onSurfaceVariant),
      ),
      title: Text(item.nome),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.codigo,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          // Etiqueta só com contorno laranja
          if (item.stockBaixo)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: cores.primary),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 12,
                    color: cores.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Stock baixo',
                    style: TextStyle(fontSize: 11, color: cores.primary),
                  ),
                ],
              ),
            ),
        ],
      ),
      // Quantidade grande à direita, com "un." por baixo
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${item.quantidade}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: item.stockBaixo ? cores.primary : cores.onSurface,
            ),
          ),
          Text(
            'un.',
            style: TextStyle(fontSize: 11, color: cores.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
