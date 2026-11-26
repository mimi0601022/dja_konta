import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // debugPrint
import 'package:dja_konta/models/grupo.dart';
import 'package:dja_konta/models/item.dart';
import 'package:dja_konta/data/local_db.dart';
import 'dart:async';
import 'conexao_service.dart';


class GroupService {
  // Quanto tempo um convite é válido (as regras também verificam)
  static const validadeConvite = Duration(days: 7);

  static Future<List<Grupo>> _lerGruposCache() async {
    final db = await LocalDb.db;
    final linhas = await db.query(
      'grupos',
    );
    debugPrint('Cache grupos: li ${linhas.length}');
    return linhas.map(Grupo.fromMap).toList();
  }

  static Future<void> _guardarGruposCache(List<Grupo> grupos) async {
    debugPrint('Cache grupos: A GUARDAR ${grupos.length}');
    final db = await LocalDb.db;
    await db.transaction((txn) async {
      await txn.delete('grupos');
      final lote = txn.batch();
      for (final grupo in grupos) {
        lote.insert('grupos', grupo.toMap());
      }
      await lote.commit(noResult: true);
    });
  }


  //criar grupo
  static Future<String?> criarGrupo({
    required String nome,
    required String tipo,
    required String? localizacao,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser; // User? (pode ser null)
      if (user == null) return 'Sessão expirada. Entre novamente.';
      final uid = user.uid; // o identificador do utilizador

      if (!ConexaoService.online.value) {
        return 'Sem ligação. Esta ação precisa de internet.';
      }

      final ref = FirebaseDatabase.instance.ref();

      // Gera um id único para o grupo (ainda não grava nada)
      final grupoId = ref.child('grupos').push().key!;

      final loc = (localizacao == null || localizacao.trim().isEmpty)
          ? null
          : localizacao.trim();

      // Grava os três caminhos numa única escrita (tudo ou nada)
      await ref.update({
        'grupos/$grupoId': {
          'nome': nome.trim(),
          'tipo': tipo,
          'localizacao': loc,
          'criadoPor': uid,
          'criadoEm': ServerValue.timestamp,
        },
        'membros/$grupoId/$uid': {
          'nome': user.displayName,
          'email': user.email,
          'papel': 'staff',
          'entrouEm': ServerValue.timestamp,
        },
        'gruposUtilizador/$uid/$grupoId': true,
      });

      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return 'Não foi possível criar o grupo.';
      return 'Sem ligação à internet. Tente novamente.';
    } catch (e) {
      return 'Ocorreu um erro inesperado. Tente novamente.';
    }
  }

  //ler grupos com o resumo de itens, stock baixo e membros
  // Com rede: lê do Firebase e guarda no SQLite Sem rede: usa o SQLite.
  static Future<List<Grupo>> lerGrupos() async {
    try {
      final user = FirebaseAuth.instance.currentUser; // User? (pode ser null)
      if (user == null) return [];
      final uid = user.uid;

      // Sem rede: nem tenta o Firebase, mostra a última cópia guardada
      if (!ConexaoService.online.value) return _lerGruposCache();

      final ref = FirebaseDatabase.instance.ref();

      // Se a rede não responder em 10 s, desiste (cai no catch - cache)
      final snap = await ref
          .child('gruposUtilizador/$uid')
          .get()
          .timeout(const Duration(seconds: 10));

      // Não pertence a nenhum grupo: a cópia local também fica vazia
      if (!snap.exists) {
        await _guardarGruposCache([]);
        return [];
      }

      final grupos = <Grupo>[];

      for (final filho in snap.children) {
        final grupoId = filho.key!; // o id do grupo (a chave em gruposUtilizador)

        // Lê primeiro o papel, se não existir, já não é membro deste grupo
        final papelSnap = await ref.child('membros/$grupoId/$uid/papel').get();
        if (!papelSnap.exists) continue;

        // Só depois lê os dados do grupo (agora tem permissão)
        final grupoSnap = await ref.child('grupos/$grupoId').get();
        if (!grupoSnap.exists) continue;

        // Resumo: quantos itens e quantos com stock baixo
        final itensSnap = await ref.child('itens/$grupoId').get();
        var nBaixos = 0;
        for (final itemSnap in itensSnap.children) {
          if (Item.fromSnapshot(itemSnap).stockBaixo) nBaixos++;
        }

        // Resumo: quantos membros
        final membrosSnap = await ref.child('membros/$grupoId').get();

        grupos.add(
          Grupo(
            id: grupoId,
            nome: grupoSnap.child('nome').value as String,
            tipo: grupoSnap.child('tipo').value as String,
            localizacao: grupoSnap.child('localizacao').value as String?,
            papel: papelSnap.value as String,
            nItens: itensSnap.children.length,
            nBaixos: nBaixos,
            nMembros: membrosSnap.children.length,
          ),
        );
      }

      // Guarda para a próxima vez que abrir sem rede
      await _guardarGruposCache(grupos);
      return grupos;
    } catch (e) {
      // Sem rede, timeout ou erro do Firebase: mostra a última cópia guardada
      debugPrint('lerGrupos: a usar a cópia local ($e)');
      return _lerGruposCache();
    }
  }

  //entrar no grupo com codigo
  static Future<String?> entrarComCodigo({required String cod}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 'Sessão expirada. Entre novamente.';
      final uid = user.uid;

      if (!ConexaoService.online.value) {
        return 'Sem ligação. Esta ação precisa de internet.';
      }

      final ref = FirebaseDatabase.instance.ref();

      final codigo = cod.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
      if (codigo.isEmpty) return 'Introduza o código';

      // Só letras e números (evita caracteres proibidos nos caminhos do Firebase)
      if (!RegExp(r'^[A-Z0-9]+$').hasMatch(codigo)) {
        return 'Código inválido ou expirado';
      }

      final conviteSnap = await ref.child('convites/$codigo').get();
      if (!conviteSnap.exists) return 'Código inválido ou expirado';

      // Convite com mais de 7 dias já não serve
      final criadoEm = (conviteSnap.child('criadoEm').value as num).toInt();
      final expiraEm =
          DateTime.fromMillisecondsSinceEpoch(criadoEm).add(validadeConvite);
      if (DateTime.now().isAfter(expiraEm)) return 'Código inválido ou expirado';

      final grupoId = conviteSnap.child('grupoId').value as String;

      final jaMembro = await ref.child('gruposUtilizador/$uid/$grupoId').get();
      if (jaMembro.exists) return 'Já pertence a este grupo';

      await ref.update({
        'membros/$grupoId/$uid': {
          'nome': user.displayName,
          'email': user.email,
          'papel': 'viewer',
          'entrouEm': ServerValue.timestamp,
          'codigoConvite': codigo, // a regra usa isto para confirmar que o convite é deste grupo
        },
        'gruposUtilizador/$uid/$grupoId': true,
      });

      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return 'Código inválido ou expirado.';
      return 'Não foi possível entrar no grupo. Tente novamente.';
    } catch (e) {
      return 'Ocorreu um erro inesperado. Tente novamente.';
    }
  }
}