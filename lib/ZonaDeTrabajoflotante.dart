import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_session.dart';

class ZonaDeTrabajoFlotanteWidget extends StatefulWidget {
  const ZonaDeTrabajoFlotanteWidget({super.key});

  @override
  State<ZonaDeTrabajoFlotanteWidget> createState() =>
      _ZonaDeTrabajoFlotanteWidgetState();
}

class _ZonaDeTrabajoFlotanteWidgetState
    extends State<ZonaDeTrabajoFlotanteWidget> {
  // Look & feel prestador
  static const Color primaryColor = Color(0xFF28B5CD);
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _textColor = Color(0xFF1E293B);

  final db = FirebaseFirestore.instance;

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
      _todasLasProvincias =
          List<Map<String, dynamic>>.from(doc.data()!['provincias']);
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

  void _mostrarSeleccionUnica({
    required String titulo,
    required List<Map<String, String>> opciones,
    required void Function(Map<String, String>) onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            titulo,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: opciones.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    opciones[index]['nombre']!,
                    style: const TextStyle(color: _textColor),
                  ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
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
                          final isChecked =
                              temp.any((e) => e['id'] == item['id']);
                          return CheckboxListTile(
                            title: Text(
                              item['nombre']!,
                              style: const TextStyle(color: _textColor),
                            ),
                            value: isChecked,
                            activeColor: primaryColor,
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  temp.add(item);
                                } else {
                                  temp.removeWhere(
                                    (e) => e['id'] == item['id'],
                                  );
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
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    onConfirm(temp);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
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
                          'Definí dónde ofrecés tus servicios. Los clientes te encuentran por estas zonas.',
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
                  valor: _provinciaNombre ?? 'Seleccionar provincia',
                  onTap: () {
                    final opciones = _todasLasProvincias
                        .map(
                          (p) => {
                            'id': p['id'].toString(),
                            'nombre': p['nombre'].toString(),
                          },
                        )
                        .toList();
                    _mostrarSeleccionUnica(
                      titulo: 'Seleccionar provincia',
                      opciones: opciones,
                      onConfirm: _seleccionarProvincia,
                    );
                  },
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
                      ? 'Seleccionar (múltiples)'
                      : _partidosSeleccionados
                          .map((e) => e['nombre'])
                          .join(', '),
                  onTap: _provinciaId == null || _cargandoZonas
                      ? null
                      : () {
                          final opciones = _partidosDeProvincia
                              .map(
                                (p) => {
                                  'id': (p['departamento_id'] ?? p['id'])
                                      .toString(),
                                  'nombre': (p['departamento_nombre'] ??
                                          p['nombre'])
                                      .toString(),
                                },
                              )
                              .toList();
                          _mostrarSeleccionMultiple(
                            titulo: 'Seleccionar partidos',
                            opciones: opciones,
                            seleccionadas: _partidosSeleccionados,
                            onConfirm: _actualizarPartidos,
                          );
                        },
                ),
                _buildSelectorWidget(
                  label: 'Localidades',
                  valor: _localidadesSeleccionadas.isEmpty
                      ? 'Seleccionar localidades (múltiples)'
                      : _localidadesSeleccionadas
                          .map((e) => e['nombre'])
                          .join(', '),
                  onTap: _partidosSeleccionados.isEmpty || _cargandoZonas
                      ? null
                      : () {
                          final idsPartidos =
                              _partidosSeleccionados.map((p) => p['id']).toSet();
                          final filtradas = _localidadesDeProvincia.where(
                            (l) => idsPartidos
                                .contains(l['partido_id']?.toString()),
                          );
                          final opciones = filtradas
                              .map(
                                (l) => {
                                  'id': (l['localidad_id'] ?? l['id'])
                                      .toString(),
                                  'nombre': (l['localidad_nombre'] ??
                                          l['nombre'])
                                      .toString(),
                                },
                              )
                              .toList();
                          _mostrarSeleccionMultiple(
                            titulo: 'Seleccionar localidades',
                            opciones: opciones,
                            seleccionadas: _localidadesSeleccionadas,
                            onConfirm: (res) {
                              setState(() => _localidadesSeleccionadas = res);
                            },
                          );
                        },
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
                Icons.arrow_drop_down,
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
