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
  String _fuente = '';

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
    await _cargarOficiosDesdeFirebase();
    await _cargarDatosUsuario();
    if (mounted) setState(() => _loading = false);
  }

  String _extraerNombre(Map<String, dynamic> data, String docId) {
    final candidatos = [
      data['nombre'],
      data['name'],
      data['oficio'],
      data['profesion'],
      data['titulo'],
      data['label'],
      data['descripcion'],
    ];
    for (final c in candidatos) {
      if (c != null && c.toString().trim().isNotEmpty) {
        return c.toString().trim();
      }
    }
    if (docId.isNotEmpty && docId.length < 50) return docId;
    return '';
  }

  Future<List<String>> _leerColeccion(String collectionName) async {
    final List<String> nombres = [];
    try {
      final snap = await db.collection(collectionName).get();
      for (final doc in snap.docs) {
        final nombre = _extraerNombre(doc.data(), doc.id);
        if (nombre.isNotEmpty) nombres.add(nombre);
      }
      debugPrint('Colección $collectionName → ${nombres.length} oficios');
    } catch (e) {
      debugPrint('Error leyendo $collectionName: $e');
    }
    return nombres;
  }

  Future<List<String>> _leerDocumentoLista(String collection, String docId) async {
    final List<String> nombres = [];
    try {
      final doc = await db.collection(collection).doc(docId).get();
      if (!doc.exists) return nombres;
      final data = doc.data()!;

      final posiblesListas = [
        data['lista'],
        data['items'],
        data['oficios'],
        data['profesiones'],
        data['rubros'],
        data['data'],
      ];

      for (final lista in posiblesListas) {
        if (lista is List && lista.isNotEmpty) {
          for (final item in lista) {
            if (item is String && item.trim().isNotEmpty) {
              nombres.add(item.trim());
            } else if (item is Map) {
              final n = (item['nombre'] ?? item['name'] ?? item['oficio'] ?? '').toString().trim();
              if (n.isNotEmpty) nombres.add(n);
            }
          }
          break;
        }
      }

      if (nombres.isEmpty) {
        data.forEach((key, value) {
          if (value is String && value.trim().isNotEmpty && key != 'updated_at') {
            nombres.add(value.trim());
          }
        });
      }

      debugPrint('Doc $collection/$docId → ${nombres.length} oficios');
    } catch (e) {
      debugPrint('Error leyendo $collection/$docId: $e');
    }
    return nombres;
  }

  Future<List<String>> _leerDesdeUsuarios() async {
    final Set<String> nombres = {};
    try {
      final snap = await db.collection('usuarios').limit(200).get();
      for (final doc in snap.docs) {
        final profesiones = doc.data()['profesiones'];
        if (profesiones is List) {
          for (final p in profesiones) {
            final s = p.toString().trim();
            if (s.isNotEmpty) nombres.add(s);
          }
        }
      }
      debugPrint('Usuarios → ${nombres.length} oficios únicos');
    } catch (e) {
      debugPrint('Error leyendo profesiones de usuarios: $e');
    }
    return nombres.toList();
  }

  Future<void> _cargarOficiosDesdeFirebase() async {
    List<String> nombres = [];

    final colecciones = [
      'cat_oficios',
      'oficios',
      'profesiones',
      'cat_profesiones',
      'rubros',
      'cat_rubros',
      'especialidades',
      'cat_especialidades',
    ];

    for (final col in colecciones) {
      nombres = await _leerColeccion(col);
      if (nombres.isNotEmpty) {
        _fuente = col;
        break;
      }
    }

    if (nombres.isEmpty) {
      final docsLista = [
        ['cat_config', 'oficios'],
        ['cat_config', 'profesiones'],
        ['catalogos', 'oficios'],
        ['catalogos', 'profesiones'],
        ['config', 'oficios'],
      ];
      for (final pair in docsLista) {
        nombres = await _leerDocumentoLista(pair[0], pair[1]);
        if (nombres.isNotEmpty) {
          _fuente = '${pair[0]}/${pair[1]}';
          break;
        }
      }
    }

    if (nombres.isEmpty) {
      nombres = await _leerDesdeUsuarios();
      if (nombres.isNotEmpty) _fuente = 'usuarios.profesiones';
    }

    final unicos = nombres.toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    _oficiosDisponibles = unicos;
    debugPrint('Oficios finales (${_oficiosDisponibles.length}) desde $_fuente');
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

        for (final o in _oficiosSeleccionados) {
          if (!_oficiosDisponibles.contains(o)) {
            _oficiosDisponibles.add(o);
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
                      ? 'No se encontraron oficios en la base'
                      : 'Podés elegir más de uno${_fuente.isNotEmpty ? ' · fuente: $_fuente' : ''}',
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
                      'No se encontraron oficios en Firebase.\n'
                      'Subí el archivo registroTrabajador.dart para ajustar la colección exacta.',
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
