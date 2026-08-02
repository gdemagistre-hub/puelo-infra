import 'package:flutter/material.dart';

/// Catálogo de servicios: categoría → especialidad + sinónimos.
/// Fuente única para UI de prestador, buscador y labels.
class CatalogoOficios {
  CatalogoOficios._();

  static const String version = '2.0';

  // ---------------------------------------------------------------------------
  // Categorías (chips de búsqueda / agrupación)
  // ---------------------------------------------------------------------------

  static const List<OficioCategoria> categorias = [
    OficioCategoria('plomeria_gas', 'Plomería y gas', Icons.plumbing),
    OficioCategoria('electricidad', 'Electricidad', Icons.electrical_services_outlined),
    OficioCategoria('construccion', 'Construcción', Icons.construction_outlined),
    OficioCategoria('pintura_acabados', 'Pintura y acabados', Icons.format_paint_outlined),
    OficioCategoria('madera_muebles', 'Madera y muebles', Icons.handyman_outlined),
    OficioCategoria('jardin_exterior', 'Jardín y exterior', Icons.yard_outlined),
    OficioCategoria('limpieza', 'Limpieza', Icons.cleaning_services_outlined),
    OficioCategoria('clima', 'Clima y calefacción', Icons.ac_unit_outlined),
    OficioCategoria('seguridad_tech', 'Seguridad y tech', Icons.videocam_outlined),
    OficioCategoria('mudanzas', 'Mudanzas y fletes', Icons.local_shipping_outlined),
    OficioCategoria('mascotas', 'Mascotas', Icons.pets_outlined),
    OficioCategoria('hogar_varios', 'Hogar y varios', Icons.home_repair_service_outlined),
  ];

  // ---------------------------------------------------------------------------
  // Especialidades
  // ---------------------------------------------------------------------------

  static const List<OficioEspecialidad> especialidades = [
    // —— Plomería y gas ——
    OficioEspecialidad('plomeria', 'Plomería', 'plomeria_gas',
        ['plomero', 'caños', 'canos', 'sanitarista', 'griferia']),
    OficioEspecialidad('gasista', 'Gasista', 'plomeria_gas',
        ['gas', 'matriculado gas', 'instalacion gas']),
    OficioEspecialidad('destapaciones', 'Destapaciones', 'plomeria_gas',
        ['desagote', 'cloaca', 'destape', 'taponamiento']),
    OficioEspecialidad('calefones', 'Calefones y termotanques', 'plomeria_gas',
        ['termotanque', 'calefon', 'agua caliente']),
    OficioEspecialidad('bombas_agua', 'Bombas de agua', 'plomeria_gas',
        ['bomba', 'presurizador']),
    OficioEspecialidad('tanques_agua', 'Tanques de agua', 'plomeria_gas',
        ['tanque', 'cisterna']),

    // —— Electricidad ——
    OficioEspecialidad('electricidad', 'Electricista', 'electricidad',
        ['electrico', 'instalacion electrica', 'tablero']),
    OficioEspecialidad('portero_electrico', 'Portero eléctrico', 'electricidad',
        ['videoportero', 'portero']),
    OficioEspecialidad('iluminacion', 'Iluminación', 'electricidad',
        ['luces', 'led', 'lamparas']),

    // —— Construcción ——
    OficioEspecialidad('albanileria', 'Albañilería', 'construccion',
        ['albanil', 'construccion', 'obra', 'revoque']),
    OficioEspecialidad('techista', 'Techista', 'construccion',
        ['techo', 'techos', 'gotera', 'chapa']),
    OficioEspecialidad('impermeabilizacion', 'Impermeabilización', 'construccion',
        ['humedad', 'filtracion', 'membrana']),
    OficioEspecialidad('colocacion_pisos', 'Colocación de pisos', 'construccion',
        ['ceramicos', 'porcelanato', 'piso', 'azulejos']),
    OficioEspecialidad('drywall', 'Durlock / drywall', 'construccion',
        ['durlock', 'yeso', 'cielorraso', 'placas']),
    OficioEspecialidad('aberturas_aluminio', 'Aberturas de aluminio', 'construccion',
        ['ventana', 'aberturas', 'aluminio']),
    OficioEspecialidad('herreria', 'Herrería', 'construccion',
        ['rejas', 'porton', 'hierro', 'soldadura']),
    OficioEspecialidad('vidrieria', 'Vidriería', 'construccion',
        ['vidrio', 'cristal', 'mampara']),
    OficioEspecialidad('piletas_construccion', 'Piletas (construcción)', 'construccion',
        ['piscina obra', 'pileta obra']),

    // —— Pintura ——
    OficioEspecialidad('pintura', 'Pintura', 'pintura_acabados',
        ['pintor', 'pintar', 'latex']),
    OficioEspecialidad('empapelado', 'Empapelado', 'pintura_acabados',
        ['papel mural', 'wallpaper']),
    OficioEspecialidad('revestimientos', 'Revestimientos', 'pintura_acabados',
        ['enducido', 'texturado']),

    // —— Madera ——
    OficioEspecialidad('carpinteria', 'Carpintería', 'madera_muebles',
        ['carpintero', 'madera']),
    OficioEspecialidad('muebles_medida', 'Muebles a medida', 'madera_muebles',
        ['amoblamiento', 'placard', 'cocina a medida']),
    OficioEspecialidad('tapiceria', 'Tapicería', 'madera_muebles',
        ['sillones', 'tapizado']),
    OficioEspecialidad('decks', 'Decks y pergolas', 'madera_muebles',
        ['deck', 'pergola', 'quincho madera']),

    // —— Jardín ——
    OficioEspecialidad('jardineria', 'Jardinería', 'jardin_exterior',
        ['jardinero', 'jardin', 'cesped']),
    OficioEspecialidad('poda', 'Poda de árboles', 'jardin_exterior',
        ['podar', 'arboles', 'ramas']),
    OficioEspecialidad('paisajismo', 'Paisajismo', 'jardin_exterior',
        ['paisajista', 'diseño jardin']),
    OficioEspecialidad('riego', 'Riego automático', 'jardin_exterior',
        ['riego', 'aspersores']),
    OficioEspecialidad('cercos', 'Cercos y alambrados', 'jardin_exterior',
        ['alambrado', 'cerco', 'perimetral']),
    OficioEspecialidad('piletas_mantenimiento', 'Piletas (mantenimiento)', 'jardin_exterior',
        ['pileta', 'piscina', 'cloro', 'mantenimiento pileta']),

    // —— Limpieza ——
    OficioEspecialidad('limpieza', 'Limpieza', 'limpieza',
        ['limpiar', 'empleada', 'limpieza hogar']),
    OficioEspecialidad('limpieza_postobra', 'Limpieza post-obra', 'limpieza',
        ['post obra', 'final de obra']),
    OficioEspecialidad('limpieza_alfombras', 'Alfombras y tapizados', 'limpieza',
        ['alfombra', 'sillones lavado', 'tapizados']),
    OficioEspecialidad('fumigacion', 'Fumigación / plagas', 'limpieza',
        ['plagas', 'desinsectacion', 'desratizacion', 'cucarachas']),
    OficioEspecialidad('vidrios', 'Limpieza de vidrios', 'limpieza',
        ['vidrios', 'cristales']),

    // —— Clima ——
    OficioEspecialidad('aire_acondicionado', 'Aire acondicionado', 'clima',
        ['aire', 'aa', 'split', 'climatizacion']),
    OficioEspecialidad('calefaccion', 'Calefacción', 'clima',
        ['caldera', 'radiador', 'estufa', 'calefaccion']),
    OficioEspecialidad('ventilacion', 'Ventilación', 'clima',
        ['extractor', 'campana']),

    // —— Seguridad y tech ——
    OficioEspecialidad('cctv', 'Cámaras / CCTV', 'seguridad_tech',
        ['camaras', 'seguridad', 'videovigilancia']),
    OficioEspecialidad('alarmas', 'Alarmas', 'seguridad_tech',
        ['alarma', 'monitoreo']),
    OficioEspecialidad('cerrajeria', 'Cerrajería', 'seguridad_tech',
        ['cerrajero', 'cerradura', 'llaves', 'apertura']),
    OficioEspecialidad('redes_wifi', 'Redes / Wi‑Fi', 'seguridad_tech',
        ['wifi', 'red', 'router', 'cableado']),
    OficioEspecialidad('soporte_pc', 'Soporte PC', 'seguridad_tech',
        ['computadora', 'notebook', 'tecnico pc', 'formateo']),
    OficioEspecialidad('domotica', 'Domótica básica', 'seguridad_tech',
        ['automatizacion', 'smart home']),

    // —— Mudanzas ——
    OficioEspecialidad('mudanzas', 'Mudanzas', 'mudanzas',
        ['mudanza', 'mudar']),
    OficioEspecialidad('fletes', 'Fletes', 'mudanzas',
        ['flete', 'transporte', 'envio']),
    OficioEspecialidad('retiro_escombros', 'Retiro de escombros', 'mudanzas',
        ['escombros', 'escombro', 'descartes']),

    // —— Mascotas ——
    OficioEspecialidad('paseador_perros', 'Paseador de perros', 'mascotas',
        ['paseador', 'perro', 'mascota']),
    OficioEspecialidad('peluqueria_canina', 'Peluquería canina', 'mascotas',
        ['grooming', 'baño perro']),
    OficioEspecialidad('pet_sitting', 'Cuidado de mascotas', 'mascotas',
        ['petsitter', 'cuidado perros', 'guarderia']),

    // —— Hogar varios ——
    OficioEspecialidad('persianas', 'Persianas y cortinas', 'hogar_varios',
        ['persiana', 'cortina', 'roller']),
    OficioEspecialidad('toldos', 'Toldos', 'hogar_varios',
        ['toldo', 'lonas']),
    OficioEspecialidad('portones_automaticos', 'Portones automáticos', 'hogar_varios',
        ['porton', 'motor porton', 'automatizacion porton']),
    OficioEspecialidad('electrodomesticos', 'Service electrodomésticos', 'hogar_varios',
        ['heladera', 'lavarropas', 'cocina', 'horno']),
    OficioEspecialidad('costura', 'Costura y arreglos', 'hogar_varios',
        ['modista', 'arreglo ropa', 'costurera']),
    OficioEspecialidad('organizacion_hogar', 'Organización del hogar', 'hogar_varios',
        ['organizer', 'orden']),
  ];

  static final Map<String, OficioEspecialidad> _byId = {
    for (final e in especialidades) e.id: e,
  };

  static final Map<String, OficioCategoria> _catById = {
    for (final c in categorias) c.id: c,
  };

  static OficioEspecialidad? especialidad(String id) =>
      _byId[id.toLowerCase().trim()];

  static OficioCategoria? categoria(String id) =>
      _catById[id.toLowerCase().trim()];

  static String label(String id) {
    final k = id.toLowerCase().trim();
    return _byId[k]?.label ??
        _catById[k]?.label ??
        (k.isEmpty ? id : _titleCase(k.replaceAll('_', ' ')));
  }

  static IconData iconFor(String id) {
    final k = id.toLowerCase().trim();
    final esp = _byId[k];
    if (esp != null) {
      return _catById[esp.categoriaId]?.icon ?? Icons.handyman_outlined;
    }
    return _catById[k]?.icon ?? Icons.handyman_outlined;
  }

  static String? categoriaDeEspecialidad(String especialidadId) =>
      _byId[especialidadId.toLowerCase().trim()]?.categoriaId;

  /// Especialidades de una categoría.
  static List<OficioEspecialidad> especialidadesDe(String categoriaId) {
    final c = categoriaId.toLowerCase().trim();
    return especialidades.where((e) => e.categoriaId == c).toList();
  }

  /// Categorías derivadas de las especialidades elegidas (sin duplicar).
  static List<String> categoriasDesdeProfesiones(Iterable<String> profesiones) {
    final out = <String>{};
    for (final p in profesiones) {
      final cat = categoriaDeEspecialidad(p);
      if (cat != null) out.add(cat);
      // si ya es categoría id
      if (_catById.containsKey(p.toLowerCase().trim())) {
        out.add(p.toLowerCase().trim());
      }
    }
    return out.toList();
  }

  /// ¿Coincide con categoría (chip), especialidad o sinónimo?
  static bool coincide({
    required Iterable<String> profesiones,
    String? categoriaId,
    String? texto,
  }) {
    final prof = profesiones
        .map((e) => e.toString().toLowerCase().trim())
        .where((s) => s.isNotEmpty)
        .toSet();

    if (categoriaId != null &&
        categoriaId.isNotEmpty &&
        categoriaId != 'Todos') {
      final cat = categoriaId.toLowerCase().trim();
      // match category id or any specialty in that category
      bool okCat = prof.contains(cat);
      if (!okCat) {
        for (final p in prof) {
          final esp = _byId[p];
          if (esp != null && esp.categoriaId == cat) {
            okCat = true;
            break;
          }
          // legacy: albanileria under construccion, etc. handled by data
        }
      }
      if (!okCat) return false;
    }

    final q = (texto ?? '').toLowerCase().trim();
    if (q.isEmpty) return true;

    if (prof.any((p) => p.contains(q) || q.contains(p))) return true;
    for (final p in prof) {
      final esp = _byId[p];
      if (esp == null) {
        if (label(p).toLowerCase().contains(q)) return true;
        continue;
      }
      if (esp.label.toLowerCase().contains(q)) return true;
      if (esp.id.contains(q)) return true;
      if (esp.sinonimos.any((s) => s.contains(q) || q.contains(s))) {
        return true;
      }
      final cat = _catById[esp.categoriaId];
      if (cat != null && cat.label.toLowerCase().contains(q)) return true;
    }
    // texto es nombre de categoría
    for (final c in categorias) {
      if (c.label.toLowerCase().contains(q) || c.id == q) {
        for (final p in prof) {
          if (_byId[p]?.categoriaId == c.id) return true;
        }
      }
    }
    return false;
  }

  /// Chips de buscador: Todos + categorías.
  static List<String> chipsBuscador() =>
      ['Todos', ...categorias.map((c) => c.label)];

  static String? categoriaIdDesdeChip(String chipLabel) {
    if (chipLabel == 'Todos') return null;
    for (final c in categorias) {
      if (c.label == chipLabel || c.id == chipLabel.toLowerCase()) {
        return c.id;
      }
    }
    // legacy chip names
    const legacy = {
      'Electricista': 'electricidad',
      'Plomero': 'plomeria_gas',
      'Gasista': 'plomeria_gas',
      'Carpintero': 'madera_muebles',
      'Pintor': 'pintura_acabados',
      'Construcción': 'construccion',
      'Jardinería': 'jardin_exterior',
      'Limpieza': 'limpieza',
    };
    return legacy[chipLabel];
  }

  /// Lista plana de ids (compat maestro / Firestore).
  static List<String> maestroIds() =>
      especialidades.map((e) => e.id).toList();

  /// Payload para seed Firestore cat_oficios.
  static Map<String, dynamic> toFirestoreSeed() {
    return {
      'version': version,
      'actualizado_en_modelo': version,
      'maestro': maestroIds(),
      'categorias': categorias
          .map((c) => {
                'id': c.id,
                'label': c.label,
              })
          .toList(),
      'especialidades': especialidades
          .map((e) => {
                'id': e.id,
                'label': e.label,
                'categoria_id': e.categoriaId,
                'sinonimos': e.sinonimos,
              })
          .toList(),
    };
  }

  static String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}

class OficioCategoria {
  final String id;
  final String label;
  final IconData icon;
  const OficioCategoria(this.id, this.label, this.icon);
}

class OficioEspecialidad {
  final String id;
  final String label;
  final String categoriaId;
  final List<String> sinonimos;
  const OficioEspecialidad(
    this.id,
    this.label,
    this.categoriaId, [
    this.sinonimos = const [],
  ]);
}
