import 'package:cloud_firestore/cloud_firestore.dart';

import 'geo/catalogo_cl_head.dart';
import 'geo/catalogo_cl_n3.dart';
import 'geo/catalogo_pack.dart';
import 'geo/catalogo_uy_head.dart';
import 'geo/catalogo_uy_n3.dart';

/// Cache geo por país. AR sigue en Firestore (cat_paises/AR).
/// CL/UY: listados oficiales embebidos (CUT / localidades 2011).
class CatalogoGeoCache {
  CatalogoGeoCache._();
  static final CatalogoGeoCache instance = CatalogoGeoCache._();

  final _db = FirebaseFirestore.instance;

  List<Map<String, dynamic>>? _provinciasAR;
  final Map<String, List<Map<String, dynamic>>> _partidosPorProv = {};
  final Map<String, List<Map<String, dynamic>>> _localidadesPorPartido = {};
  final Map<String, List<Map<String, dynamic>>> _n2 = {};
  final Map<String, List<Map<String, dynamic>>> _n3 = {};
  final Map<String, List<Map<String, dynamic>>> _n3por1 = {};

  Map<String, List<Map<String, String>>>? _bundleOf(String iso) {
    if (iso == 'CL') {
      return {
        'nivel1': kClNivel1,
        'nivel2': kClNivel2,
        'nivel3': CatalogoPack.parse(kClNivel3Raw),
      };
    }
    if (iso == 'UY') {
      return {
        'nivel1': kUyNivel1,
        'nivel2': kUyNivel2,
        'nivel3': CatalogoPack.parse(kUyNivel3Raw),
      };
    }
    return null;
  }

  List<Map<String, dynamic>> _asMaps(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> nivel1(String iso) async {
    final s = iso.trim().toUpperCase();
    if (s.isEmpty || s == 'AR') return provinciasAR();
    return _asMaps(_bundleOf(s)?['nivel1']);
  }

  Future<List<Map<String, dynamic>>> nivel2(String iso, String nivel1Id) async {
    final s = iso.trim().toUpperCase();
    if (s.isEmpty || s == 'AR') return partidosDeProvincia(nivel1Id);
    final key = '$s|$nivel1Id';
    if (_n2.containsKey(key)) return _n2[key]!;
    final list = _asMaps(_bundleOf(s)?['nivel2'])
        .where((e) => (e['padre'] ?? '').toString() == nivel1Id)
        .map((e) => {
              'id': e['id'],
              'nombre': e['nombre'],
              'departamento_id': e['id'],
              'departamento_nombre': e['nombre'],
              'provincia_id': nivel1Id,
            })
        .toList();
    _n2[key] = list;
    return list;
  }

  Future<List<Map<String, dynamic>>> nivel3(String iso, String nivel2Id) async {
    final s = iso.trim().toUpperCase();
    if (s.isEmpty || s == 'AR') return localidadesDePartido(nivel2Id);
    final key = '$s|$nivel2Id';
    if (_n3.containsKey(key)) return _n3[key]!;
    final list = _asMaps(_bundleOf(s)?['nivel3'])
        .where((e) => (e['padre'] ?? '').toString() == nivel2Id)
        .map((e) => {
              'id': e['id'],
              'nombre': e['nombre'],
              'localidad_id': e['id'],
              'localidad_nombre': e['nombre'],
              'partido_id': nivel2Id,
              'provincia_id': e['nivel1'],
            })
        .toList();
    _n3[key] = list;
    return list;
  }

  Future<List<Map<String, dynamic>>> localidadesDeNivel1(
    String iso,
    String nivel1Id,
  ) async {
    final s = iso.trim().toUpperCase();
    if (s.isEmpty || s == 'AR') {
      final q = await _db
          .collection('cat_localidades')
          .where('provincia_id', isEqualTo: nivel1Id)
          .get();
      return q.docs.map((d) => d.data()).toList();
    }
    final key = '$s|p|$nivel1Id';
    if (_n3por1.containsKey(key)) return _n3por1[key]!;
    final list = _asMaps(_bundleOf(s)?['nivel3'])
        .where((e) => (e['nivel1'] ?? '').toString() == nivel1Id)
        .map((e) => {
              'id': e['id'],
              'nombre': e['nombre'],
              'localidad_id': e['id'],
              'localidad_nombre': e['nombre'],
              'partido_id': e['padre'],
              'provincia_id': nivel1Id,
            })
        .toList();
    _n3por1[key] = list;
    return list;
  }

  Future<List<Map<String, dynamic>>> provinciasAR() async {
    if (_provinciasAR != null) return _provinciasAR!;
    final doc = await _db.collection('cat_paises').doc('AR').get();
    if (doc.exists && doc.data()!.containsKey('provincias')) {
      _provinciasAR =
          List<Map<String, dynamic>>.from(doc.data()!['provincias']);
    } else {
      _provinciasAR = [];
    }
    return _provinciasAR!;
  }

  Future<List<Map<String, dynamic>>> partidosDeProvincia(String provId) async {
    if (_partidosPorProv.containsKey(provId)) {
      return _partidosPorProv[provId]!;
    }
    final query = await _db
        .collection('cat_departamentos')
        .where('provincia_id', isEqualTo: provId)
        .get();
    final list = query.docs.map((d) => d.data()).toList();
    _partidosPorProv[provId] = list;
    return list;
  }

  Future<List<Map<String, dynamic>>> localidadesDePartido(String partId) async {
    if (_localidadesPorPartido.containsKey(partId)) {
      return _localidadesPorPartido[partId]!;
    }
    final query = await _db
        .collection('cat_localidades')
        .where('partido_id', isEqualTo: partId)
        .get();
    final list = query.docs.map((d) => d.data()).toList();
    _localidadesPorPartido[partId] = list;
    return list;
  }

  void clear() {
    _provinciasAR = null;
    _partidosPorProv.clear();
    _localidadesPorPartido.clear();
    _n2.clear();
    _n3.clear();
    _n3por1.clear();
  }
}
