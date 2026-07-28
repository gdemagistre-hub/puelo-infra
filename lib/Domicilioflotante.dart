import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_session.dart';
import 'widgets/searchable_picker.dart';
import 'catalogo_geo_cache.dart';

class DomicilioFlotanteWidget extends StatefulWidget {
  const DomicilioFlotanteWidget({super.key});

  @override
  State<DomicilioFlotanteWidget> createState() =>
      _DomicilioFlotanteWidgetState();
}

class _DomicilioFlotanteWidgetState extends State<DomicilioFlotanteWidget> {
  static const Color primaryColor = Color(0xFF734BE4);
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _textColor = Color(0xFF1E293B);

  final db = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  final _calleController = TextEditingController();
  final _numeroController = TextEditingController();
  final _pisoController = TextEditingController();
  final _cpController = TextEditingController();

  String? selectedProvinciaId;
  String? selectedProvinciaNombre;
  String? selectedPartidoId;
  String? selectedPartidoNombre;
  String? selectedLocalidadId;
  String? selectedLocalidadNombre;

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

  InputDecoration _dec(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      labelStyle: TextStyle(color: Colors.grey.shade600),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Future<void> _cargarDatos() async {
    final uid = UserSession().uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      provincias = await CatalogoGeoCache.instance.provinciasAR();

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
          selectedProvinciaNombre = geo['provincia_nombre']?.toString();
          selectedPartidoId = geo['partido_id']?.toString();
          selectedPartidoNombre = geo['partido_nombre']?.toString();
          selectedLocalidadId = geo['localidad_id']?.toString();
          selectedLocalidadNombre = geo['localidad_nombre']?.toString();

          if (selectedProvinciaId != null) {
            partidos = await CatalogoGeoCache.instance
                .partidosDeProvincia(selectedProvinciaId!);
          }
          if (selectedPartidoId != null) {
            localidades = await CatalogoGeoCache.instance
                .localidadesDePartido(selectedPartidoId!);
          }
        }
      }
    } catch (e) {
      debugPrint('Error cargando domicilio: $e');
    }

    setState(() => _loading = false);
  }

  Future<void> _abrirProvincia() async {
    final opciones = provincias
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
      titulo: 'Provincia',
      opciones: opciones,
      selectedId: selectedProvinciaId,
      accent: primaryColor,
      hintBuscar: 'Escribí el nombre de la provincia…',
    );
    if (elegido == null) return;

    setState(() {
      selectedProvinciaId = elegido['id'];
      selectedProvinciaNombre = elegido['nombre'];
      selectedPartidoId = null;
      selectedPartidoNombre = null;
      selectedLocalidadId = null;
      selectedLocalidadNombre = null;
      partidos = [];
      localidades = [];
    });

    partidos = await CatalogoGeoCache.instance
        .partidosDeProvincia(elegido['id']!);
    if (mounted) setState(() {});
  }

  Future<void> _abrirPartido() async {
    if (selectedProvinciaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero elegí la provincia')),
      );
      return;
    }

    final opciones = partidos
        .map(
          (p) => {
            'id': (p['departamento_id'] ?? p['id']).toString(),
            'nombre': (p['departamento_nombre'] ?? p['nombre']).toString(),
          },
        )
        .toList()
      ..sort((a, b) => a['nombre']!.compareTo(b['nombre']!));

    final elegido = await SearchablePicker.pickSingle(
      context: context,
      titulo: 'Partido / Departamento',
      opciones: opciones,
      selectedId: selectedPartidoId,
      accent: primaryColor,
      hintBuscar: 'Escribí el nombre del partido…',
    );
    if (elegido == null) return;

    setState(() {
      selectedPartidoId = elegido['id'];
      selectedPartidoNombre = elegido['nombre'];
      selectedLocalidadId = null;
      selectedLocalidadNombre = null;
      localidades = [];
    });

    localidades = await CatalogoGeoCache.instance
        .localidadesDePartido(elegido['id']!);
    if (mounted) setState(() {});
  }

  Future<void> _abrirLocalidad() async {
    if (selectedPartidoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero elegí el partido')),
      );
      return;
    }

    final opciones = localidades
        .map(
          (l) => {
            'id': (l['localidad_id'] ?? l['id']).toString(),
            'nombre': (l['localidad_nombre'] ?? l['nombre']).toString(),
          },
        )
        .toList()
      ..sort((a, b) => a['nombre']!.compareTo(b['nombre']!));

    final elegido = await SearchablePicker.pickSingle(
      context: context,
      titulo: 'Localidad',
      opciones: opciones,
      selectedId: selectedLocalidadId,
      accent: primaryColor,
      hintBuscar: 'Escribí el nombre de la localidad…',
    );
    if (elegido == null) return;

    setState(() {
      selectedLocalidadId = elegido['id'];
      selectedLocalidadNombre = elegido['nombre'];
    });
  }

  Future<void> _actualizarDatos() async {
    if (!_formKey.currentState!.validate()) return;

    final tieneCalle = _calleController.text.trim().isNotEmpty;
    final tieneNumero = _numeroController.text.trim().isNotEmpty;

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
      await db.collection('usuarios').doc(uid).set({
        'calle': _calleController.text.trim(),
        'numero': _numeroController.text.trim(),
        'piso_depto': _pisoController.text.trim(),
        'cp': _cpController.text.trim(),
        'direccion_geo': {
          'provincia_id': selectedProvinciaId,
          'provincia_nombre': selectedProvinciaNombre,
          'partido_id': selectedPartidoId,
          'partido_nombre': selectedPartidoNombre,
          'localidad_id': selectedLocalidadId,
          'localidad_nombre': selectedLocalidadNombre,
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
          'Domicilio',
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
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildField('Calle', _calleController),
                  _buildField('Número', _numeroController),
                  _buildField('Piso / Departamento', _pisoController),
                  _buildGeoTile(
                    label: 'Provincia',
                    value: selectedProvinciaNombre ?? 'Buscar o elegir…',
                    onTap: _abrirProvincia,
                  ),
                  _buildGeoTile(
                    label: 'Partido / Departamento',
                    value: selectedPartidoNombre ?? 'Buscar o elegir…',
                    onTap: _abrirPartido,
                  ),
                  _buildGeoTile(
                    label: 'Localidad',
                    value: selectedLocalidadNombre ?? 'Buscar o elegir…',
                    onTap: _abrirLocalidad,
                  ),
                  _buildField(
                    'Código postal',
                    _cpController,
                    keyboard: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tocá provincia, partido o localidad para buscar escribiendo o desplazarte por la lista.',
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
        decoration: _dec(label),
      ),
    );
  }

  Widget _buildGeoTile({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: _dec(label).copyWith(
            suffixIcon: const Icon(Icons.search),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: value.startsWith('Buscar')
                  ? Colors.grey.shade500
                  : _textColor,
            ),
          ),
        ),
      ),
    );
  }
}
