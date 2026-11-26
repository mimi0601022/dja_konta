import 'package:dja_konta/services/sync_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:dja_konta/models/item.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'package:dja_konta/data/local_db.dart';
import 'dart:async';


class ItemService {
  // Ouve os itens de um grupo em tempo real.
  // Sempre que algo muda na base de dados, devolve a lista atualizada.
  static Stream<List<Item>> ouvirItens(String grupoId) {
    late final StreamController<List<Item>> controlador;
    StreamSubscription<DatabaseEvent>? subFirebase;
    var servidor = <Item>[]; // últimos dados do Firebase (ou da cópia local)

    // Junta os dados com as operações pendentes e envia para o ecrã
    Future<void> emitir() async {
      final ops = await SyncService.operacoesPorEnviar(grupoId);
      if (controlador.isClosed) return;
      controlador.add(_aplicar(servidor, ops));
    }

    controlador = StreamController<List<Item>>(
      // Corre quando o ecrã começa a ouvir
      onListen: () async {
        //mostra logo a cópia local funciona sem rede
        servidor = await _lerCache(grupoId);
        if (controlador.isClosed) return;
        await emitir();

        //quando a fila muda (nova alteração ou já enviada), recalcula
        SyncService.versao.addListener(emitir);

        //Quando há rede, o Firebase manda os dados reais
        subFirebase = FirebaseDatabase.instance.ref('itens/$grupoId').onValue.listen(
          (evento) async {
            servidor = [
              for (final filho in evento.snapshot.children) Item.fromSnapshot(filho),
            ];
            await _guardarCache(grupoId, servidor); // atualiza a cópia local
            await emitir();
          },
          onError: (Object erro) {
            if (!controlador.isClosed) controlador.addError(erro);
          },
        );
      },

      // Corre quando o ecrã fecha: desliga tudo
      onCancel: () async {
        SyncService.versao.removeListener(emitir);
        await subFirebase?.cancel();
        await controlador.close();
      },
    );

    return controlador.stream;
  }

  //um item
   static Stream<Item?> ouvirItem(String grupoId, String codigo) {
    return ouvirItens(grupoId).map((itens) {
      for (final item in itens) {
        if (item.codigo == codigo) return item;
      }
      return null; // foi removido
    });
  }

  //alterar quantidade
  static Future<String?> alterarQuantidade({
    required String grupoId,
    required String codigo,
    required int delta,
  }) async{
    await SyncService.adicionar(
      tipo: 'delta', 
      grupoId: grupoId,
      codigo: codigo,
      dados:{'delta': delta},
    );
    return null;
  }

  /*---------------------------------- */
  // Substitui a cópia local de um grupo pelos dados novos (tudo ou nada)
  static Future<void> _guardarCache(String grupoId, List<Item> itens) async {
    final db = await LocalDb.db;
    await db.transaction((txn) async {
      await txn.delete('itens', where: 'grupoId = ?', whereArgs: [grupoId]);
      final lote = txn.batch();
      for (final item in itens) {
        lote.insert('itens', item.toMap(grupoId));
      }
      await lote.commit(noResult: true);
    });
  }

  //lê a cópia local dos itens de um grupo (funciona sem rede)
  static Future<List<Item>> _lerCache(String grupoId) async {
    final db = await LocalDb.db;
    final linhas = await db.query(
      'itens',
      where: 'grupoId = ?',
      whereArgs: [grupoId],
    );
    return linhas.map(Item.fromMap).toList();
  }

  // Aplica as operações ainda por enviar por cima dos dados
  // (é isto que dá feedback imediato, mesmo sem rede)
  static List<Item> _aplicar(List<Item> servidor, List<Map<String, Object?>> ops) {
    // Mapa código - item, para encontrar cada item rapidamente
    final mapa = {for (final i in servidor) i.codigo: i};
    final eu = FirebaseAuth.instance.currentUser?.uid ?? '';

    for (final op in ops) {
      final codigo = op['codigo'] as String;
      final dados = SyncService.dadosDe(op);
      final quando = op['criadoEm'] as int;
      final atual = mapa[codigo];

      switch (op['tipo']) {
        case 'delta':
          // +1/−1: soma ao valor atual (nunca abaixo de 0)
          if (atual != null) {
            mapa[codigo] = Item(
              codigo: codigo,
              nome: atual.nome,
              quantidade: max(0, atual.quantidade + (dados['delta'] as int)),
              quantidadeMinima: atual.quantidadeMinima,
              atualizadoEm: quando,
              atualizadoPor: eu,
            );
          }

        case 'criar':
          // Item novo: aparece logo na lista
          mapa[codigo] = Item(
            codigo: codigo,
            nome: dados['nome'] as String,
            quantidade: dados['quantidade'] as int,
            quantidadeMinima: dados['quantidadeMinima'] as int?,
            atualizadoEm: quando,
            atualizadoPor: eu,
          );

        case 'editar':
          // Edição: troca os campos (só se o item existir)
          if (atual != null) {
            mapa[codigo] = Item(
              codigo: codigo,
              nome: dados['nome'] as String,
              quantidade: dados['quantidade'] as int,
              quantidadeMinima: dados['quantidadeMinima'] as int?,
              atualizadoEm: quando,
              atualizadoPor: eu,
            );
          }

        case 'remover':
          // Remoção: desaparece logo da lista
          mapa.remove(codigo);
      }
    }

    final lista = mapa.values.toList();
    lista.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    return lista;
  }


  //criarItem
  static Future<String?> criarItem({
    required String grupoId,
    required String codigo,
    required String nome,
    required int quantidade,
    required int? quantidadeMinima,
  }) async {
    // Verificação local (a definitiva é feita ao sincronizar)
    final atuais = _aplicar(
      await _lerCache(grupoId),
      await SyncService.operacoesPorEnviar(grupoId),
    );
    if (atuais.any((i) => i.codigo == codigo)) {
      return 'Já existe um item com este código.';
    }

    await SyncService.adicionar(
      tipo: 'criar',
      grupoId: grupoId,
      codigo: codigo,
      dados: {
        'nome': nome,
        'quantidade': quantidade,
        'quantidadeMinima': quantidadeMinima,
      },
    );
    return null;
  }

  //editar
  static Future<String?> editarItem({
    required String grupoId,
    required String codigo,
    required String nome,
    required int quantidade,
    required int? quantidadeMinima,
  }) async {
    await SyncService.adicionar(
      tipo: 'editar', 
      grupoId: grupoId,
      codigo: codigo,
      dados: {
        'nome': nome,
        'quantidade': quantidade,
        'quantidadeMinima': quantidadeMinima, // null apaga o mínimo no Firebase
      },
    );
    return null;
  }

  static Future<String?> removerItem({
    required String grupoId,
    required String codigo,
  }) async{
    await SyncService.adicionar(
      tipo: 'remover', 
      grupoId: grupoId,
      codigo: codigo,
    );
    return null;
  }
}