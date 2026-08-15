import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_session.dart';
import 'catalogo_oficios.dart';
import 'prestador_list_fields.dart';

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

  /// Evaluaciones recibidas: si > 0 no se puede quedar sin oficios.
  int _cantidadEvaluaciones = 0;

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
    _oficiosDisponibles = CatalogoOficios.maestroIds();
    try {
      final oficiosSnapshot = await db.collection('cat_oficios').get();
      for (final doc in oficiosSnapshot.docs) {
        final data = doc.data();
        final raw = data['maestro'];
        if (raw is List && raw.isNotEmpty) {
          final remoto = raw
              .map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList();
          final set = {..._oficiosDisponibles, ...remoto};
          _oficiosDisponibles = set.toList()..sort();
          break;
        }
      }
    } catch (e) {
      debugPrint('cat_oficios remoto no disponible, uso local: $e');
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
        final n = data['cantidadEvaluadores'] ??
            data['list_n_eval'] ??
            data['cantidad_evaluadores'] ??
            0;
        _cantidadEvaluaciones = (n is num) ? n.toInt() : int.tryParse('$n') ?? 0;
      }
    } catch (e) {
      debugPrint('Error cargando datos usuario: $e');
    }
  }

  String _labelOficio(String clave) => CatalogoOficios.label(clave);

  Future<void> _guardar() async {
    final uid = UserSession().uid;
    if (uid == null) return;

    // Sin servicios: solo si todavía no lo evaluaron → pasa a cliente.
    if (_oficiosSeleccionados.isEmpty) {
      if (_cantidadEvaluaciones > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No podés quitar todos los servicios: ya tenés evaluaciones.',
            ),
            backgroundColor: Color(0xFFB45309),
          ),
        );
        return;
      }

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Dejar de ofrecer servicios?'),
          content: const Text(
            'Vas a guardar el perfil sin oficios y quedar solo como cliente.\n'
            'Podés volver a ofrecer servicios cuando quieras.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: primaryColor),
              child: const Text('Sí, quedar como cliente'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _saving = true);
    try {
      final vacio = _oficiosSeleccionados.isEmpty;
      final categorias = vacio
          ? <String>[]
          : CatalogoOficios.categoriasDesdeProfesiones(_oficiosSeleccionados);
      final session = UserSession();
      final base = {
        ...(session.datosCompletos ?? {}),
        'nombre_comercial': _nombreComercialController.text.trim(),
        'profesiones': _oficiosSeleccionados,
        'categorias_servicio': categorias,
        'es_trabajador': !vacio,
        if (vacio) 'rol': 'cliente',
        if (vacio) 'camino_elegido': 'busco',
        if (!vacio) 'rol': 'trabajador',
      };
      final listFields = PrestadorListFields.build(data: base);
      final listFieldsMem =
          PrestadorListFields.build(data: base, touchTimestamp: false);

      final patch = <String, dynamic>{
        'nombre_comercial': _nombreComercialController.text.trim(),
        'profesiones': _oficiosSeleccionados,
        'categorias_servicio': categorias,
        'es_trabajador': !vacio,
        'updated_at': FieldValue.serverTimestamp(),
        ...listFields,
      };
      if (vacio) {
        patch['rol'] = 'cliente';
        patch['camino_elegido'] = 'busco';
        // Limpia texto libre de onboarding si quedó.
        patch['oficio_libre'] = FieldValue.delete();
      } else {
        patch['rol'] = 'trabajador';
      }

      await db.collection('usuarios').doc(uid).set(patch, SetOptions(merge: true));

      session.datosCompletos = {
        ...(session.datosCompletos ?? {}),
        'nombre_comercial': _nombreComercialController.text.trim(),
        'profesiones': List<String>.from(_oficiosSeleccionados),
        'categorias_servicio': categorias,
        'es_trabajador': !vacio,
        'rol': vacio ? 'cliente' : 'trabajador',
        if (vacio) 'camino_elegido': 'busco',
        if (vacio) 'oficio_libre': null,
        ...listFieldsMem,
      };
      session.invalidateHomeCache();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              vacio
                  ? 'Perfil actualizado: quedaste como cliente'
                  : 'Servicios actualizados',
            ),
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
    String? catExpandida;
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
            final alto = MediaQuery.of(context).size.height * 0.85;
            return SafeArea(
              child: SizedBox(
                height: alto,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Servicios que ofrezco',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Elegí categoría y después las especialidades. '
                        'El cliente te encuentra por las dos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            height: 1.3),
                      ),
                      const SizedBox(height: 8),
                      if (_oficiosSeleccionados.isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${_oficiosSeleccionados.length} seleccionada(s)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView(
                          children: [
                            for (final cat in CatalogoOficios.categorias) ...[
                              _CategoriaTile(
                                categoria: cat,
                                expanded: catExpandida == cat.id,
                                seleccionados: _oficiosSeleccionados,
                                primary: primaryColor,
                                onToggleExpand: () {
                                  setModalState(() {
                                    catExpandida =
                                        catExpandida == cat.id ? null : cat.id;
                                  });
                                },
                                onToggleEsp: (espId, selected) {
                                  setModalState(() {
                                    if (selected) {
                                      if (!_oficiosSeleccionados
                                          .contains(espId)) {
                                        _oficiosSeleccionados.add(espId);
                                      }
                                    } else {
                                      _oficiosSeleccionados.remove(espId);
                                    }
                                  });
                                  setState(() {});
                                },
                              ),
                              const SizedBox(height: 8),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              '¿No está tu oficio? Escribinos y lo sumamos. '
                              'Mientras tanto elegí la categoría más cercana.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
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
                          child: const Text('Listo',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
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
                Text(
                  _cantidadEvaluaciones > 0
                      ? 'Podés sacar o sumar oficios. Si ya te evaluaron, '
                          'tenés que dejar al menos uno.'
                      : 'Podés sacar todos y guardar: quedás solo como cliente.',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
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
                                    ? 'Ninguno (solo cliente)'
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
                      _saving
                          ? 'Guardando...'
                          : (_oficiosSeleccionados.isEmpty
                              ? 'Guardar (solo cliente)'
                              : 'Actualizar los datos'),
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

class _CategoriaTile extends StatelessWidget {
  final OficioCategoria categoria;
  final bool expanded;
  final List<String> seleccionados;
  final Color primary;
  final VoidCallback onToggleExpand;
  final void Function(String espId, bool selected) onToggleEsp;

  const _CategoriaTile({
    required this.categoria,
    required this.expanded,
    required this.seleccionados,
    required this.primary,
    required this.onToggleExpand,
    required this.onToggleEsp,
  });

  @override
  Widget build(BuildContext context) {
    final esps = CatalogoOficios.especialidadesDe(categoria.id);
    final nSel = esps.where((e) => seleccionados.contains(e.id)).length;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: nSel > 0 ? primary.withOpacity(0.45) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: onToggleExpand,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(categoria.icon, color: primary, size: 22),
            ),
            title: Text(
              categoria.label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            subtitle: Text(
              nSel > 0 ? '$nSel especialidad(es)' : '${esps.length} opciones',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.grey.shade500,
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(
                children: [
                  for (final esp in esps)
                    CheckboxListTile(
                      dense: true,
                      value: seleccionados.contains(esp.id),
                      activeColor: primary,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        esp.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 14),
                      ),
                      onChanged: (v) => onToggleEsp(esp.id, v == true),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
