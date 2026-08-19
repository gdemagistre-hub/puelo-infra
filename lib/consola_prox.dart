import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'scoring_service.dart';
import 'user_session.dart';

/// Consola de monitoreo Prox.
///
/// Seguridad:
/// - Solo entra si `UserSession.datosCompletos['es_admin'] == true`.
/// - No muestra PII (nombres, teléfonos, emails).
/// - Lectura acotada (últimos eventos, límite duro).
/// - Las reglas de Firestore deben denegar lectura de analytics a no-admin
///   cuando exista Firebase Auth + claim/campo admin verificado en servidor.
class ConsolaProxWidget extends StatefulWidget {
  const ConsolaProxWidget({super.key});

  static const String routeName = 'ConsolaProx';
  static const String routePath = '/consolaProx';

  /// Gate client-side. Complementar siempre con reglas Firestore.
  static bool get puedeAcceder {
    final data = UserSession().datosCompletos;
    if (data == null) return false;
    if (data['es_admin'] == true) return true;
    if (data['rol'] == 'admin') return true;
    return false;
  }

  @override
  State<ConsolaProxWidget> createState() => _ConsolaProxWidgetState();
}

class _ConsolaProxWidgetState extends State<ConsolaProxWidget> {
  static const Color _primary = Color(0xFF3D4756);
  static const Color _bg = Color(0xFFF8FAFC);

  bool _loading = true;
  String? _error;
  List<QueryDocumentSnapshot> _events = [];

  // Agregados en cliente sobre la muestra reciente (no es warehouse).
  final Map<String, int> _viewsByScreen = {};
  final Map<String, List<int>> _loadMsByScreen = {};
  final Map<String, List<int>> _dwellMsByScreen = {};
  final Map<String, int> _lastScreenCounts = {};
  final Map<String, int> _actions = {};
  final Map<String, int> _errorsByScreen = {};
  int _sessionStarts = 0;
  int _sessionEnds = 0;

  // Scoring batch (Phase 1)
  bool _batchRunning = false;
  String? _batchMsg;

  @override
  void initState() {
    super.initState();
    if (!ConsolaProxWidget.puedeAcceder) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Acceso restringido')),
          );
          Navigator.pop(context);
        }
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
      final snap = await FirebaseFirestore.instance
          .collection('analytics_events')
          .orderBy('client_ts', descending: true)
          .limit(400)
          .get();

      _events = snap.docs;
      _recompute();

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'No se pudieron leer eventos. Verificá reglas Firestore e índice '
              'en client_ts. Detalle técnico solo en logs de admin.';
        });
      }
      debugPrint('ConsolaProx load error: $e');
    }
  }

  void _recompute() {
    _viewsByScreen.clear();
    _loadMsByScreen.clear();
    _dwellMsByScreen.clear();
    _lastScreenCounts.clear();
    _actions.clear();
    _errorsByScreen.clear();
    _sessionStarts = 0;
    _sessionEnds = 0;

    for (final doc in _events) {
      final d = doc.data() as Map<String, dynamic>;
      final type = (d['type'] ?? '').toString();

      switch (type) {
        case 'screen_view':
          final s = (d['screen'] ?? '?').toString();
          _viewsByScreen[s] = (_viewsByScreen[s] ?? 0) + 1;
          break;
        case 'screen_timing':
          final s = (d['screen'] ?? '?').toString();
          final ms = (d['load_ms'] as num?)?.toInt();
          if (ms != null) {
            _loadMsByScreen.putIfAbsent(s, () => []).add(ms);
          }
          break;
        case 'screen_exit':
          final s = (d['screen'] ?? '?').toString();
          final ms = (d['dwell_ms'] as num?)?.toInt();
          if (ms != null) {
            _dwellMsByScreen.putIfAbsent(s, () => []).add(ms);
          }
          break;
        case 'session_end':
          _sessionEnds++;
          final last = (d['last_screen'] ?? '').toString();
          if (last.isNotEmpty) {
            _lastScreenCounts[last] = (_lastScreenCounts[last] ?? 0) + 1;
          }
          break;
        case 'session_start':
          _sessionStarts++;
          break;
        case 'action':
          final name = (d['name'] ?? '?').toString();
          _actions[name] = (_actions[name] ?? 0) + 1;
          break;
        case 'error':
          final s = (d['screen'] ?? '?').toString();
          _errorsByScreen[s] = (_errorsByScreen[s] ?? 0) + 1;
          break;
      }
    }
  }

  int? _p95(List<int> values) {
    if (values.isEmpty) return null;
    final sorted = List<int>.from(values)..sort();
    final idx = ((sorted.length - 1) * 0.95).round();
    return sorted[idx.clamp(0, sorted.length - 1)];
  }

  int? _avg(List<int> values) {
    if (values.isEmpty) return null;
    return (values.reduce((a, b) => a + b) / values.length).round();
  }

  Future<void> _runScoringBatch({bool force = false}) async {
    if (_batchRunning) return;
    setState(() {
      _batchRunning = true;
      _batchMsg = null;
    });
    try {
      final r = await ScoringService.ejecutarBatchDiario(
        trigger: 'manual_admin',
        force: force,
      );
      final msg =
          'Scoring ${r.status}: ${r.actualizados}/${r.procesados} usuarios · '
          'run ${r.runId}'
          '${r.errores.isEmpty ? '' : ' · errores: ${r.errores.length}'}';
      if (!mounted) return;
      setState(() => _batchMsg = msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      final msg = 'Batch falló: $e';
      if (!mounted) return;
      setState(() => _batchMsg = msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
      );
      debugPrint('ConsolaProx batch: $e');
    } finally {
      if (mounted) setState(() => _batchRunning = false);
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
          'Consola Prox',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _cargar,
          ),
        ],
      ),
      body: !ConsolaProxWidget.puedeAcceder
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
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: _cargar,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _bannerSeguridad(),
                          const SizedBox(height: 12),
                          _scoringBatchCard(),
                          const SizedBox(height: 12),
                          _kpiRow(),
                          const SizedBox(height: 20),
                          _sectionTitle('Demora de carga (p95 / avg ms)'),
                          _timingTable(),
                          const SizedBox(height: 20),
                          _sectionTitle('Tiempo en pantalla (avg dwell ms)'),
                          _dwellTable(),
                          const SizedBox(height: 20),
                          _sectionTitle('Ultima pantalla antes de abandonar'),
                          _rankingMap(_lastScreenCounts),
                          const SizedBox(height: 20),
                          _sectionTitle('Vistas por pantalla'),
                          _rankingMap(_viewsByScreen),
                          const SizedBox(height: 20),
                          _sectionTitle('Acciones'),
                          _rankingMap(_actions),
                          const SizedBox(height: 20),
                          _sectionTitle('Errores por pantalla'),
                          _errorsByScreen.isEmpty
                              ? _empty('Sin errores en la muestra')
                              : _rankingMap(_errorsByScreen),
                          const SizedBox(height: 20),
                          Text(
                            'Muestra: ${_events.length} eventos recientes. '
                            'No incluye datos personales.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
    );
  }

  Widget _scoringBatchCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF28B5CD).withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scoring batch',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Recalcula badges, scores y exporta features_v1 a la '
            'coleccion scoring_features (Phase 1 / Vertex). '
            'Solo admin. Puede tardar 1-3 min.',
            style: TextStyle(fontSize: 12, height: 1.35, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _batchRunning ? null : () => _runScoringBatch(),
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
                      : const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text(
                    _batchRunning ? 'Corriendo...' : 'Correr scoring 1x',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed:
                    _batchRunning ? null : () => _runScoringBatch(force: true),
                child: const Text('Force'),
              ),
            ],
          ),
          if (_batchMsg != null) ...[
            const SizedBox(height: 10),
            Text(
              _batchMsg!,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade800),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bannerSeguridad() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: const Text(
        'Solo administradores. Los eventos no guardan nombre, email, '
        'telefono ni documento. Aplica firestore.rules en el proyecto '
        'para bloquear lecturas a usuarios no admin.',
        style: TextStyle(fontSize: 12, height: 1.35, color: Color(0xFF9A3412)),
      ),
    );
  }

  Widget _kpiRow() {
    return Row(
      children: [
        Expanded(child: _kpiCard('Session start', '$_sessionStarts')),
        const SizedBox(width: 10),
        Expanded(child: _kpiCard('Session end', '$_sessionEnds')),
        const SizedBox(width: 10),
        Expanded(child: _kpiCard('Eventos', '${_events.length}')),
      ],
    );
  }

  Widget _kpiCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          t,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
      );

  Widget _empty(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: TextStyle(color: Colors.grey.shade600)),
      );

  Widget _timingTable() {
    if (_loadMsByScreen.isEmpty) return _empty('Sin timings aún');
    final keys = _loadMsByScreen.keys.toList()
      ..sort((a, b) =>
          (_p95(_loadMsByScreen[b]!) ?? 0)
              .compareTo(_p95(_loadMsByScreen[a]!) ?? 0));

    return _card(
      child: Column(
        children: keys.map((s) {
          final list = _loadMsByScreen[s]!;
          return _row3(s, 'p95 ${_p95(list)} ms', 'avg ${_avg(list)} ms');
        }).toList(),
      ),
    );
  }

  Widget _dwellTable() {
    if (_dwellMsByScreen.isEmpty) return _empty('Sin dwell aún');
    final keys = _dwellMsByScreen.keys.toList()
      ..sort((a, b) =>
          (_avg(_dwellMsByScreen[b]!) ?? 0)
              .compareTo(_avg(_dwellMsByScreen[a]!) ?? 0));

    return _card(
      child: Column(
        children: keys.map((s) {
          final list = _dwellMsByScreen[s]!;
          return _row3(s, 'avg ${_avg(list)} ms', 'n=${list.length}');
        }).toList(),
      ),
    );
  }

  Widget _rankingMap(Map<String, int> map) {
    if (map.isEmpty) return _empty('Sin datos');
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _card(
      child: Column(
        children: entries
            .take(12)
            .map((e) => _row3(e.key, '${e.value}', ''))
            .toList(),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
        ],
      ),
      child: child,
    );
  }

  Widget _row3(String a, String b, String c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              a,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              b,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
          if (c.isNotEmpty)
            SizedBox(
              width: 72,
              child: Text(
                c,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
        ],
      ),
    );
  }
}
