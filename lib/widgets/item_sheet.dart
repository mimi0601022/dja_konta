import 'package:dja_konta/services/membro_service.dart';
import 'package:flutter/material.dart';
import 'package:dja_konta/models/grupo.dart';
import 'package:dja_konta/models/item.dart';
import 'package:dja_konta/services/item_service.dart';
import 'package:dja_konta/utils/tempo.dart';

// Folha inferior com os detalhes de um item (atualiza em tempo real)
// Devolve 'ler' (ler outro código) ou 'editar' (abrir o formulário) no pop
class ItemSheet extends StatefulWidget {
  final Grupo grupo;
  final Item item;
  final bool doScanner; // true se foi aberta depois de ler um código

  const ItemSheet({
    super.key,
    required this.grupo,
    required this.item,
    this.doScanner = false,
  });

  @override
  ItemSheetState createState() => ItemSheetState();
}

class ItemSheetState extends State<ItemSheet> {
  late final Stream<Item?> _streamItem;
  
  // Nomes já pedidos, por uid (cada uid só é lido uma vez)
  final _nomes = <String, Future<String?>>{};

  Future<String?> _nomeDe(String uid) {
    return _nomes.putIfAbsent(
      uid,
      () => MembroService.lerNome(grupoId: widget.grupo.id, uid: uid),
    );
  }

  String? _erro;

  @override
  void initState() {
    super.initState();
    // Ouve só este item (criado uma vez)
    _streamItem = ItemService.ouvirItem(widget.grupo.id, widget.item.codigo);
  }

  // +1 ou −1
  Future<void> _alterar(int delta) async {
    final erro = await ItemService.alterarQuantidade(
      grupoId: widget.grupo.id,
      codigo: widget.item.codigo,
      delta: delta,
    );
    if (!mounted) return;
    setState(() {
      _erro = erro;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;

    return StreamBuilder<Item?>(
      stream: _streamItem,
      initialData: widget.item, // abre logo com os dados da lista
      builder: (context, snapshot) {
        final item = snapshot.data;

        // Item apagado por outro membro
        if (item == null) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Este item foi removido.'),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Topo: ícone, nome, código, etiqueta e X
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: cores.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.inventory_2_outlined,
                        color: cores.onSurfaceVariant),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.nome,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(item.codigo,
                            style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: cores.onSurfaceVariant)),
                        if (item.stockBaixo) ...[
                          const SizedBox(height: 4),
                          _etiquetaStockBaixo(cores),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Centro: quantidade em destaque
              Text(
                'QUANTIDADE EM STOCK',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: cores.onSurfaceVariant,
                ),
              ),
              Text(
                '${item.quantidade}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w700,
                  color: item.stockBaixo ? cores.primary : cores.onSurface,
                ),
              ),
                            // "Stock mínimo: 10 · atualizado por Ana Silva há 2 min"
              FutureBuilder<String?>(
                future: _nomeDe(item.atualizadoPor),
                builder: (context, snapNome) {
                  final quem = snapNome.data != null ? ' por ${snapNome.data}' : '';
                  final quando = tempoDesde(item.dataAtualizacao);
                  final minimo = item.quantidadeMinima != null
                      ? 'Stock mínimo: ${item.quantidadeMinima} · '
                      : '';
                  return Text(
                    '${minimo}Atualizado$quem $quando',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: cores.onSurfaceVariant),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Erro ao alterar (ex.: abaixo de 0)
              if (_erro != null) ...[
                Text(_erro!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cores.error)),
                const SizedBox(height: 12),
              ],

              // Baixo: depende do papel
              if (widget.grupo.isStaff) ...[
                // −1 / +1
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52)),
                        // Desativado no 0 (nem chega a tentar)
                        onPressed:
                            item.quantidade > 0 ? () => _alterar(-1) : null,
                        child: const Text('−1', style: TextStyle(fontSize: 20)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52)),
                        onPressed: () => _alterar(1),
                        child: const Text('+1', style: TextStyle(fontSize: 20)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Editar: fecha a folha e avisa o ecrã de trás
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, 'editar'),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                ),
              ] else
                // Viewer: só consulta
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cores.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline,
                          size: 18, color: cores.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Só consulta. Peça a um membro staff para alterar o stock.',
                          style: TextStyle(
                              fontSize: 13, color: cores.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),

              // Só quando veio do scanner
              if (widget.doScanner) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                  onPressed: () => Navigator.pop(context, 'ler'),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Ler outro código'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // Igual à da lista: contorno laranja
  Widget _etiquetaStockBaixo(ColorScheme cores) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: cores.primary),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 12, color: cores.primary),
          const SizedBox(width: 4),
          Text('Stock baixo',
              style: TextStyle(fontSize: 11, color: cores.primary)),
        ],
      ),
    );
  }
}