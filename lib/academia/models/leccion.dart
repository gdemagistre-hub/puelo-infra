class Leccion {
  const Leccion({
    required this.id,
    required this.titulo,
    required this.resumen,
    required this.cuerpo,
    required this.minutos,
    required this.tag,
  });

  final String id;
  final String titulo;
  final String resumen;
  final String cuerpo;
  final int minutos;
  final String tag;
}
