import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'Homepage.dart';
import 'mensajes/mensajes_service.dart';
import 'theme/app_colors.dart';
import 'user_session.dart';

/// Prestador evalúa a un cliente con el que ya tuvo interacción en Mensajes
/// (recibo, calificación o chat). Solo señales neutras/positivas.
class EvaluarClienteWidget extends StatefulWidget {
  const EvaluarClienteWidget({super.key});

  @override
  State<EvaluarClienteWidget> createState() => _EvaluarClienteWidgetState();
}

class _EvaluarClienteWidgetState extends State<EvaluarClienteWidget> {
  final _searchCtrl = TextEditingController();
  final _comentarioCtrl = TextEditingController();
  String _query = '';
  String? _selectedUid;
  String? _selectedNombre;
  int _estrellas = 0;
  bool _enviando = false;
  final Set<String> _tags = {};

  static const _tagOptions = [
    'Puntual',
    'Claro',
    'Respetuoso',
    'Recomendable',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _comentarioCtrl.dispose();
    super.dispose();
  }

  Future<List<_ClienteItem>> _cargarClientesDesdeMensajes(String myUid) async {
    final snap = await FirebaseFirestore.instance
        .collection('conversaciones')
        .where('participantes', arrayContains: myUid)
        .orderBy('last_event_at', descending: true)
        .limit(80)
        .get();

    final seen = <String>{};
    final items = <_ClienteItem>[];

    for (final doc in snap.docs) {
      final d = doc.data();
      final other = MensajesService.otherParticipantUid(
        myUid: myUid,
        convId: doc.id,
        data: d,
      );
      if (other == null || other.isEmpty || other == myUid) continue;
      if (!seen.add(other)) continue;

      final name = await MensajesService.instance.resolveDisplayName(other);
      final summary = (d['last_summary'] ?? '').toString();
      items.add(_ClienteItem(
        uid: other,
        nombre: name,
        convId: doc.id,
        lastSummary: summary,
      ));
    }
    return items;
  }

  List<_ClienteItem> _filtrar(List<_ClienteItem> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    return all.where((c) {
      final h = '${c.nombre} ${c.lastSummary}'.toLowerCase();
      return tokens.every((t) => h.contains(t));
    }).toList();
  }

  Future<void> _enviar() async {
    final myUid = UserSession().uid;
    if (myUid == null || myUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesión no encontrada.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_selectedUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Elegí un cliente de la lista.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_estrellas < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Elegí al menos 1 estrella.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _enviando = true);
    try {
      final comentario = _comentarioCtrl.text.trim();
      await FirebaseFirestore.instance.collection('calificaciones').add({
        'tipo': 'cliente',
        'cliente_id': _selectedUid,
        'prestador_id': myUid,
        'trabajador_id': myUid,
        'estrellas': _estrellas,
        'rating': _estrellas,
        'comentario': comentario,
        'tags': _tags.toList(),
        'estado': 'publicada',
        'origen': 'mensajes',
        'created_at': FieldValue.serverTimestamp(),
        'fecha': FieldValue.serverTimestamp(),
        'par_completo': false,
        'aceptado_por_prestador': true,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gracias. Tu evaluación del cliente quedó registrada.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar: $e'),
          backgroundColor: const Color(0xFFB91C1C),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = UserSession().uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text(
          'Evaluar a un cliente',
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
                MaterialPageRoute(builder: (_) => const HomePageWidget()),
                (_) => false,
              );
            },
          ),
        ],
      ),
      body: myUid.isEmpty
          ? const Center(child: Text('Iniciá sesión para continuar.'))
          : FutureBuilder<List<_ClienteItem>>(
              future: _cargarClientesDesdeMensajes(myUid),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No se pudieron cargar contactos: ${snap.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFB91C1C)),
                      ),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snap.data!;
                final filtrados = _filtrar(all);

                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        children: [
                          const Text(
                            'Solo aparecen clientes con los que ya tuviste un intercambio en Mensajes (recibo, evaluación o chat).',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _searchCtrl,
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
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: AppColors.prestador,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          if (_selectedNombre != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.prestador.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.prestador.withOpacity(0.25),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded,
                                      color: AppColors.prestador, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Cliente: $_selectedNombre',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => setState(() {
                                      _selectedUid = null;
                                      _selectedNombre = null;
                                    }),
                                    child: const Text('Cambiar'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          if (all.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Text(
                                'Todavía no tenés intercambios en Mensajes. '
                                'Cuando emitas o recibas un recibo, o te califiquen, '
                                'el cliente aparecerá acá.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  height: 1.4,
                                ),
                              ),
                            )
                          else if (filtrados.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                'No hay coincidencias con “$_query”.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.textMuted),
                              ),
                            )
                          else
                            ...filtrados.map((c) {
                              final selected = _selectedUid == c.uid;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Material(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => setState(() {
                                      _selectedUid = c.uid;
                                      _selectedNombre = c.nombre;
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
                                              ? AppColors.prestador
                                              : const Color(0xFFE2E8F0),
                                          width: selected ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: AppColors.prestador
                                                .withOpacity(0.12),
                                            child: Text(
                                              c.nombre.isNotEmpty
                                                  ? c.nombre[0].toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                color: AppColors.prestador,
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
                                                  c.nombre,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                if (c.lastSummary.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    c.lastSummary,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          AppColors.textMuted,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            selected
                                                ? Icons.check_circle_rounded
                                                : Icons.circle_outlined,
                                            color: selected
                                                ? AppColors.prestador
                                                : Colors.grey.shade400,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          if (_selectedUid != null) ...[
                            const SizedBox(height: 20),
                            const Text(
                              '¿Cómo fue trabajar con este cliente?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Solo señales positivas o neutras. Ayuda a la reciprocidad.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (i) {
                                final v = i + 1;
                                return IconButton(
                                  iconSize: 36,
                                  onPressed: () =>
                                      setState(() => _estrellas = v),
                                  icon: Icon(
                                    _estrellas >= v
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    color: const Color(0xFFFFB000),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _tagOptions.map((t) {
                                final on = _tags.contains(t);
                                return FilterChip(
                                  label: Text(t),
                                  selected: on,
                                  onSelected: (sel) {
                                    setState(() {
                                      if (sel) {
                                        _tags.add(t);
                                      } else {
                                        _tags.remove(t);
                                      }
                                    });
                                  },
                                  selectedColor:
                                      AppColors.prestador.withOpacity(0.2),
                                  checkmarkColor: AppColors.prestador,
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _comentarioCtrl,
                              maxLength: 200,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: 'Comentario (opcional)',
                                hintText: 'Ej. llegó a tiempo, fue claro…',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.prestador,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _enviando ? null : _enviar,
                            child: _enviando
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Enviar evaluación',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _ClienteItem {
  final String uid;
  final String nombre;
  final String convId;
  final String lastSummary;

  _ClienteItem({
    required this.uid,
    required this.nombre,
    required this.convId,
    required this.lastSummary,
  });
}
