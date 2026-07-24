import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_session.dart';

class DomicilioFlotanteWidget extends StatefulWidget {
  const DomicilioFlotanteWidget({super.key});

  @override
  State<DomicilioFlotanteWidget> createState() =>
      _DomicilioFlotanteWidgetState();
}

class _DomicilioFlotanteWidgetState extends State<DomicilioFlotanteWidget> {
  final primaryColor = const Color(0xFF0F52BA);
  final db = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  final _calleController = TextEditingController();
  final _numeroController = TextEditingController();
  final _pisoController = TextEditingController();
  final _cpController = TextEditingController();

  String? selectedProvinciaId;
  String? selectedPartidoId;
  String? selectedLocalidadId;

  List<Map<String, dynamic>> provincias = [];
  List<Map<String, dynamic>> partidos = [];
  List<Map<String, dynamic>> localidades = [];

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _calleController.dispose();
    _numeroController.dispose();
    _pisoController.dispose();
    _cpController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    final uid = UserSession().uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final paisDoc = await db.collection('cat_paises').doc('AR').get();
      if (paisDoc.exists && paisDoc.data()!.containsKey('provincias')) {
        provincias =
            List<Map<String, dynamic>>.from(paisDoc.data()!['provincias']);
      }

      final doc = await db.collection('usuarios').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _calleController.text = (data['calle'] ?? '').toString();
        _numeroController.text = (data['numero'] ?? '').toString();
        _pisoController.text =
            (data['piso_depto'] ?? data['piso'] ?? '').toString();
        _cpController.text =
            (data['cp'] ?? data['codigo_postal'] ?? '').toString();

        final geo = data['direccion_geo'] as Map<String, dynamic>?;
        if (geo != null) {
          selectedProvinciaId = geo['provincia_id']?.toString();
          selectedPartidoId = geo['partido_id']?.toString();
          selectedLocalidadId = geo['localidad_id']?.toString();

          if (selectedProvinciaId != null) {
            await _loadPartidos(selectedProvinciaId!);
          }
          if (selectedPartidoId != null) {
            await _loadLocalidades(selectedPartidoId!);
          }
        }
      }
    } catch (e) {
      debugPrint('Error cargando domicilio: $e');
    }

    setState(() => _loading = false);
  }

  Future<void> _loadPartidos(String provId) async {
    final query = await db
        .collection('cat_departamentos')
        .where('provincia_id', isEqualTo: provId)
        .get();
    setState(() {
      partidos = query.docs.map((d) => d.data()).toList();
    });
  }

  Future<void> _loadLocalidades(String partId) async {
    final query = await db
        .collection('cat_localidades')
        .where('partido_id', isEqualTo: partId)
        .get();
    setState(() {
      localidades = query.docs.map((d) => d.data()).toList();
    });
  }

  Future<void> _onProvinciaChanged(String? provId) async {
    setState(() {
      selectedProvinciaId = provId;
      selectedPartidoId = null;
      selectedLocalidadId = null;
      partidos = [];
      localidades = [];
    });
    if (provId != null) await _loadPartidos(provId);
  }

  Future<void> _onPartidoChanged(String? partId) async {
    setState(() {
      selectedPartidoId = partId;
      selectedLocalidadId = null;
      localidades = [];
    });
    if (partId != null) await _loadLocalidades(partId);
  }

  Future<void> _actualizarDatos() async {
    if (!_formKey.currentState!.validate()) return;

    final tieneCalle = _calleController.text.trim().isNotEmpty;
    final tieneNumero = _numeroController.text.trim().isNotEmpty;

    // Si cargó calle o número → provincia, partido y localidad obligatorios
    if (tieneCalle || tieneNumero) {
      if (selectedProvinciaId == null ||
          selectedPartidoId == null ||
          selectedLocalidadId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Si cargás calle y número, también son obligatorios provincia, partido y localidad.',
            ),
          ),
        );
        return;
      }
    }

    final uid = UserSession().uid;
    if (uid == null) return;

    setState(() => _saving = true);

    try {
      String? provNombre;
      String? partNombre;
      String? locNombre;

      if (selectedProvinciaId != null) {
        final p = provincias
            .where((e) => e['id'].toString() == selectedProvinciaId)
            .toList();
        if (p.isNotEmpty) provNombre = p.first['nombre']?.toString();
      }
      if (selectedPartidoId != null) {
        final p = partidos
            .where(
              (e) =>
                  (e['departamento_id'] ?? e['id']).toString() ==
                  selectedPartidoId,
            )
            .toList();
        if (p.isNotEmpty) {
          partNombre =
              (p.first['departamento_nombre'] ?? p.first['nombre'])?.toString();
        }
      }
      if (selectedLocalidadId != null) {
        final p = localidades
            .where(
              (e) =>
                  (e['localidad_id'] ?? e['id']).toString() ==
                  selectedLocalidadId,
            )
            .toList();
        if (p.isNotEmpty) {
          locNombre =
              (p.first['localidad_nombre'] ?? p.first['nombre'])?.toString();
        }
      }

      await db.collection('usuarios').doc(uid).set({
        'calle': _calleController.text.trim(),
        'numero': _numeroController.text.trim(),
        'piso_depto': _pisoController.text.trim(),
        'cp': _cpController.text.trim(),
        'direccion_geo': {
          'provincia_id': selectedProvinciaId,
          'provincia_nombre': provNombre,
          'partido_id': selectedPartidoId,
          'partido_nombre': partNombre,
          'localidad_id': selectedLocalidadId,
          'localidad_nombre': locNombre,
        },
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Domicilio actualizado correctamente'),
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

    setState(() => _saving = false);
  }

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
          'Domicilio',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildField('Calle', _calleController),
                  _buildField('Número', _numeroController),
                  _buildField('Piso / Departamento', _pisoController),
                  _buildDropdown(
                    'Provincia',
                    selectedProvinciaId,
                    provincias
                        .map(
                          (p) => MapEntry(
                            p['id'].toString(),
                            p['nombre'].toString(),
                          ),
                        )
                        .toList(),
                    _onProvinciaChanged,
                  ),
                  _buildDropdown(
                    'Partido / Departamento',
                    selectedPartidoId,
                    partidos
                        .map(
                          (p) => MapEntry(
                            (p['departamento_id'] ?? p['id']).toString(),
                            (p['departamento_nombre'] ?? p['nombre'])
                                .toString(),
                          ),
                        )
                        .toList(),
                    _onPartidoChanged,
                  ),
                  _buildDropdown(
                    'Localidad',
                    selectedLocalidadId,
                    localidades
                        .map(
                          (l) => MapEntry(
                            (l['localidad_id'] ?? l['id']).toString(),
                            (l['localidad_nombre'] ?? l['nombre']).toString(),
                          ),
                        )
                        .toList(),
                    (v) => setState(() => selectedLocalidadId = v),
                  ),
                  _buildField(
                    'Código postal',
                    _cpController,
                    keyboard: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Si cargás calle y número, provincia, partido y localidad son obligatorios.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String? value,
    List<MapEntry<String, String>> items,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value != null && items.any((e) => e.key == value) ? value : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        items: items
            .map(
              (e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: onChanged,
        isExpanded: true,
      ),
    );
  }
}
