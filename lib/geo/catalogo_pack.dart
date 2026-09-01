/// Parser de catálogos compactos id|nombre|padre|nivel1
class CatalogoPack {
  static List<Map<String, String>> parse(String raw) {
    final out = <Map<String, String>>[];
    for (final line in raw.split('\n')) {
      final t = line.trim();
      if (t.isEmpty) continue;
      final p = t.split('|');
      if (p.length < 4) continue;
      out.add({
        'id': p[0],
        'nombre': p[1],
        'padre': p[2],
        'nivel1': p[3],
      });
    }
    return out;
  }
}
