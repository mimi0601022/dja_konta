import 'package:firebase_database/firebase_database.dart';
import 'package:dja_konta/models/item.dart';
import 'package:firebase_auth/firebase_auth.dart';


class ItemService {
  // Ouve os itens de um grupo em tempo real.
  // Sempre que algo muda na base de dados, devolve a lista atualizada.
  static Stream<List<Item>> ouvirItens(String grupoId) {
    return FirebaseDatabase.instance
        .ref('itens/$grupoId')
        .onValue
        .map((evento) {
      final itens = <Item>[]; // lista nova a cada atualização

      for (final filho in evento.snapshot.children) {
        itens.add(Item.fromSnapshot(filho)); // converte cada filho num Item
      }

      // Ordena por nome (a base de dados devolve ordenado pelo código)
      itens.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

      return itens;
    });
  }

  //alterar quantidade
  static Future<String?> alterarQuantidade({
    required String grupoId,
    required String codigo,
    required int delta,
  }) async{
    try{

      final user = FirebaseAuth.instance.currentUser; // User? (pode ser null)
      if (user == null) return 'Sessão expirada. Entre novamente.';
      final uid = user.uid;

      final ref = FirebaseDatabase.instance.ref('itens/$grupoId/$codigo');

      await ref.update({
        'quantidade': ServerValue.increment(delta),
        'atualizadoEm':ServerValue.timestamp,
        'atualizadoPor': uid,
      });

      return null;
    } on FirebaseException catch (e){
      if (e.code == 'permission-denied') return 'Não é possível ficar abaixo de 0';
      return 'Sem ligação à internet. Tente novamente.';
    } catch (e){
      return 'Ocorreu um erro inesperado. Tente novamente.';
    }
  }

  //um item
  static Stream<Item?> ouvirItem(String grupoId, String codigo) {
    return FirebaseDatabase.instance
        .ref('itens/$grupoId/$codigo')
        .onValue
        .map((evento) {
      
        if(evento.snapshot.exists) {
          return Item.fromSnapshot(evento.snapshot); // 
        }

      return null;
    });
  }

  //criarItem
  static Future<String?> criarItem({
    required String grupoId,
    required String codigo,
    required String nome,
    required int quantidade,
    required int? quantidadeMinima,
  }) async {
    try{
      final user = FirebaseAuth.instance.currentUser; // User? (pode ser null)
      if (user == null) return 'Sessão expirada. Entre novamente.';
      final uid = user.uid;

      final ref = FirebaseDatabase.instance.ref('itens/$grupoId/$codigo');

      final jaExiste = await ref.get();
      if(jaExiste.exists) return 'Já existe um item com este código.';

      await ref.set({
        'nome': nome,
        'quantidade': quantidade,
        'quantidadeMinima': quantidadeMinima,
        'atualizadoEm': ServerValue.timestamp,
        'atualizadoPor': uid,
      });
      return null;
    } on FirebaseException catch (e){
      if (e.code == 'permission-denied') return 'Não tem permissão para adicionar itens.';
      return 'Sem ligação à internet. Tente novamente.';
    } catch (e) {
      return 'Ocorreu um erro inesperado. Tente novamente.';
    }
  }

  //editar
  static Future<String?> editarItem({
    required String grupoId,
    required String codigo,
    required String nome,
    required int quantidade,
    required int? quantidadeMinima,
  }) async {
    try{
    final user = FirebaseAuth.instance.currentUser; // User? (pode ser null)
      if (user == null) return 'Sessão expirada. Entre novamente.';
      final uid = user.uid;

      final ref = FirebaseDatabase.instance.ref('itens/$grupoId/$codigo');

      await ref.update({
        'nome': nome,
        'quantidade': quantidade,
        'quantidadeMinima': quantidadeMinima,
        'atualizadoEm': ServerValue.timestamp,
        'atualizadoPor': uid,
      });
    return null;
    } on FirebaseException catch (e){
      if (e.code == 'permission-denied') return 'Não tem permissão para editar este item.';
      return 'Sem ligação à internet. Tente novamente.';
    } catch (e){
      return 'Ocorreu um erro inesperado. Tente novamente.';
    }
  }

  static Future<String?> removerItem({
    required String grupoId,
    required String codigo,
  }) async{
    try{

      final ref = FirebaseDatabase.instance.ref('itens/$grupoId/$codigo'); 
      await ref.remove();

      return null;
    } on FirebaseException catch (e){
      if (e.code == 'permission-denied') return 'Não tem permissão para remover este item.';
      return 'Sem ligação à internet. Tente novamente.';
    } catch (e){
      return 'Ocorreu um erro inesperado. Tente novamente.';
    }
  }
}