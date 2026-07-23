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

  static const _camposIgnorar = {
    'id',
    'created_at',
    'updated_at',
    'createdAt',
    'updatedAt',
    'timestamp',
    'activo',
    'active',
    'nombre',
    'name',
    'descripcion',
    'description',
    'tipo',
    'type',
  };

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
    await _cargarOficiosDesdeMaestro();
    await _cargarDatosUsuario();
    if (mounted) setState(() => _loading = false);
  }

  /// Los oficios son los NOMBRES DE CAMPOS dentro de documentos de la colección `maestro`.
  /// Ejemplo: jardineria, plomeria, gasista, electricista, etc.
  Future<void> _cargarOficiosDesdeMaestro() async {
    final Set<String> nombres = {};

    try {
      final snap = await db.collection('maestro').get();
      debugPrint('maestro: ${snap.docs.length} documento(s)');

      for (final doc in snap.docs) {
        final data = doc.data();
        debugPrint('maestro/${doc.id} keys: ${data.keys.toList()}');

        for (final key in data.keys) {
          final k = key.toString().trim();
          if (k.isEmpty) continue;
          if (_camposIgnorar.contains(k)) continue;
          if (k.startsWith('_')) continue;
          if (data[key] == false) continue;
          nombres.add(_formatearNombreOficio(k));
        }

        for (final value in data.values) {
          if (value is List) {
            for (final item in value) {
              if (item is String && item.trim().isNotEmpty) {
                nombres.add(_formatearNombreOficio(item.trim()));
              } else if (item is Map) {
                final n = (item['nombre'] ?? item['name'] ?? item['oficio'] ?? '').toString().trim();
                if (n.isNotEmpty) nombres.add(_formatearNombreOficio(n));
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error leyendo colección maestro: $e');
    }

    if (nombres.isEmpty) {
      for (final col in ['config', 'cat_config', 'catalogos', 'parametros']) {
        try {
          final doc = await db.collection(col).doc('maestro').get();
          if (doc.exists) {
            final data = doc.data()!;
            for (final key in data.keys) {
              final k = key.toString().trim();
              if (k.isEmpty || _camposIgnorar.contains(k) || k.startsWith('_')) continue;
              if (data[key] == false) continue;
              nombres.add(_formatearNombreOficio(k));
            }
            if (nombres.isNotEmpty) break;
          }
        } catch (_) {}
      }
    }

    final lista = nombres.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    _oficiosDisponibles = lista;
    debugPrint('Oficios desde maestro (${lista.length}): $lista');
  }

  String _formatearNombreOficio(String raw) {
    final conEspacios = raw.replaceAll('_', ' ').replaceAll('-', ' ').trim();
    if (conEspacios.isEmpty) return raw;
    return conEspacios
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
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
        _oficiosSeleccionados = profesiones.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toSet();

        for (final o in _oficiosSeleccionados) {
          final yaEsta = _oficiosDisponibles.any(
            (d) => d.toLowerCase() == o.toLowerCase() || d.toLowerCase().replaceAll(' ', '_') == o.toLowerCase(),
          );
          if (!yaEsta) {
            _oficiosDisponibles.add(_formatearNombreOficio(o));
          }
        }
        _oficiosDisponibles.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
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

  bool _estaSeleccionado(String oficio) {
    final lower = oficio.toLowerCase();
    final snake = lower.replaceAll(' ', '_');
    return _oficiosSeleccionados.any((s) {
      final sl = s.toLowerCase();
      return sl == lower || sl == snake || sl.replaceAll('_', ' ') == lower;
    });
  }

  void _toggleOficio(String oficio, bool selected) {
    setState(() {
      _oficiosSeleccionados.removeWhere((s) {
        final sl = s.toLowerCase();
        final lower = oficio.toLowerCase();
        final snake = lower.replaceAll(' ', '_');
        return sl == lower || sl == snake || sl.replaceAll('_', ' ') == lower;
      });
      if (selected) {
        _oficiosSeleccionados.add(oficio);
      }
    });
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
                Text(
                  _oficiosDisponibles.isEmpty
                      ? 'No se encontraron oficios en maestro'
                      : 'Podés elegir más de uno · fuente: maestro',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
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
                      'No se leyeron campos desde la colección "maestro".\n'
                      'Verificá que exista y que tenga campos como jardineria, plomeria, gasista, etc.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF9A3412)),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _oficiosDisponibles.map((oficio) {
                      final selected = _estaSeleccionado(oficio);
                      return FilterChip(
                        label: Text(oficio),
                        selected: selected,
                        selectedColor: primaryColor.withOpacity(0.15),
                        checkmarkColor: primaryColor,
                        labelStyle: TextStyle(
                          color: selected ? primaryColor : Colors.black87,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        onSelected: (val) => _toggleOficio(oficio, val),
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
