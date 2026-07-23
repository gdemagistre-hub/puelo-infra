import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_session.dart';

class EspecialidadesLaboralesFlotanteWidget extends StatefulWidget {
  const EspecialidadesLaboralesFlotanteWidget({super.key});

  @override
  State<EspecialidadesLaboralesFlotanteWidget> createState() => _EspecialidadesLaboralesFlotanteWidgetState();
}

class _EspecialidadesLaboralesFlotanteWidgetState extends State<EspecialidadesLaboralesFlotanteWidget> {
  final primaryColor = const Color(0xFF0F52BA);
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

  /// Misma fuente que registroTrabajador.dart:
  /// colección cat_oficios → campo lista "maestro"
  Future<void> _cargarCatalogos() async {
    try {
      final oficiosSnapshot = await db.collection('cat_oficios').get();
      debugPrint('cat_oficios docs: ${oficiosSnapshot.docs.length}');

      for (final doc in oficiosSnapshot.docs) {
        final data = doc.data();
        debugPrint('cat_oficios/${doc.id} keys=${data.keys.toList()}');

        final raw = data['maestro'];
        if (raw is List && raw.isNotEmpty) {
          _oficiosDisponibles =
              raw.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
          debugPrint('Oficios OK (${_oficiosDisponibles.length}): $_oficiosDisponibles');
          return;
        }
      }

      if (_oficiosDisponibles.isEmpty) {
        _errorCarga = oficiosSnapshot.docs.isEmpty
            ? 'La colección cat_oficios está vacía o no hay permisos de lectura.'
            : 'Ningún documento de cat_oficios tiene el campo lista "maestro".';
      }
    } catch (e) {
      _errorCarga = 'Error leyendo cat_oficios: $e';
      debugPrint(_errorCarga);
      rethrow;
    }
  }

  Future<void> _cargarDatosUsuario() async {
    final uid = UserSession().uid;
    if (uid == null) return;

    try {
      final doc = await db.collection('usuarios').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _nombreComercialController.text = (data['nombre_comercial'] ?? '').toString();
        if (data['profesiones'] != null) {
          _oficiosSeleccionados = List<String>.from(data['profesiones']);
        }
      }
    } catch (e) {
      debugPrint('Error cargando datos usuario: $e');
    }
  }

  Future<void> _actualizarDatos() async {
    final uid = UserSession().uid;
    if (uid == null) return;

    if (_oficiosSeleccionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná al menos una especialidad')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await db.collection('usuarios').doc(uid).set({
        'nombre_comercial': _nombreComercialController.text.trim(),
        'profesiones': _oficiosSeleccionados,
        'es_trabajador': true,
        'rol': 'trabajador',
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Especialidades actualizadas'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }

    if (mounted) setState(() => _saving = false);
  }

  void _mostrarSeleccionEspecialidades() {
    final opciones = _oficiosDisponibles.map((p) => {'id': p, 'nombre': p}).toList();
    List<Map<String, String>> tempSeleccionadas =
        _oficiosSeleccionados.map((p) => {'id': p, 'nombre': p}).toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Especialidades',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: opciones.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No hay especialidades disponibles.', textAlign: TextAlign.center),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: opciones.length,
                        itemBuilder: (context, index) {
                          final item = opciones[index];
                          final isChecked = tempSeleccionadas.any((e) => e['id'] == item['id']);
                          return CheckboxListTile(
                            title: Text(item['nombre']!, style: const TextStyle(color: Color(0xFF1E293B))),
                            value: isChecked,
                            activeColor: primaryColor,
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  tempSeleccionadas.add(item);
                                } else {
                                  tempSeleccionadas.removeWhere((e) => e['id'] == item['id']);
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
                    setState(() {
                      _oficiosSeleccionados = tempSeleccionadas.map((e) => e['nombre']!).toList();
                    });
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
          'Especialidades laborales',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            tooltip: 'Recargar oficios',
            onPressed: _loading ? null : _cargarTodo,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextFormField(
                  controller: _nombreComercialController,
                  decoration: InputDecoration(
                    labelText: 'Nombre comercial',
                    hintText: 'Ej: Servicios Eléctricos López',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Oficios / Especialidades',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Podés elegir más de uno',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _oficiosDisponibles.isEmpty ? null : _mostrarSeleccionEspecialidades,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Oficios / Especialidades',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _oficiosSeleccionados.isEmpty
                                    ? 'Seleccionar Especialidades'
                                    : _oficiosSeleccionados.join(', '),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                if (_oficiosDisponibles.isEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'No se cargaron oficios desde cat_oficios.maestro',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9A3412),
                          ),
                        ),
                        if (_errorCarga != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _errorCarga!,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF9A3412)),
                          ),
                        ],
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _cargarTodo,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  if (_oficiosSeleccionados.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _oficiosSeleccionados.map((o) {
                        return Chip(
                          label: Text(o),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () {
                            setState(() => _oficiosSeleccionados.remove(o));
                          },
                          backgroundColor: primaryColor.withOpacity(0.1),
                          labelStyle: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '${_oficiosDisponibles.length} especialidades disponibles en catálogo',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _actualizarDatos,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Guardando...' : 'Actualizar los datos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
