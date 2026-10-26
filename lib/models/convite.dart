class Convite {
  final String codigo;          // código de barras/QR (é a chave na base de dados)
  final DateTime expiraEm;

  Convite({
    required this.codigo,
    required this.expiraEm,
  });

  bool get expirado => DateTime.now().isAfter(expiraEm);

  // "K7QM2X" → "K7Q-2MX" (só para mostrar; o código guardado não tem hífen)
  String get formatado => '${codigo.substring(0, 3)}-${codigo.substring(3)}';
}