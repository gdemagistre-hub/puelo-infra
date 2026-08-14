class Leccion {
  const Leccion({
    required this.id,
    required this.titulo,
    required this.resumen,
    required this.cuerpo,
    required this.minutos,
    required this.tag,
    this.audioUrl,
  });

  final String id;
  final String titulo;
  final String resumen;
  final String cuerpo;
  final int minutos;
  final String tag;

  /// URL del MP3 (Hosting PROX o fallback GitHub).
  final String? audioUrl;

  bool get hasAudio => audioUrl != null && audioUrl!.trim().isNotEmpty;
}
