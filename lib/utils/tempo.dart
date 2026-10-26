// Texto relativo: "agora mesmo", "há 2 min", "há 3 h", "há 5 dias"
String tempoDesde(DateTime data) {
  final diff = DateTime.now().difference(data);
  if (diff.inMinutes < 1) return 'agora mesmo';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'há ${diff.inHours} h';
  return 'há ${diff.inDays} ${diff.inDays == 1 ? 'dia' : 'dias'}';
}