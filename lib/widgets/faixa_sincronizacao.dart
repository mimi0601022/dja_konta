import 'package:flutter/material.dart';
import 'package:dja_konta/services/conexao_service.dart';
import 'package:dja_konta/services/sync_service.dart';

// Faixa laranja no topo: "Sem ligação · N alterações por sincronizar"
// ou "A sincronizar N alterações…". Não aparece quando está tudo em dia
class FaixaSincronizacao extends StatelessWidget {
  const FaixaSincronizacao({super.key});

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;

    // Ouve a ligação...
    return ValueListenableBuilder<bool>(
      valueListenable: ConexaoService.online,//para quando a ligação muda
      builder: (context, online, _) { //_ pq recebo mas nao preciso
        // ...e o número de alterações na fila
        return ValueListenableBuilder<int>(
          valueListenable: SyncService.pendentes,//para quando a fila muda
          builder: (context, n, _) {
            final palavra = n == 1 ? 'alteração' : 'alterações';

            // Sem rede
            if (!online) {
              return _faixa(
                cores,
                icone: Icon(Icons.cloud_off_outlined, size: 16, color: cores.onPrimary),
                texto: n == 0
                    ? 'Sem ligação'
                    : 'Sem ligação · $n $palavra por sincronizar',
              );
            }

            //Com rede, a enviar a fila
            if (n > 0) {
              return _faixa(
                cores,
                icone: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cores.onPrimary,
                  ),
                ),
                texto: 'A sincronizar $n $palavra…',
              );
            }

            // Tudo em dia: não mostra nada
            return const SizedBox.shrink(); //tamanho 0
          },
        );
      },
    );
  }

  // O aspeto da faixa (igual nos dois casos, muda só o ícone e o texto)
  Widget _faixa(ColorScheme cores, {required Widget icone, required String texto}) {
    return Container(
      width: double.infinity,
      color: cores.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          icone,
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(fontSize: 13, color: cores.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}