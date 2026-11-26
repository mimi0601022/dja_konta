import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:dja_konta/data/local_db.dart';
import 'package:dja_konta/services/conexao_service.dart';

enum _Resultado { aceite, recusada, falhou }

// Fila de operações offline (SQLite) e envio para o Firebase (reconciliação)
class SyncService {
  static final pendentes = ValueNotifier<int>(0); // nº na faixa "N alterações"
  static final versao = ValueNotifier<int>(0); // muda sempre que a fila muda
  static final aviso = ValueNotifier<String?>(null); // mensagens da reconciliação

  static final _aEnviar = <int>{}; // ids que estão a ser enviados agora
  static bool _aSincronizar = false;
  static bool _iniciado = false;

  static void iniciar() {
    if (_iniciado) return;
    _iniciado = true;
    // Quando a ligação volta, envia o que estiver na fila
    ConexaoService.online.addListener(() {
      if (ConexaoService.online.value) sincronizar();
    });
    atualizar();
    sincronizar();
  }

  // Guarda uma operação na fila; se houver rede, tenta enviar já
  static Future<void> adicionar({
    required String tipo, // 'delta', 'criar', 'editar', 'remover'
    required String grupoId,
    required String codigo,
    Map<String, dynamic>? dados,
  }) async {
    final db = await LocalDb.db;
    await db.insert('operacoes', {
      'tipo': tipo,
      'grupoId': grupoId,
      'codigo': codigo,
      'dados': jsonEncode(dados ?? {}),
      'criadoEm': DateTime.now().millisecondsSinceEpoch,
    });
    await atualizar();
    if (ConexaoService.online.value) sincronizar(); // sem await: corre em segundo plano
  }

  // Operações de um grupo ainda por enviar (para mostrar no ecrã por cima dos dados)
  static Future<List<Map<String, Object?>>> operacoesPorEnviar(String grupoId) async {
    final db = await LocalDb.db;
    final linhas = await db.query(
      'operacoes',
      where: 'grupoId = ?',
      whereArgs: [grupoId],
      orderBy: 'id',
    );
    // As que já estão a caminho do Firebase já aparecem nos dados dele
    return linhas.where((l) => !_aEnviar.contains(l['id'])).toList();
  }

  static Map<String, dynamic> dadosDe(Map<String, Object?> op) {
    final texto = op['dados'] as String?;
    if (texto == null || texto.isEmpty) return {};
    return jsonDecode(texto) as Map<String, dynamic>;
  }

  // Recalcula o nº de pendentes e avisa quem estiver a ouvir
  static Future<void> atualizar() async {
    final db = await LocalDb.db;
    final n = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM operacoes'),
        ) ??
        0;
    pendentes.value = n;
    versao.value++;
  }

  // Envia a fila por ordem, uma operação de cada vez
  static Future<void> sincronizar() async {
    if (_aSincronizar) return; // já está a correr: não envia nada duas vezes
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _aSincronizar = true;
    var recusadas = 0;

    try {
      final db = await LocalDb.db;
      while (ConexaoService.online.value) {
        final linhas = await db.query('operacoes', orderBy: 'id', limit: 1);
        if (linhas.isEmpty) break; // fila vazia

        final op = linhas.first;
        final id = op['id'] as int;

        _aEnviar.add(id);
        final resultado = await _enviar(op, uid);

        if (resultado == _Resultado.falhou) {
          // Problema de rede: fica na fila para a próxima vez
          _aEnviar.remove(id);
          break;
        }

        if (resultado == _Resultado.recusada) recusadas++;
        await db.delete('operacoes', where: 'id = ?', whereArgs: [id]);
        _aEnviar.remove(id);
        await atualizar();
      }
    } finally {
      _aSincronizar = false;
    }

    if (recusadas > 0) {
      aviso.value = recusadas == 1
          ? '1 alteração foi recusada: o item mudou entretanto.'
          : '$recusadas alterações foram recusadas: os itens mudaram entretanto.';
    }
  }

  // Envia uma operação
  static Future<_Resultado> _enviar(Map<String, Object?> op, String uid) async {
    final grupoId = op['grupoId'] as String;
    final codigo = op['codigo'] as String;
    final dados = dadosDe(op);
    final ref = FirebaseDatabase.instance.ref('itens/$grupoId/$codigo');

    try {
      switch (op['tipo']) {
        case 'delta':
          // increment: o servidor soma. Vários telemóveis offline nunca perdem contagens.
          // Se ficasse abaixo de 0, as regras recusam.
          await ref.update({
            'quantidade': ServerValue.increment(dados['delta'] as int),
            'atualizadoEm': ServerValue.timestamp,
            'atualizadoPor': uid,
          });

        case 'criar':
          // Se outro membro criou o mesmo código entretanto, não substitui
          final existe = await ref.get();
          if (existe.exists) return _Resultado.recusada;
          await ref.set({
            'nome': dados['nome'],
            'quantidade': dados['quantidade'],
            'quantidadeMinima': dados['quantidadeMinima'],
            'atualizadoEm': ServerValue.timestamp,
            'atualizadoPor': uid,
          });

        case 'editar':
          // A última edição ganha; mas não ressuscita um item que foi removido
          final existe = await ref.get();
          if (!existe.exists) return _Resultado.recusada;
          await ref.update({
            'nome': dados['nome'],
            'quantidade': dados['quantidade'],
            'quantidadeMinima': dados['quantidadeMinima'], // null apaga o mínimo
            'atualizadoEm': ServerValue.timestamp,
            'atualizadoPor': uid,
          });

        case 'remover':
          // Remover algo que já não existe não é erro
          await ref.remove();
      }
      return _Resultado.aceite;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return _Resultado.recusada;
      debugPrint('Sync falhou: ${e.code}');
      return _Resultado.falhou;
    } catch (e) {
      debugPrint('Sync falhou: $e');
      return _Resultado.falhou;
    }
  }
}