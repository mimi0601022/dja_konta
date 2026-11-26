import 'dart:math';

import 'package:dja_konta/models/convite.dart';
import 'package:dja_konta/models/membro.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dja_konta/services/group_service.dart';
import 'package:firebase_core/firebase_core.dart';

class MembroService {
  static Stream<List<Membro>> ouvirMembros(String grupoId) {
    return FirebaseDatabase.instance.ref('membros/$grupoId').onValue.map((
      evento,
    ) {
      final membros = <Membro>[]; // lista nova a cada atualização

      for (final filho in evento.snapshot.children) {
        membros.add(Membro.fromSnapshot(filho)); 
      }

      // Ordena por nome
      membros.sort(
        (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()),
      );

      return membros;
    });
  }

  //ler nome da ultima pessoa que alterou
  static Future<String?> lerNome({
    required String grupoId,
    required String uid,
  }) async{
    try{

      final snap = await FirebaseDatabase.instance.ref('membros/$grupoId/$uid/nome').get();

      if(snap.exists) return snap.value as String;

      return null;
    } catch (e) {
      return 'Ocorreu um erro inesperado. Tente novamente.';
    }
  }

  //alterar papel
  static Future<String?> alterarPapel({
    required String grupoId,
    required String uid,
    required String papel,
  }) async {
    try {
      final ref = FirebaseDatabase.instance.ref('membros/$grupoId/$uid');

      await ref.update({'papel': papel});

      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied'){
        return 'Não tem permissão para alterar o papel.';
      }
      return 'Sem ligação à internet. Tente novamente.';
    } catch (e) {
      return 'Ocorreu um erro inesperado. Tente novamente.';
    }
  }

  //remover
  static Future<String?> removerMembro({
    required String grupoId,
    required String uid,
  }) async {
    try {
      final ref = FirebaseDatabase.instance.ref();

      await ref.update({
        'membros/$grupoId/$uid': null,
        'gruposUtilizador/$uid/$grupoId': null,
      });

      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied'){
        return 'Não tem permissão para remover este membro.';
      }
      return 'Sem ligação à internet. Tente novamente.';
    } catch (e) {
      return 'Ocorreu um erro inesperado. Tente novamente.';
    }
  }

  //sair
  static Future<String?> sairDoGrupo({required String grupoId}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 'Sessão expirada. Entre novamente.';
      final uid = user.uid;

      final ref = FirebaseDatabase.instance.ref();
      await ref.update({
        'membros/$grupoId/$uid': null,
        'gruposUtilizador/$uid/$grupoId': null,
      });

      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied'){
        return 'Não foi possível sair do grupo.';
      }
      return 'Sem ligação à internet. Tente novamente.';
    } catch (e) {
      return 'Ocorreu um erro inesperado. Tente novamente.';
    }
  }

  //obterConvite
  // Convite atual do grupo (null se ainda não tiver nenhum)
  static Future<Convite?> obterConvite(String grupoId) async {
    try {
      final ref = FirebaseDatabase.instance.ref();

      // Qual é o código? (está guardado no próprio grupo)
      final codigoSnap = await ref.child('grupos/$grupoId/codigoConvite').get();
      if (!codigoSnap.exists) return null;
      final codigo = codigoSnap.value as String;

      // Quando foi criado? (está no convite)
      final conviteSnap = await ref.child('convites/$codigo').get();
      if (!conviteSnap.exists) return null;
      final criadoEm = (conviteSnap.child('criadoEm').value as num).toInt();

      return Convite(
        codigo: codigo,
        expiraEm: DateTime.fromMillisecondsSinceEpoch(criadoEm)
            .add(GroupService.validadeConvite),
      );
    } catch (e) {
      return null; // sem convite visível: o ecrã mostra "Gerar código"
    }
  }

  //gerarConvite
  static String _gerarCod(){
    // Conjunto de caracteres permitidos
      const caracteresPermitidos =
          'ABCDEFGHJKMNPQRSTUVWXYZ' // Letras maiúsculas sem O, I, L
          '23456789'; // Dígitos sem 0 e 1

      final random = Random.secure();
      final buffer = StringBuffer();

      for (int i = 0; i < 6; i++) {
        final index = random.nextInt(caracteresPermitidos.length);
        buffer.write(caracteresPermitidos[index]);
      }

    return buffer.toString();
  }

  static Future<String?> gerarConvite({
    required String grupoId,
    required String? codigoAntigo,
  }) async {
    try {
      final ref = FirebaseDatabase.instance.ref();
      String novo;
      DataSnapshot snapshot;

      do {
        novo = _gerarCod();
        snapshot = await ref.child('convites/$novo').get();
      } while (snapshot.exists);

      await ref.update({
        if (codigoAntigo != null) 'convites/$codigoAntigo': null,
        'convites/$novo':{
          'grupoId': grupoId,
          'criadoEm': ServerValue.timestamp,
        },
        'grupos/$grupoId/codigoConvite': novo,
      });
      return null;
    }  on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return 'Só o staff pode gerar convites.';
      return 'Não foi possível gerar convite. Tente novamente.';
    }catch (e) {
      return 'Ocorreu um erro inesperado. Tente novamente.'; // sem convite visível: o ecrã mostra "Gerar código;
    }
  }
}
