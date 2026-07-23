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
  Set<String> _oficiosSeleccionados = {};
  bool _loading = true;
  bool _saving = false;

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
    await Future.wait([
      _cargarOficiosDesdeFirebase(),
      _cargarDatosUsuario(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _cargarOficiosDesdeFirebase() async {
    final List<String> nombres = [];

    try {
      final snap = await db.collection('cat_oficios').orderBy('nombre').get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final nombre = (data['nombre'] ?? data['name'] ?? data['oficio'] ?? doc.id).toString().trim();
        if (nombre.isNotEmpty) nombres.add(nombre);
      }
    } catch (e) {
      debugPrint('cat_oficios: $e');
    }

    if (nombres.isEmpty) {
      try {
        final snap = await db.collection('oficios').orderBy('nombre').get();
        for (final doc in snap.docs) {
          final data = doc.data();
          final nombre = (data['nombre'] ?? data['name'] ?? data['oficio'] ?? doc.id).toString().trim();
          if (nombre.isNotEmpty) nombres.add(nombre);
        }
      } catch (e) {
        debugPrint('oficios: $e');
      }
    }

    if (nombres.isEmpty) {
      try {
        final snap = await db.collection('profesiones').orderBy('nombre').get();
        for (final doc in snap.docs) {
          final data = doc.data();
          final nombre = (data['nombre'] ?? data['name'] ?? doc.id).toString().trim();
          if (nombre.isNotEmpty) nombres.add(nombre);
        }
      } catch (e) {
        debugPrint('profesiones: $e');
      }
    }

    if (nombres.isEmpty) {
      try {
        final doc = await db.collection('cat_config').doc('oficios').get();
        if (doc.exists) {
          final lista = doc.data()?['lista'] as List<dynamic>? ??
              doc.data()?['items'] as List<dynamic>? ??
              [];
          for (final item in lista) {
            if (item is String && item.trim().isNotEmpty) {
              nombres.add(item.trim());
            } else if (item is Map) {
              final n = (item['nombre'] ?? item['name'] ?? '').toString().trim();
              if (n.isNotEmpty) nombres.add(n);
            }
          }
        }
      } catch (e) {
        debugPrint('cat_config/oficios: $e');
      }
    }

    final unicos = nombres.toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    _oficiosDisponibles = unicos;
  }

  Future<void> _cargarDatosUsuario() async {
    final uid = UserSession().uid;
    if (uid == null) return;

    try {
      final doc = await db.collection('usuarios').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _nombreComercialController.text =
            (data['nombre_comercial'] ?? data['nombreComercial'] ?? '').toString();
        final profesiones = data['profesiones'] as List<dynamic>? ?? [];
        _oficiosSeleccionados = profesiones.map((e) => e.toString()).toSet();
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
        'profesiones': _oficiosSeleccionados.toList(),
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
          'Especialidades laborales',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
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
                if (_oficiosDisponibles.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: const Text(
                      'No se encontraron oficios en Firebase.\n'
                      'Verificá que exista la colección cat_oficios (o oficios) con campo "nombre".',
                      style: TextStyle(fontSize: 13, color: Color(0xFF9A3412)),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _oficiosDisponibles.map((oficio) {
                      final selected = _oficiosSeleccionados.contains(oficio);
                      return FilterChip(
                        label: Text(oficio),
                        selected: selected,
                        selectedColor: primaryColor.withOpacity(0.15),
                        checkmarkColor: primaryColor,
                        labelStyle: TextStyle(
                          color: selected ? primaryColor : Colors.black87,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _oficiosSeleccionados.add(oficio);
                            } else {
                              _oficiosSeleccionados.remove(oficio);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
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
