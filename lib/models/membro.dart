import 'package:firebase_database/firebase_database.dart';

class Membro {
  final String uid;
  final String nome;
  final String email;
  final String papel;
  final int entrouEm;

  Membro({
    required this.uid,
    required this.nome,
    required this.email,
    required this.papel,
    required this.entrouEm,
  });

  bool get isStaff => papel == 'staff';

  // Iniciais para o avatar: primeira e última palavra ("Ana Silva" - "AS")
  String get iniciais {
    final partes = nome.trim().split(RegExp(r'\s+'));
    if (partes.first.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes.first[0] + partes.last[0]).toUpperCase();
  }

  factory Membro.fromSnapshot(DataSnapshot snap) {
    return Membro(
      uid: snap.key!,
      nome: snap.child('nome').value as String,
      email: (snap.child('email').value as String),
      papel: (snap.child('papel').value as String),
      entrouEm: (snap.child('entrouEm').value as num).toInt(),
    );
  }
}
