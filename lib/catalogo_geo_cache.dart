import 'package:cloud_firestore/cloud_firestore.dart';

/// Cache en memoria de catálogos geográficos para evitar releer Firestore
/// en cada pantalla (buscador, domicilio, zona) durante la sesión.
class CatalogoGeoCache {
  CatalogoGeoCache._();
  static final CatalogoGeoCache instance = CatalogoGeoCache._();

  final _db = FirebaseFirestore.instance;

  List<Map<String, dynamic>>? _provinciasAR;
  final Map<String, List<Map<String, dynamic>>> _partidosPorProv = {};
  final Map<String, List<Map<String, dynamic>>> _localidadesPorPartido = {};

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

  /// Llamar en logout si se quiere forzar datos frescos en la próxima sesión.
  void clear() {
    _provinciasAR = null;
    _partidosPorProv.clear();
    _localidadesPorPartido.clear();
  }
}
