import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'calificarTrabajo.dart';
import 'Homepage.dart';
import 'user_session.dart';
import 'theme/app_colors.dart';

/// Cliente elige prestador y pasa a calificar (estrellas + comentario).
/// Solo prestadores con vínculo previo: contacto (WA/llamada) o Mensajes.
class CargaTrabajoClienteWidget extends StatefulWidget {
  const CargaTrabajoClienteWidget({super.key});

  @override
  State<CargaTrabajoClienteWidget> createState() =>
      _CargaTrabajoClienteWidgetState();
}

class _CargaTrabajoClienteWidgetState extends State<CargaTrabajoClienteWidget> {
  DocumentReference? _selectedTrabajador;
  String? _selectedNombre;
  bool _isSaving = false;
  String _query = '';
  final _searchCtrl = TextEditingController();
  late final Future<List<DocumentSnapshot<Map<String, dynamic>>>> _vinculadosFuture;

  @override
  void initState() {
    super.initState();
    _vinculadosFuture = _cargarPrestadoresVinculados();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>>
      _cargarPrestadoresVinculados() async {
    final uid = UserSession().uid;
    if (uid == null || uid.isEmpty) return const [];

    final ids = <String>{};
    final db = FirebaseFirestore.instance;

    try {
      final contactos = await db
          .collection('contactos')
          .where('cliente_uid', isEqualTo: uid)
          .limit(80)
          .get();
      for (final doc in contactos.docs) {
        final p = (doc.data()['prestador_uid'] ?? '').toString().trim();
        if (p.isNotEmpty && p != uid) ids.add(p);
      }
    } catch (_) {}

    try {
      final convs = await db
          .collection('conversaciones')
          .where('participantes', arrayContains: uid)
          .limit(80)
          .get();
      for (final doc in convs.docs) {
        final parts = doc.data()['participantes'];
        if (parts is! List) continue;
        for (final raw in parts) {
          final p = raw.toString().trim();
          if (p.isNotEmpty && p != uid) ids.add(p);
        }
      }
    } catch (_) {}

    if (ids.isEmpty) return const [];

    final out = <DocumentSnapshot<Map<String, dynamic>>>[];
    for (final id in ids) {
      try {
        final doc = await db.collection('usuarios').doc(id).get();
        if (!doc.exists) continue;
        out.add(doc);
      } catch (_) {}
    }
    out.sort((a, b) => _displayName(a.data() ?? {})
        .toLowerCase()
        .compareTo(_displayName(b.data() ?? {}).toLowerCase()));
    return out;
  }

  String _displayName(Map<String, dynamic> data) {
    final comercial = (data['nombre_comercial'] ?? '').toString().trim();
    if (comercial.isNotEmpty) return comercial;
    final n = '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}'.trim();
    if (n.isNotEmpty) return n;
    final listNombre = (data['list_nombre'] ?? '').toString().trim();
    if (listNombre.isNotEmpty) return listNombre;
    return 'Sin nombre';
  }

  String _haystack(Map<String, dynamic> data) {
    final parts = <String>[
      (data['nombre_comercial'] ?? '').toString(),
      (data['nombre'] ?? '').toString(),
      (data['apellido'] ?? '').toString(),
      (data['list_nombre'] ?? '').toString(),
      if (data['profesiones'] is List) (data['profesiones'] as List).join(' '),
    ];
    return parts.join(' ').toLowerCase();
  }

  List<DocumentSnapshot<Map<String, dynamic>>> _filtrar(
    List<DocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return docs;
    final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    return docs.where((doc) {
      final h = _haystack(doc.data() ?? {});
      return tokens.every((t) => h.contains(t));
    }).toList();
  }

  Future<void> _continuarACalificar() async {
    if (_selectedTrabajador == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccioná el prestador del servicio.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final sessionUid = UserSession().uid;
    if (sessionUid == null || sessionUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesión no encontrada. Volvé a iniciar.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final clienteActualRef =
          FirebaseFirestore.instance.collection('usuarios').doc(sessionUid);

      final nuevoTrabajoRef =
          await FirebaseFirestore.instance.collection('trabajos').add({
        'trabajadorRef': _selectedTrabajador,
        'clienteRef': clienteActualRef,
        'usuario_id': _selectedTrabajador!.id,
        'fechaCarga': FieldValue.serverTimestamp(),
        'cargadoPor': 'Cliente',
        'tipo': 'evaluacion',
        'calificado': false,
        'comentarioCliente': '',
        'estrellas': 0,
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CalificarTrabajoWidget(
            trabajoId: nuevoTrabajoRef.id,
            trabajadorId: _selectedTrabajador!.id,
            clienteId: sessionUid,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo continuar: $e'),
            backgroundColor: const Color(0xFFB91C1C),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text(
          'Calificar servicio',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomePageWidget()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '¿A quién calificás?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Solo aparecen prestadores que contactaste (WhatsApp o llamada) '
              'o con los que ya tenés un hilo en Mensajes.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppColors.cliente, width: 1.5),
                ),
              ),
            ),
            if (_selectedNombre != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.cliente.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.cliente.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.cliente, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Seleccionado: $_selectedNombre',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _selectedTrabajador = null;
                        _selectedNombre = null;
                      }),
                      child: const Text('Cambiar'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<
                  List<DocumentSnapshot<Map<String, dynamic>>>>(
                future: _vinculadosFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(
                      'Error al cargar prestadores: ${snapshot.error}',
                      style: const TextStyle(color: Color(0xFFB91C1C)),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final todos = snapshot.data!;
                  final filtrados = _filtrar(todos);
                  if (todos.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Todavía no hay nadie para calificar.\n\n'
                          'Primero contactalo desde su tarjeta (WhatsApp o llamada) '
                          'o registrá un pago en Mensajes. Después aparece acá.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ),
                    );
                  }
                  if (filtrados.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No encontramos a nadie con “$_query” entre tus contactos.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: filtrados.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final doc = filtrados[i];
                      final data = doc.data() ?? {};
                      final name = _displayName(data);
                      final selected = _selectedTrabajador?.id == doc.id;
                      final profesiones = data['profesiones'] as List? ?? [];
                      final oficio = profesiones.isNotEmpty
                          ? profesiones.first.toString()
                          : '';
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        elevation: selected ? 2 : 0,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => setState(() {
                            _selectedTrabajador = doc.reference;
                            _selectedNombre = name;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? AppColors.cliente
                                    : const Color(0xFFE2E8F0),
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      AppColors.cliente.withOpacity(0.12),
                                  child: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: AppColors.cliente,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: AppColors.text,
                                        ),
                                      ),
                                      if (oficio.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          oficio,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (selected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.cliente,
                                  )
                                else
                                  Icon(
                                    Icons.circle_outlined,
                                    color: Colors.grey.shade400,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cliente,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isSaving ? null : _continuarACalificar,
                child: _isSaving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Continuar a calificar',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
