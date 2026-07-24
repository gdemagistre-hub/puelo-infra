import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_session.dart';

class ZonaDeTrabajoFlotanteWidget extends StatefulWidget {
  const ZonaDeTrabajoFlotanteWidget({super.key});

  @override
  State<ZonaDeTrabajoFlotanteWidget> createState() => _ZonaDeTrabajoFlotanteWidgetState();
}

class _ZonaDeTrabajoFlotanteWidgetState extends State<ZonaDeTrabajoFlotanteWidget> {
  final primaryColor = const Color(0xFF0F52BA);
  final textColor = const Color(0xFF1E293B);
  final inputBgColor = const Color(0xFFF8FAFC);
  final db = FirebaseFirestore.instance;

  // País fijo (mismo criterio que registroTrabajador)
  final String _paisId = 'AR';
  final String _paisNombre = 'Argentina';

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
    final doc = await db.collection('cat_paises').doc('AR').get();
    if (doc.exists && doc.data()!.containsKey('provincias')) {
      _todasLasProvincias = List<Map<String, dynamic>>.from(doc.data()!['provincias']);
    }
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

    // Partidos (formato de registroTrabajador)
    final partidosRaw = cobertura['partidos'] as List<dynamic>? ?? [];
    _partidosSeleccionados = partidosRaw
        .whereType<Map>()
        .map((p) => {
              'id': (p['id'] ?? '').toString(),
              'nombre': (p['nombre'] ?? '').toString(),
            })
        .where((p) => p['id']!.isNotEmpty)
        .toList();

    // Localidades
    final locsRaw = cobertura['localidades'] as List<dynamic>? ?? [];
    _localidadesSeleccionadas = locsRaw
        .whereType<Map>()
        .map((l) => {
              'id': (l['id'] ?? '').toString(),
              'nombre': (l['nombre'] ?? '').toString(),
            })
        .where((l) => l['id']!.isNotEmpty)
        .toList();

    // Si había provincia, precargamos partidos y localidades de esa provincia
    if (_provinciaId != null) {
      await _cargarZonasDeProvincia(_provinciaId!, limpiarSeleccion: false);
    }
  }

  Future<void> _cargarZonasDeProvincia(String provId, {bool limpiarSeleccion = true}) async {
    setState(() => _cargandoZonas = true);

    try {
      final depQuery = await db
          .collection('cat_departamentos')
          .where('provincia_id', isEqualTo: provId)
          .get();

      final locQuery = await db
          .collection('cat_localidades')
          .where('provincia_id', isEqualTo: provId)
          .get();

      setState(() {
        _partidosDeProvincia = depQuery.docs.map((d) => d.data()).toList();
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

      // Sacamos localidades que ya no pertenecen a los partidos elegidos
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

  // ─── Diálogos (mismo patrón que registroTrabajador) ───────────────────────

  void _mostrarSeleccionUnica({
    required String titulo,
    required List<Map<String, String>> opciones,
    required void Function(Map<String, String>) onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: opciones.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(opciones[index]['nombre']!, style: TextStyle(color: textColor)),
                  onTap: () {
                    onConfirm(opciones[index]);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _mostrarSeleccionMultiple({
    required String titulo,
    required List<Map<String, String>> opciones,
    required List<Map<String, String>> seleccionadas,
    required void Function(List<Map<String, String>>) onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        List<Map<String, String>> temp = List.from(seleccionadas);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              content: SizedBox(
                width: double.maxFinite,
                child: opciones.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Primero debés seleccionar el filtro anterior.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: opciones.length,
                        itemBuilder: (context, index) {
                          final item = opciones[index];
                          final isChecked = temp.any((e) => e['id'] == item['id']);
                          return CheckboxListTile(
                            title: Text(item['nombre']!, style: TextStyle(color: textColor)),
                            value: isChecked,
                            activeColor: primaryColor,
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  temp.add(item);
                                } else {
                                  temp.removeWhere((e) => e['id'] == item['id']);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    onConfirm(temp);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                  child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── Guardar ──────────────────────────────────────────────────────────────

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
      await db.collection('usuarios').doc(uid).set({
        'zonas_cobertura': {
          'pais_id': _paisId,
          'pais_nombre': _paisNombre,
          'provincia_id': _provinciaId,
          'provincia_nombre': _provinciaNombre,
          'partidos': _partidosSeleccionados,
          'localidades': _localidadesSeleccionadas,
        },
        'es_trabajador': true,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Zona de trabajo preferida',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Zonas de Cobertura (Filtro Geográfico)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                const Divider(),
                const SizedBox(height: 12),

                // País (fijo)
                _buildSelectorWidget(
                  label: 'País',
                  valor: _paisNombre,
                  onTap: null, // solo Argentina por ahora
                ),

                // Provincia
                _buildSelectorWidget(
                  label: 'Provincia',
                  valor: _provinciaNombre ?? 'Seleccionar Provincia',
                  onTap: () {
                    final opciones = _todasLasProvincias
                        .map((p) => {
                              'id': p['id'].toString(),
                              'nombre': p['nombre'].toString(),
                            })
                        .toList();
                    _mostrarSeleccionUnica(
                      titulo: 'Seleccionar Provincia',
                      opciones: opciones,
                      onConfirm: _seleccionarProvincia,
                    );
                  },
                ),

                if (_cargandoZonas)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  ),

                // Partidos / Departamentos (múltiple)
                _buildSelectorWidget(
                  label: 'Partidos / Departamentos',
                  valor: _partidosSeleccionados.isEmpty
                      ? 'Seleccionar (Múltiple)'
                      : _partidosSeleccionados.map((e) => e['nombre']).join(', '),
                  onTap: _provinciaId == null || _cargandoZonas
                      ? null
                      : () {
                          final opciones = _partidosDeProvincia
                              .map((p) => {
                                    'id': (p['departamento_id'] ?? p['id']).toString(),
                                    'nombre':
                                        (p['departamento_nombre'] ?? p['nombre']).toString(),
                                  })
                              .toList();
                          _mostrarSeleccionMultiple(
                            titulo: 'Seleccionar Partidos',
                            opciones: opciones,
                            seleccionadas: _partidosSeleccionados,
                            onConfirm: _actualizarPartidos,
                          );
                        },
                ),

                // Localidades (múltiple, filtradas por partidos)
                _buildSelectorWidget(
                  label: 'Localidades',
                  valor: _localidadesSeleccionadas.isEmpty
                      ? 'Seleccionar Localidades (Múltiple)'
                      : _localidadesSeleccionadas.map((e) => e['nombre']).join(', '),
                  onTap: _partidosSeleccionados.isEmpty || _cargandoZonas
                      ? null
                      : () {
                          final idsPartidos =
                              _partidosSeleccionados.map((p) => p['id']).toSet();
                          final filtradas = _localidadesDeProvincia.where(
                            (l) => idsPartidos.contains(l['partido_id']?.toString()),
                          );
                          final opciones = filtradas
                              .map((l) => {
                                    'id': (l['localidad_id'] ?? l['id']).toString(),
                                    'nombre':
                                        (l['localidad_nombre'] ?? l['nombre']).toString(),
                                  })
                              .toList();
                          _mostrarSeleccionMultiple(
                            titulo: 'Seleccionar Localidades',
                            opciones: opciones,
                            seleccionadas: _localidadesSeleccionadas,
                            onConfirm: (res) {
                              setState(() => _localidadesSeleccionadas = res);
                            },
                          );
                        },
                ),

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
                    label: Text(_saving ? 'Guardando...' : 'Actualizar los datos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
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
            color: inputBgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      valor,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: onTap == null ? Colors.grey.shade300 : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
