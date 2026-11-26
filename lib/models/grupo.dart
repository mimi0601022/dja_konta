
class Grupo {

  final String id;
  final String nome;
  final String tipo;
  final String? localizacao;
  final String papel;

  // Resumo para a página inicial (contados ao ler os grupos)
  final int nItens;
  final int nBaixos;
  final int nMembros;

  Grupo({
    required this.id,
    required this.nome,
    required this.tipo,
    this.localizacao,
    required this.papel,
    this.nItens = 0,
    this.nBaixos = 0,
    this.nMembros = 0,
  });

 //para saber se o utilizador pode editar
  bool get isStaff => papel == 'staff';

  factory Grupo.fromMap(Map<String, Object?> m) => Grupo(
    id: m['id'] as String,
    nome: m['nome'] as String,
    tipo: m['tipo'] as String,
    localizacao: m['localizacao'] as String?,
    papel: m['papel'] as String,
    nItens: m['nItens'] as int,
    nBaixos: m['nBaixos'] as int,
    nMembros: m['nMembros'] as int,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'nome': nome,
    'tipo': tipo,
    'localizacao': localizacao,
    'papel': papel,
    'nItens': nItens,
    'nBaixos': nBaixos,
    'nMembros': nMembros,
  };
}