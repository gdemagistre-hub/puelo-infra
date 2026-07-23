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
  final db = FirebaseFirestore.instance;

  String? selectedProvinciaId;
  Set<String> selectedPartidosIds = {};
  Set<String> selectedLocalidadesIds = {};

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

  Future<void> _cargarDatos() async {
    final uid = UserSession().uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final paisDoc = await db.collection('cat_paises').doc('AR').get();
      if (paisDoc.exists && paisDoc.data()!.containsKey('provincias')) {
        provincias = List<Map<String, dynamic>>.from(paisDoc.data()!['provincias']);
      }

      final doc = await db.collection('usuarios').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final cobertura = data['zonas_cobertura'] as Map<String, dynamic>?;

        if (cobertura != null) {
          selectedProvinciaId = cobertura['provincia_id']?.toString();
          final locs = cobertura['localidades'] as List<dynamic>? ?? [];

          for (final l in locs) {
            if (l is Map) {
              if (l['partido_id'] != null) selectedPartidosIds.add(l['partido_id'].toString());
              if (l['id'] != null) selectedLocalidadesIds.add(l['id'].toString());
            }
          }

          if (selectedProvinciaId != null) {
            await _loadPartidos(selectedProvinciaId!);
            for (final partId in selectedPartidosIds) {
              await _loadLocalidades(partId, append: true);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error cargando zona de trabajo: $e');
    }

    setState(() => _loading = false);
  }

  Future<void> _loadPartidos(String provId) async {
    final query = await db.collection('cat_departamentos').where('provincia_id', isEqualTo: provId).get();
    setState(() {
      partidos = query.docs.map((d) => d.data()).toList();
    });
  }

  Future<void> _loadLocalidades(String partId, {bool append = false}) async {
    final query = await db.collection('cat_localidades').where('partido_id', isEqualTo: partId).get();
    final nuevos = query.docs.map((d) => d.data()).toList();
    setState(() {
      if (append) {
        final idsExistentes = localidades.map((l) => (l['localidad_id'] ?? l['id']).toString()).toSet();
        for (final l in nuevos) {
          final id = (l['localidad_id'] ?? l['id']).toString();
          if (!idsExistentes.contains(id)) localidades.add(l);
        }
      } else {
        localidades = nuevos;
      }
    });
  }

  Future<void> _onProvinciaChanged(String? provId) async {
    setState(() {
      selectedProvinciaId = provId;
      selectedPartidosIds = {};
      selectedLocalidadesIds = {};
      partidos = [];
      localidades = [];
    });
    if (provId != null) await _loadPartidos(provId);
  }

  Future<void> _togglePartido(String partId, bool selected) async {
    setState(() {
      if (selected) {
        selectedPartidosIds.add(partId);
      } else {
        selectedPartidosIds.remove(partId);
        final locsDelPartido = localidades
            .where((l) => (l['partido_id'] ?? '').toString() == partId)
            .map((l) => (l['localidad_id'] ?? l['id']).toString())
            .toSet();
        selectedLocalidadesIds.removeAll(locsDelPartido);
      }
    });

    if (selected) {
      await _loadLocalidades(partId, append: true);
    } else {
      setState(() {
        localidades.removeWhere((l) => (l['partido_id'] ?? '').toString() == partId);
      });
    }
  }

  Future<void> _actualizarDatos() async {
    final uid = UserSession().uid;
    if (uid == null) return;

    if (selectedProvinciaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná una provincia')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      String? provNombre;
      final p = provincias.where((e) => e['id'].toString() == selectedProvinciaId).toList();
      if (p.isNotEmpty) provNombre = p.first['nombre']?.toString();

      final List<Map<String, dynamic>> locsData = [];
      for (final locId in selectedLocalidadesIds) {
        final match = localidades.where((l) => (l['localidad_id'] ?? l['id']).toString() == locId).toList();
        if (match.isNotEmpty) {
          final l = match.first;
          locsData.add({
            'id': locId,
            'nombre': (l['localidad_nombre'] ?? l['nombre'])?.toString(),
            'partido_id': (l['partido_id'] ?? '').toString(),
          });
        }
      }

      await db.collection('usuarios').doc(uid).set({
        'zonas_cobertura': {
          'provincia_id': selectedProvinciaId,
          'provincia_nombre': provNombre,
          'localidades': locsData,
        },
        'es_trabajador': true,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zona de trabajo actualizada'), backgroundColor: Colors.green),
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
        title: const Text('Zona de trabajo preferida', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Zona de cobertura',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Definí dónde prestás servicios',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedProvinciaId != null &&
                          provincias.any((p) => p['id'].toString() == selectedProvinciaId)
                      ? selectedProvinciaId
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Provincia',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  items: provincias
                      .map((p) => DropdownMenuItem(
                            value: p['id'].toString(),
                            child: Text(p['nombre'].toString()),
                          ))
                      .toList(),
                  onChanged: _onProvinciaChanged,
                  isExpanded: true,
                ),
                const SizedBox(height: 20),
                if (partidos.isNotEmpty) ...[
                  const Text('Partido / Departamento (podés elegir más de uno)',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: partidos.map((p) {
                      final id = (p['departamento_id'] ?? p['id']).toString();
                      final nombre = (p['departamento_nombre'] ?? p['nombre']).toString();
                      final selected = selectedPartidosIds.contains(id);
                      return FilterChip(
                        label: Text(nombre),
                        selected: selected,
                        selectedColor: primaryColor.withOpacity(0.15),
                        checkmarkColor: primaryColor,
                        onSelected: (val) => _togglePartido(id, val),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
                if (localidades.isNotEmpty) ...[
                  const Text('Localidad (podés elegir más de una)',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: localidades.map((l) {
                      final id = (l['localidad_id'] ?? l['id']).toString();
                      final nombre = (l['localidad_nombre'] ?? l['nombre']).toString();
                      final selected = selectedLocalidadesIds.contains(id);
                      return FilterChip(
                        label: Text(nombre),
                        selected: selected,
                        selectedColor: primaryColor.withOpacity(0.15),
                        checkmarkColor: primaryColor,
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              selectedLocalidadesIds.add(id);
                            } else {
                              selectedLocalidadesIds.remove(id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _actualizarDatos,
                    icon: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Guardando...' : 'Actualizar los datos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }
}
