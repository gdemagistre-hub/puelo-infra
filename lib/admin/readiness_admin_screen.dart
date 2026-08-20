import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../readiness/readiness_service.dart';
import '../scoring_service.dart';
import '../user_session.dart';

/// Tablero admin: madurez para microcrédito (solo lectura + recalcular).
class ReadinessAdminScreen extends StatefulWidget {
  const ReadinessAdminScreen({super.key});

  static bool get puedeAcceder {
    final data = UserSession().datosCompletos;
    if (data == null) return false;
    return data['es_admin'] == true || data['rol'] == 'admin';
  }

  @override
  State<ReadinessAdminScreen> createState() => _ReadinessAdminScreenState();
}

class _ReadinessAdminScreenState extends State<ReadinessAdminScreen> {
  static const _primary = Color(0xFF3D4756);
  static const _bg = Color(0xFFF8FAFC);

  String _filtroBucket = 'todos'; // todos | lejos | casi | listo
  bool? _filtroAcademia; // null = todos, true = ok, false = no
  bool _loading = true;
  bool _batchRunning = false;
  String? _error;
  String? _batchMsg;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];

  @override
  void initState() {
    super.initState();
    if (!ReadinessAdminScreen.puedeAcceder) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Acceso restringido')),
        );
        Navigator.pop(context);
      });
      return;
    }
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Preferir orden por readiness si el campo existe en la mayoría.
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await FirebaseFirestore.instance
            .collection('usuarios')
            .orderBy('readiness_microcredito', descending: true)
            .limit(120)
            .get();
      } catch (_) {
        snap = await FirebaseFirestore.instance
            .collection('usuarios')
            .limit(120)
            .get();
      }
      _docs = snap.docs;
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'No se pudo leer usuarios: $e';
        });
      }
    }
  }

  Future<void> _recalcular() async {
    if (_batchRunning) return;
    setState(() {
      _batchRunning = true;
      _batchMsg = null;
    });
    try {
      final r = await ReadinessService.recalcularTodos(maxUsers: 600);
      final msg =
          'Readiness OK: ${r.actualizados}/${r.procesados} · ${r.duracionMs} ms'
          '${r.errores.isEmpty ? '' : ' · ${r.errores.first}'}';
      if (!mounted) return;
      setState(() => _batchMsg = msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 8)),
      );
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _batchMsg = 'Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Batch falló: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _batchRunning = false);
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _filtrados {
    return _docs.where((doc) {
      final d = doc.data();
      final bucket = (d['readiness_bucket'] ?? '').toString();
      if (_filtroBucket != 'todos' && bucket != _filtroBucket) return false;
      if (_filtroAcademia != null) {
        final ac = d['readiness_academia'];
        final ok = ac is Map && ac['ok'] == true;
        if (ok != _filtroAcademia) return false;
      }
      return true;
    }).toList();
  }

  Color _bucketColor(String b) {
    switch (b) {
      case 'listo':
        return const Color(0xFF16A34A);
      case 'casi':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Madurez microcrédito',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading || _batchRunning ? null : _cargar,
          ),
        ],
      ),
      body: !ReadinessAdminScreen.puedeAcceder
          ? const Center(child: Text('Acceso denegado'))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: _cargar,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        _toolbar(),
                        if (_batchMsg != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: SelectableText(
                              _batchMsg!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _cargar,
                            child: _filtrados.isEmpty
                                ? ListView(
                                    children: const [
                                      SizedBox(height: 80),
                                      Center(
                                        child: Text(
                                          'Sin usuarios en este filtro.\n'
                                          'Corré “Recalcular readiness”.',
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 4, 16, 32),
                                    itemCount: _filtrados.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (context, i) {
                                      return _row(_filtrados[i]);
                                    },
                                  ),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _toolbar() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Readiness 0–100 (KYC + actividad). Academia solo indica '
            'preparación financiera (no suma puntos).',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _batchRunning ? null : _recalcular,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF28B5CD),
              foregroundColor: Colors.white,
            ),
            icon: _batchRunning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.calculate_outlined, size: 20),
            label: Text(
              _batchRunning ? 'Recalculando…' : 'Recalcular readiness',
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('Todos', _filtroBucket == 'todos', () {
                  setState(() => _filtroBucket = 'todos');
                }),
                _chip('Lejos', _filtroBucket == 'lejos', () {
                  setState(() => _filtroBucket = 'lejos');
                }),
                _chip('Casi', _filtroBucket == 'casi', () {
                  setState(() => _filtroBucket = 'casi');
                }),
                _chip('Listo', _filtroBucket == 'listo', () {
                  setState(() => _filtroBucket = 'listo');
                }),
                const SizedBox(width: 8),
                _chip(
                  'Academia ✓',
                  _filtroAcademia == true,
                  () {
                    setState(() {
                      _filtroAcademia =
                          _filtroAcademia == true ? null : true;
                    });
                  },
                ),
                _chip(
                  'Academia ✗',
                  _filtroAcademia == false,
                  () {
                    setState(() {
                      _filtroAcademia =
                          _filtroAcademia == false ? null : false;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFF28B5CD).withOpacity(0.2),
        checkmarkColor: const Color(0xFF1A8FA3),
      ),
    );
  }

  Widget _row(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final nombre =
        '${d['nombre'] ?? ''} ${d['apellido'] ?? ''}'.trim();
    final score = (d['readiness_microcredito'] is num)
        ? (d['readiness_microcredito'] as num).toInt()
        : 0;
    final bucket = (d['readiness_bucket'] ?? 'lejos').toString();
    final next = (d['readiness_next_step'] ?? '—').toString();
    final ac = d['readiness_academia'];
    final acOk = ac is Map && ac['ok'] == true;
    final acN = ac is Map && ac['n_capsulas'] is num
        ? (ac['n_capsulas'] as num).toInt()
        : 0;
    final badge = (d['list_badge'] ?? d['badge_prestador'] ?? '').toString();
    final oferta = d['readiness_oferta_elegible'] == true;
    final bc = _bucketColor(bucket);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _detalle(doc.id, d),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      nombre.isEmpty ? doc.id : nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: bc.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$score · $bucket',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: bc,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (badge.isNotEmpty)
                    Text(
                      ScoringService.labelBadge(badge),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const Spacer(),
                  Icon(
                    acOk ? Icons.school : Icons.school_outlined,
                    size: 16,
                    color: acOk
                        ? const Color(0xFF16A34A)
                        : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Academia $acN/${ReadinessService.academiaMinRequeridas}',
                    style: TextStyle(
                      fontSize: 11,
                      color: acOk
                          ? const Color(0xFF16A34A)
                          : Colors.grey.shade600,
                    ),
                  ),
                  if (oferta) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.verified, size: 16, color: Color(0xFF28B5CD)),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                next,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _detalle(String uid, Map<String, dynamic> d) {
    final detalle = d['readiness_detalle'];
    final map = detalle is Map
        ? Map<String, dynamic>.from(detalle)
        : <String, dynamic>{};
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            24 + MediaQuery.of(ctx).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${d['nombre'] ?? ''} ${d['apellido'] ?? ''}'.trim().isEmpty
                    ? uid
                    : '${d['nombre']} ${d['apellido']}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Readiness ${d['readiness_microcredito'] ?? 0} · '
                '${d['readiness_bucket'] ?? '—'}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              if (map.isEmpty)
                const Text('Sin detalle. Recalculá readiness.')
              else
                ...map.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.key,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text('${e.value}'),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 12),
              Text(
                'Próximo paso: ${d['readiness_next_step'] ?? '—'}',
                style: const TextStyle(height: 1.35),
              ),
              const SizedBox(height: 8),
              Text(
                'Oferta elegible: '
                '${d['readiness_oferta_elegible'] == true ? 'Sí' : 'No'} '
                '(score ≥ 70 y Academia OK)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await ReadinessService.recalcularUid(uid);
                    await _cargar();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Usuario recalculado')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                child: const Text('Recalcular este usuario'),
              ),
            ],
          ),
        );
      },
    );
  }
}
