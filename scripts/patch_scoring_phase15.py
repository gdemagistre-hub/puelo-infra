from pathlib import Path

def patch_scoring_service():
    p = Path('lib/scoring_service.dart')
    t = p.read_text()
    if "v1.2-phase1.5" in t and "Validá tu DNI" in t:
        print('scoring_service already patched')
        return

    t = t.replace("static const String modelVersion = 'v1.2-phase1';", "static const String modelVersion = 'v1.2-phase1.5';", 1)

    old_badge = '''  static String? calcularBadgePrestador(
    Map<String, dynamic> data, {
    required int fotosPortfolio,
    required int fotosClientes,
    required int validaciones6mDistintas,
    required int validadoresConCalificacion,
    int nEvalTrabajo = 0,
  }) {
    final registrado = _noVacio(data['nombre']) && _noVacio(data['apellido']) && _noVacio(data['telefono']);
    if (registrado && data['doc_validado'] == true) return 'bronce_plus';
    if (registrado) return 'registrado';
    return 'nuevo';
  }'''

    new_badge = '''  /// Escalera alineada a CF scoringCore:
  /// nuevo → registrado → bronce → bronce_plus (plata/oro más adelante).
  static String? calcularBadgePrestador(
    Map<String, dynamic> data, {
    required int fotosPortfolio,
    required int fotosClientes,
    required int validaciones6mDistintas,
    required int validadoresConCalificacion,
    int nEvalTrabajo = 0,
    int scoreIdentidad = 0,
  }) {
    final registrado = _noVacio(data['nombre']) &&
        _noVacio(data['apellido']) &&
        _noVacio(data['telefono']);
    final docOk = data['doc_validado'] == true;
    final tieneDoc = _noVacio(data['doc_numero'] ?? data['numero_documento']);
    final geo = data['direccion_geo'];
    final tieneZona = geo is Map &&
        (_noVacio(geo['localidad_id']) || _noVacio(geo['localidad_nombre']));
    final perfilFuerte = registrado && (tieneDoc || tieneZona || scoreIdentidad >= 30);

    if (registrado && docOk) return 'bronce_plus';
    if (perfilFuerte && scoreIdentidad >= 35) return 'bronce';
    if (registrado) return 'registrado';
    return 'nuevo';
  }'''

    if old_badge not in t:
        raise SystemExit('badge block not found')
    t = t.replace(old_badge, new_badge, 1)

    old_call = '''        final badge = calcularBadgePrestador(
          d,
          fotosPortfolio: 0,
          fotosClientes: 0,
          validaciones6mDistintas: 0,
          validadoresConCalificacion: 0,
        );'''
    new_call = '''        final badge = calcularBadgePrestador(
          d,
          fotosPortfolio: 0,
          fotosClientes: 0,
          validaciones6mDistintas: 0,
          validadoresConCalificacion: 0,
          scoreIdentidad: id.score,
        );'''
    if old_call in t:
        t = t.replace(old_call, new_call, 1)

    old_tips = "  static List<Map<String, String>> generarConsejosConfianza(Map<String, dynamic> data, {int fotosPortfolio = 0}) => [];"
    new_tips = '''  /// Tips priorizados (máx 6) para "Para subir tu Confianza".
  static List<Map<String, String>> generarConsejosConfianza(
    Map<String, dynamic> data, {
    int fotosPortfolio = 0,
  }) {
    final tips = <Map<String, String>>[];
    void add(String id, String titulo, String sub) {
      if (tips.length >= 6) return;
      tips.add({'id': id, 'titulo': titulo, 'subtitulo': sub});
    }

    final docOk = data['doc_validado'] == true;
    final geo = data['direccion_geo'];
    final tieneZona = geo is Map &&
        (_noVacio(geo['localidad_id']) || _noVacio(geo['localidad_nombre']));
    final profesiones = data['profesiones'] ?? data['categorias_servicio'];
    final tieneOficios = profesiones is List && profesiones.isNotEmpty;
    final capacitaciones = data['capacitaciones'];
    final nCap = capacitaciones is List ? capacitaciones.length : 0;

    if (!_noVacio(data['url_foto_perfil'])) {
      add('foto', 'Subí una foto de perfil', 'Los clientes confían más con cara visible');
    }
    if (!docOk) {
      add('ocr', 'Validá tu DNI con la cámara', 'Salto grande a Bronce Plus');
    }
    if (!_noVacio(data['telefono'])) {
      add('tel', 'Agregá tu celular', 'Necesario para que te contacten');
    }
    if (!tieneZona) {
      add('domicilio', 'Cargá tu zona de trabajo', 'Aparecés en búsquedas de tu barrio');
    }
    if (!tieneOficios) {
      add('oficios', 'Elegí tus oficios', 'Sin oficio no te encuentran en el buscador');
    }
    if (fotosPortfolio < 1) {
      add('fotos_trabajo', 'Subí fotos de trabajos hechos', 'Portfolio visible en tu tarjeta digital');
    }
    if (nCap < 1) {
      add('capacitaciones', 'Sumá un curso o capacitación', 'Suma solidez profesional (opcional)');
    }
    if (!_noVacio(data['email'])) {
      add('email', 'Confirmá tu email', 'Recuperación de cuenta y avisos');
    }
    return tips;
  }'''
    if old_tips not in t:
        raise SystemExit('tips not found')
    t = t.replace(old_tips, new_tips, 1)
    p.write_text(t)
    print('scoring_service patched', t.count('{') == t.count('}'))

def patch_cf():
    p = Path('functions/scoringCore.js')
    t = p.read_text()
    if 'v1.2-phase1.5-cf' in t:
        print('scoringCore already patched')
        return
    old = '''function badgeSimple(data, scoreId) {
  const geo = data.direccion_geo || {};
  const reg =
    noVacio(data.nombre) &&
    noVacio(data.apellido) &&
    noVacio(data.telefono) &&
    noVacio(data.doc_numero || data.numero_documento) &&
    (geo.localidad_id || geo.localidad_nombre);
  if (reg && data.doc_validado === true && scoreId >= 50) return "bronce_plus";
  if (reg && scoreId >= 35) return "bronce";
  if (reg) return "registrado";
  return "nuevo";
}'''
    new = '''function badgeSimple(data, scoreId) {
  const geo = data.direccion_geo || {};
  const base =
    noVacio(data.nombre) && noVacio(data.apellido) && noVacio(data.telefono);
  const reg =
    base &&
    noVacio(data.doc_numero || data.numero_documento) &&
    (geo.localidad_id || geo.localidad_nombre);
  if (base && data.doc_validado === true) return "bronce_plus";
  if (reg && scoreId >= 35) return "bronce";
  if (base) return "registrado";
  return "nuevo";
}'''
    if old not in t:
        raise SystemExit('cf badge not found')
    t = t.replace(old, new, 1).replace('v1.2-phase1-cf', 'v1.2-phase1.5-cf', 1)
    p.write_text(t)
    print('scoringCore patched')

if __name__ == '__main__':
    patch_scoring_service()
    patch_cf()
