
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
}