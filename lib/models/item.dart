import 'package:firebase_database/firebase_database.dart';

// Modelo de um item do inventário
class Item {
  final String codigo;          // código de barras/QR (é a chave na base de dados)
  final String nome;
  final int quantidade;
  final int? quantidadeMinima;  // opcional
  final int atualizadoEm;       // timestamp em milissegundos
  final String atualizadoPor;   // uid de quem alterou

  Item({
    required this.codigo,
    required this.nome,
    required this.quantidade,
    this.quantidadeMinima,
    required this.atualizadoEm,
    required this.atualizadoPor,
  });

  // Stock baixo: só se tiver quantidade mínima definida
  bool get stockBaixo =>
      quantidadeMinima != null && quantidade <= quantidadeMinima!;

  // Data da última atualização, já convertida (para mostrar no ecrã)
  DateTime get dataAtualizacao =>
      DateTime.fromMillisecondsSinceEpoch(atualizadoEm);

  // Cria um Item a partir dos dados da base de dados
  factory Item.fromSnapshot(DataSnapshot snap) {
    return Item(
      codigo: snap.key!,
      nome: snap.child('nome').value as String,
      quantidade: (snap.child('quantidade').value as num).toInt(),
      quantidadeMinima: (snap.child('quantidadeMinima').value as num?)?.toInt(),
      atualizadoEm: (snap.child('atualizadoEm').value as num).toInt(),
      atualizadoPor: snap.child('atualizadoPor').value as String,
    );
  }

  // Linha do SQLite p Item
  factory Item.fromMap(Map<String, Object?> m) => Item(
    codigo: m['codigo'] as String,
    nome: m['nome'] as String,
    quantidade: m['quantidade'] as int,
    quantidadeMinima: m['quantidadeMinima'] as int?,
    atualizadoEm: m['atualizadoEm'] as int,
    atualizadoPor: m['atualizadoPor'] as String,
  );

  // Item p linha do SQLite
  Map<String, Object?> toMap(String grupoId) => {
    'grupoId': grupoId,
    'codigo': codigo,
    'nome': nome,
    'quantidade': quantidade,
    'quantidadeMinima': quantidadeMinima,
    'atualizadoEm': atualizadoEm,
    'atualizadoPor': atualizadoPor,
  };
}