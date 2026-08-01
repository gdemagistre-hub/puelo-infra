import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_session.dart';

class EspecialidadesLaboralesFlotanteWidget extends StatefulWidget {
  const EspecialidadesLaboralesFlotanteWidget({super.key});

  @override
  State<EspecialidadesLaboralesFlotanteWidget> createState() =>
      _EspecialidadesLaboralesFlotanteWidgetState();
}

class _EspecialidadesLaboralesFlotanteWidgetState
    extends State<EspecialidadesLaboralesFlotanteWidget> {
  static const Color primaryColor = Color(0xFF28B5CD);
  static const Color _bg = Color(0xFFF8FAFC);
  static const Color _textColor = Color(0xFF1E293B);

  final db = FirebaseFirestore.instance;
  final _nombreComercialController = TextEditingController();

  List<String> _oficiosDisponibles = [];
  List<String> _oficiosSeleccionados = [];

  bool _loading = true;
  bool _saving = false;
  String? _errorCarga;

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  @override
  void dispose() {
    _nombreComercialController.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    setState(() {
      _loading = true;
      _errorCarga = null;
    });

    try {
      await _cargarCatalogos();
      await _cargarDatosUsuario();
    } catch (e) {
      _errorCarga = e.toString();
      debugPrint('Error general carga: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _cargarCatalogos() async {
    try {
      final oficiosSnapshot = await db.collection('cat_oficios').get();
      debugPrint('cat_oficios docs: ${oficiosSnapshot.docs.length}');

      for (final doc in oficiosSnapshot.docs) {
        final data = doc.data();
        final raw = data['maestro'];
        if (raw is List && raw.isNotEmpty) {
          _oficiosDisponibles = raw
              .map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList();
          return;
        }
      }

      if (_oficiosDisponibles.isEmpty) {
        debugPrint(
          oficiosSnapshot.docs.isEmpty
              ? 'cat_oficios vacía; usando catálogo local de oficios.'
              : 'cat_oficios sin campo maestro; usando catálogo local.',
        );
        _oficiosDisponibles = const [
          'electricidad',
          'carpinteria',
          'plomeria',
          'jardineria',
          'limpieza',
          'pintura',
          'gasista',
          'albanileria',
        ];
      }
    } catch (e) {
      debugPrint('Error leyendo cat_oficios: $e');
      // Fallback local si rules aún no permiten cat_oficios o hay fallo de red.
      _oficiosDisponibles = const [
        'electricidad',
        'carpinteria',
        'plomeria',
        'jardineria',
        'limpieza',
        'pintura',
        'gasista',
        'albanileria',
      ];
      _errorCarga = null;
    }
  }

  Future<void> _cargarDatosUsuario() async {
    final uid = UserSession().uid;
    if (uid == null) return;

    try {
      final doc = await db.collection('usuarios').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _nombreComercialController.text =
            (data['nombre_comercial'] ?? '').toString();
        if (data['profesiones'] != null) {
          _oficiosSeleccionados = List<String>.from(data['profesiones']);
        }
      }
    } catch (e) {
      debugPrint('Error cargando datos usuario: $e');
    }
  }

  String _labelOficio(String clave) {
    const labels = {
      'electricidad': 'Electricista',
      'plomeria': 'Plomería',
      'gasista': 'Gasista',
      'carpinteria': 'Carpintería',
      'pintura': 'Pintura',
      'albanileria': 'Construcción',
      'jardineria': 'Jardinería',
      'limpieza': 'Limpieza',
    };
    final k = clave.toLowerCase().trim();
    return labels[k] ?? clave;
  }

  Future<void> _guardar() async {
    final uid = UserSession().uid;
    if (uid == null) return;

    if (_oficiosSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná al menos un servicio')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await db.collection('usuarios').doc(uid).set({
        'nombre_comercial': _nombreComercialController.text.trim(),
        'profesiones': _oficiosSeleccionados,
        'es_trabajador': true,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final session = UserSession();
      if (session.datosCompletos != null) {
        session.datosCompletos = {
          ...session.datosCompletos!,
          'nombre_comercial': _nombreComercialController.text.trim(),
          'profesiones': _oficiosSeleccionados,
          'es_trabajador': true,
        };
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Servicios actualizados'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  void _mostrarSeleccionEspecialidades() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Servicios que ofrezco',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Podés elegir más de uno',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: _oficiosDisponibles.map((oficio) {
                          final selected =
                              _oficiosSeleccionados.contains(oficio);
                          return CheckboxListTile(
                            value: selected,
                            activeColor: primaryColor,
                            title: Text(
                              _labelOficio(oficio),
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            onChanged: (v) {
                              setModalState(() {
                                if (v == true) {
                                  if (!_oficiosSeleccionados.contains(oficio)) {
                                    _oficiosSeleccionados.add(oficio);
                                  }
                                } else {
                                  _oficiosSeleccionados.remove(oficio);
                                }
                              });
                              setState(() {});
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Listo'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _dec(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
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
          'Mis servicios',
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: primaryColor,
            onPressed: _loading ? null : _cargarTodo,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextField(
                  controller: _nombreComercialController,
                  decoration: _dec('Nombre comercial'),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Servicios que ofrezco',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Podés elegir más de uno',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _oficiosDisponibles.isEmpty
                      ? null
                      : _mostrarSeleccionEspecialidades,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Servicios que ofrezco',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _oficiosSeleccionados.isEmpty
                                    ? 'Seleccionar servicios'
                                    : _oficiosSeleccionados
                                        .map(_labelOficio)
                                        .join(' · '),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: _oficiosSeleccionados.isEmpty
                                      ? Colors.grey.shade500
                                      : _textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.expand_more, color: Colors.grey.shade600),
                      ],
                    ),
                  ),
                ),
                if (_oficiosSeleccionados.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _oficiosSeleccionados.map((o) {
                      return Chip(
                        label: Text(_labelOficio(o)),
                        backgroundColor: primaryColor.withOpacity(0.12),
                        labelStyle: const TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                        deleteIconColor: primaryColor,
                        onDeleted: () {
                          setState(() => _oficiosSeleccionados.remove(o));
                        },
                      );
                    }).toList(),
                  ),
                ],
                if (_errorCarga != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDBA74)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _errorCarga!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9A3412),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _cargarTodo,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Reintentar'),
                          style: TextButton.styleFrom(
                            foregroundColor: primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _guardar,
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
              ],
            ),
    );
  }
}
