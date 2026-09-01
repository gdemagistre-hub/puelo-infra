import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_session.dart';
import 'prestador_list_fields.dart';
import 'widgets/searchable_picker.dart';
import 'catalogo_geo_cache.dart';
import 'geo/country_profile.dart';

class ZonaDeTrabajoFlotanteWidget extends StatefulWidget {
  const ZonaDeTrabajoFlotanteWidget({super.key});

  @override
  State<ZonaDeTrabajoFlotanteWidget> createState() =>
      _ZonaDeTrabajoFlotanteWidgetState();
}

class _ZonaDeTrabajoFlotanteWidgetState
    extends State<ZonaDeTrabajoFlotanteWidget> {
  static const Color primaryColor = Color(0xFF28B5CD);
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _textColor = Color(0xFF1E293B);

  final db = FirebaseFirestore.instance;

  CountryProfile get _pais => CountryProfile.of(UserSession().countryCode);
  String get _paisId => _pais.iso;
  String get _paisNombre => _pais.name;

  String? _provinciaId;
  String? _provinciaNombre;

  List<Map<String, String>> _partidosSeleccionados = [];
  List<Map<String, String>> _localidadesSeleccionadas = [];

  List<Map<String, dynamic>> _todasLasProvincias = [];
  List<Map<String, dynamic>> _partidosDeProvincia = [];
  List<Map<String, dynamic>> _localidadesDeProvincia = [];

  bool _loading = true;
  bool _cargandoZonas = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    try {
      await _cargarProvincias();
      await _cargarDatosUsuario();
    } catch (e) {
      debugPrint('Error cargando zona de trabajo: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _cargarProvincias() async {
    if (!_pais.geoReady) return;
    _todasLasProvincias = await CatalogoGeoCache.instance.provinciasAR();
  }

  void _avisoGeoNoListo() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'El catálogo de zonas todavía no está activo en ${_pais.name}.',
        ),
      ),
    );
  }

  Future<void> _cargarDatosUsuario() async {
    final uid = UserSession().uid;
    if (uid == null) return;

    final doc = await db.collection('usuarios').doc(uid).get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final cobertura = data['zonas_cobertura'] as Map<String, dynamic>?;
    if (cobertura == null) return;

    _provinciaId = cobertura['provincia_id']?.toString();
    _provinciaNombre = cobertura['provincia_nombre']?.toString();

    final partidosRaw = cobertura['partidos'] as List<dynamic>? ?? [];
    _partidosSeleccionados = partidosRaw
        .whereType<Map>()
        .map(
          (p) => {
            'id': (p['id'] ?? '').toString(),
            'nombre': (p['nombre'] ?? '').toString(),
          },
        )
        .where((p) => p['id']!.isNotEmpty)
        .toList();

    final locsRaw = cobertura['localidades'] as List<dynamic>? ?? [];
    _localidadesSeleccionadas = locsRaw
        .whereType<Map>()
        .map(
          (l) => {
            'id': (l['id'] ?? '').toString(),
            'nombre': (l['nombre'] ?? '').toString(),
          },
        )
        .where((l) => l['id']!.isNotEmpty)
        .toList();

    if (_provinciaId != null) {
      await _cargarZonasDeProvincia(_provinciaId!, limpiarSeleccion: false);
    }
  }

  Future<void> _cargarZonasDeProvincia(
    String provId, {
    bool limpiarSeleccion = true,
  }) async {
    setState(() => _cargandoZonas = true);

    try {
      final partidos =
          await CatalogoGeoCache.instance.partidosDeProvincia(provId);

      // Localidades por provincia: se obtienen de todos los partidos en cache
      // o una query directa por provincia_id si existe ese campo.
      final locQuery = await db
          .collection('cat_localidades')
          .where('provincia_id', isEqualTo: provId)
          .get();

      setState(() {
        _partidosDeProvincia = partidos;
        _localidadesDeProvincia = locQuery.docs.map((d) => d.data()).toList();

        if (limpiarSeleccion) {
          _partidosSeleccionados.clear();
          _localidadesSeleccionadas.clear();
        }
        _cargandoZonas = false;
      });
    } catch (e) {
      debugPrint('Error cargando zonas: $e');
      if (mounted) setState(() => _cargandoZonas = false);
    }
  }

  Future<void> _seleccionarProvincia(Map<String, String> prov) async {
    setState(() {
      _provinciaId = prov['id'];
      _provinciaNombre = prov['nombre'];
      _partidosSeleccionados.clear();
      _localidadesSeleccionadas.clear();
      _partidosDeProvincia.clear();
      _localidadesDeProvincia.clear();
    });
    await _cargarZonasDeProvincia(prov['id']!, limpiarSeleccion: true);
  }

  void _actualizarPartidos(List<Map<String, String>> nuevosPartidos) {
    setState(() {
      _partidosSeleccionados = nuevosPartidos;

      final idsPartidos = nuevosPartidos.map((p) => p['id']).toSet();

      _localidadesSeleccionadas.removeWhere((loc) {
        final original = _localidadesDeProvincia.firstWhere(
          (l) => (l['localidad_id'] ?? l['id'])?.toString() == loc['id'],
          orElse: () => <String, dynamic>{},
        );
        if (original.isEmpty) return true;
        return !idsPartidos.contains(original['partido_id']?.toString());
      });
    });
  }

  Future<void> _abrirProvincia() async {
    if (!_pais.geoReady) {
      _avisoGeoNoListo();
      return;
    }
    final opciones = _todasLasProvincias
        .map(
          (p) => {
            'id': p['id'].toString(),
            'nombre': p['nombre'].toString(),
          },
        )
        .toList()
      ..sort((a, b) => a['nombre']!.compareTo(b['nombre']!));

    final elegido = await SearchablePicker.pickSingle(
      context: context,
      titulo: 'Seleccionar provincia',
      opciones: opciones,
      selectedId: _provinciaId,
      accent: primaryColor,
      hintBuscar: 'Ej: Buenos Aires, Córdoba…',
    );
    if (elegido != null) await _seleccionarProvincia(elegido);
  }

  Future<void> _abrirPartidos() async {
    if (!_pais.geoReady) {
      _avisoGeoNoListo();
      return;
    }
    final opciones = _partidosDeProvincia
        .map(
          (p) => {
            'id': (p['departamento_id'] ?? p['id']).toString(),
            'nombre': (p['departamento_nombre'] ?? p['nombre']).toString(),
          },
        )
        .toList()
      ..sort((a, b) => a['nombre']!.compareTo(b['nombre']!));

    final res = await SearchablePicker.pickMulti(
      context: context,
      titulo: 'Seleccionar partidos',
      opciones: opciones,
      seleccionadas: _partidosSeleccionados,
      accent: primaryColor,
      hintBuscar: 'Escribí el nombre del partido…',
    );
    if (res != null) _actualizarPartidos(res);
  }

  Future<void> _abrirLocalidades() async {
    if (!_pais.geoReady) {
      _avisoGeoNoListo();
      return;
    }
    final idsPartidos = _partidosSeleccionados.map((p) => p['id']).toSet();
    final filtradas = _localidadesDeProvincia.where(
      (l) => idsPartidos.contains(l['partido_id']?.toString()),
    );
    final opciones = filtradas
        .map(
          (l) => {
            'id': (l['localidad_id'] ?? l['id']).toString(),
            'nombre': (l['localidad_nombre'] ?? l['nombre']).toString(),
          },
        )
        .toList()
      ..sort((a, b) => a['nombre']!.compareTo(b['nombre']!));

    final res = await SearchablePicker.pickMulti(
      context: context,
      titulo: 'Seleccionar localidades',
      opciones: opciones,
      seleccionadas: _localidadesSeleccionadas,
      accent: primaryColor,
      hintBuscar: 'Escribí el nombre de la localidad…',
    );
    if (res != null) setState(() => _localidadesSeleccionadas = res);
  }

  Future<void> _actualizarDatos() async {
    final uid = UserSession().uid;
    if (uid == null) return;

    if (_provinciaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná una provincia')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final cobertura = {
        'pais_id': _paisId,
        'pais_nombre': _paisNombre,
        'provincia_id': _provinciaId,
        'provincia_nombre': _provinciaNombre,
        'partidos': _partidosSeleccionados,
        'localidades': _localidadesSeleccionadas,
      };
      final session = UserSession();
      final base = {
        ...(session.datosCompletos ?? {}),
        'zonas_cobertura': cobertura,
        'es_trabajador': true,
      };
      final listFields = PrestadorListFields.build(data: base);
      final listFieldsMem =
          PrestadorListFields.build(data: base, touchTimestamp: false);
      await db.collection('usuarios').doc(uid).set({
        'zonas_cobertura': cobertura,
        'es_trabajador': true,
        'updated_at': FieldValue.serverTimestamp(),
        ...listFields,
      }, SetOptions(merge: true));
      if (session.datosCompletos != null) {
        session.datosCompletos = {
          ...session.datosCompletos!,
          'zonas_cobertura': cobertura,
          'es_trabajador': true,
          ...listFieldsMem,
        };
      }
      session.invalidateHomeCache();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Zona de trabajo actualizada'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: _textColor,
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Zona de trabajo preferida',
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.map_outlined, color: primaryColor, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Definí dónde ofrecés tus servicios. Podés buscar escribiendo el nombre.',
                          style: TextStyle(
                            fontSize: 13,
                            color: _textColor,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Cobertura geográfica',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSelectorWidget(
                  label: 'País',
                  valor: _paisNombre,
                  onTap: null,
                ),
                _buildSelectorWidget(
                  label: 'Provincia',
                  valor: _provinciaNombre ?? 'Buscar o elegir provincia',
                  onTap: _abrirProvincia,
                ),
                if (_cargandoZonas)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    ),
                  ),
                _buildSelectorWidget(
                  label: 'Partidos / Departamentos',
                  valor: _partidosSeleccionados.isEmpty
                      ? 'Buscar o elegir (múltiples)'
                      : _partidosSeleccionados
                          .map((e) => e['nombre'])
                          .join(', '),
                  onTap: _provinciaId == null || _cargandoZonas
                      ? null
                      : _abrirPartidos,
                ),
                _buildSelectorWidget(
                  label: 'Localidades',
                  valor: _localidadesSeleccionadas.isEmpty
                      ? 'Buscar o elegir localidades'
                      : _localidadesSeleccionadas
                          .map((e) => e['nombre'])
                          .join(', '),
                  onTap: _partidosSeleccionados.isEmpty || _cargandoZonas
                      ? null
                      : _abrirLocalidades,
                ),
                if (_partidosSeleccionados.isNotEmpty ||
                    _localidadesSeleccionadas.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._partidosSeleccionados.map(
                        (p) => Chip(
                          label: Text(p['nombre'] ?? ''),
                          backgroundColor: primaryColor.withOpacity(0.12),
                          side: BorderSide(
                            color: primaryColor.withOpacity(0.25),
                          ),
                          labelStyle: const TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      ..._localidadesSeleccionadas.map(
                        (l) => Chip(
                          label: Text(l['nombre'] ?? ''),
                          backgroundColor: primaryColor.withOpacity(0.08),
                          side: BorderSide(
                            color: primaryColor.withOpacity(0.2),
                          ),
                          labelStyle: TextStyle(
                            color: primaryColor.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _actualizarDatos,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _saving ? 'Guardando...' : 'Actualizar los datos',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _buildSelectorWidget({
    required String label,
    required String valor,
    required VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      valor,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: onTap == null
                            ? Colors.grey.shade500
                            : _textColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.search,
                color: onTap == null
                    ? Colors.grey.shade300
                    : Colors.grey.shade500,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
