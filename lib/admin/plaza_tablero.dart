import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Tablero de plaza. Lee solo stats/plaza_diaria/dias (admin).
class PlazaTablero extends StatefulWidget {
  const PlazaTablero({super.key, this.generation = 0});

  final int generation;

  @override
  State<PlazaTablero> createState() => _PlazaTableroState();
}

class _PlazaTableroState extends State<PlazaTablero> {
  static const Color _ink = Color(0xFF1E293B);
  static const Color _teal = Color(0xFF28B5CD);
  static const Color _muted = Color(0xFF64748B);

  bool _loading = true;
  String? _error;
  List<_Dia> _dias = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(PlazaTablero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.generation != widget.generation) _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('stats')
          .doc('plaza_diaria')
          .collection('dias')
          .orderBy(FieldPath.documentId, descending: true)
          .limit(21)
          .get();
      final dias = snap.docs.map(_Dia.fromDoc).toList();
      if (!mounted) return;
      setState(() {
        _dias = dias;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo leer el tablero';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _teal.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plaza',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: _ink,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Pilar · día cerrado a las 02:30',
            style: TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_error != null)
            Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)))
          else if (_dias.isEmpty)
            const Text(
              'Todavía no hay un día cerrado. El batch de las 02:30 escribe el día anterior.',
              style: TextStyle(fontSize: 13, height: 1.35, color: _ink),
            )
          else ...[
            _comparacion(),
            const SizedBox(height: 16),
            const Text(
              'Últimos 14 días',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _ink),
            ),
            const SizedBox(height: 8),
            _tabla(),
            const SizedBox(height: 16),
            const Text(
              'Zonas',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _ink),
            ),
            const SizedBox(height: 8),
            ..._filasZona(),
          ],
        ],
      ),
    );
  }

  _Dia get _hoy => _dias.first;

  _Dia? get _semana {
    final wanted = _sumarDias(_hoy.ymd, -7);
    for (final d in _dias) {
      if (d.ymd == wanted) return d;
    }
    return null;
  }

  Widget _comparacion() {
    final prev = _semana;
    final items = [
      _cmp('Altas', _hoy.altas, prev?.altas),
      _cmp('Activos', _hoy.activos, prev?.activos),
      _cmp('Búsquedas', _hoy.busquedas, prev?.busquedas),
      _cmp('Contactos', _hoy.contactos, prev?.contactos),
      _cmp('Comprobantes', _hoy.comprobantes, prev?.comprobantes),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _fmt(_hoy.ymd),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink),
        ),
        const SizedBox(height: 2),
        Text(
          prev == null
              ? 'Sin el mismo día de la semana anterior'
              : 'Contra ${_fmt(prev.ymd)}',
          style: const TextStyle(fontSize: 11, color: _muted),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: items),
      ],
    );
  }

  Widget _cmp(String label, int value, int? prev) {
    String delta = '—';
    Color color = _muted;
    if (prev != null) {
      final d = value - prev;
      delta = d > 0 ? '+$d' : '$d';
      color = d > 0 ? const Color(0xFF15803D) : (d < 0 ? const Color(0xFFB45309) : _muted);
    }
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _muted)),
          const SizedBox(height: 2),
          Text(
            '$value',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink),
          ),
          Text(delta, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _tabla() {
    final rows = _dias.take(14).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 32,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 36,
        columnSpacing: 16,
        headingTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _muted),
        dataTextStyle: const TextStyle(fontSize: 12, color: _ink),
        columns: const [
          DataColumn(label: Text('Día')),
          DataColumn(label: Text('Altas'), numeric: true),
          DataColumn(label: Text('Activos'), numeric: true),
          DataColumn(label: Text('Búsquedas'), numeric: true),
          DataColumn(label: Text('Contactos'), numeric: true),
          DataColumn(label: Text('Comprob.'), numeric: true),
        ],
        rows: rows
            .map(
              (d) => DataRow(cells: [
                DataCell(Text(_fmt(d.ymd))),
                DataCell(Text('${d.altas}')),
                DataCell(Text('${d.activos}')),
                DataCell(Text('${d.busquedas}')),
                DataCell(Text('${d.contactos}')),
                DataCell(Text('${d.comprobantes}')),
              ]),
            )
            .toList(),
      ),
    );
  }

  List<Widget> _filasZona() {
    final ventana = _dias.take(14).toList();
    final nombres = <String>{'Pilar'};
    for (final d in ventana) {
      nombres.addAll(d.zonas.keys);
    }
    final ordered = nombres.toList()
      ..sort((a, b) {
        if (a == 'Pilar') return -1;
        if (b == 'Pilar') return 1;
        return a.compareTo(b);
      });
    return ordered.map((n) => _filaZona(n, ventana)).toList();
  }

  Widget _filaZona(String nombre, List<_Dia> ventana) {
    final luz = _semaforo(nombre, ventana);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: luz.color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink),
                ),
                Text(
                  luz.motivo,
                  style: const TextStyle(fontSize: 12, height: 1.3, color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _Luz _semaforo(String zona, List<_Dia> ventana) {
    final saltos = <int>[];
    var busquedas = 0;
    var contactos = 0;
    final oficios = <String, int>{};
    Map<String, int> stock = {};
    var visto = false;
    for (final d in ventana) {
      final z = d.zonas[zona];
      if (z == null) continue;
      visto = true;
      saltos.addAll(z.saltoDias);
      busquedas += z.busquedas;
      contactos += z.contactos;
      z.oficiosBuscados.forEach((k, v) => oficios[k] = (oficios[k] ?? 0) + v);
    }
    for (final d in ventana) {
      final z = d.zonas[zona];
      if (z == null) continue;
      stock = z.stockOficio;
      break;
    }
    if (!visto || saltos.isEmpty) {
      return const _Luz(
        Color(0xFFCBD5E1),
        'Sin vínculos de invitación: no se puede medir el salto.',
      );
    }
    final med = _median(saltos);
    final faltan = oficios.keys.where((id) => (stock[id] ?? 0) <= 0).toList();
    final ratio = busquedas == 0 ? null : contactos / busquedas;
    final hopOk = med <= 7;
    final oficioOk = oficios.isNotEmpty && faltan.isEmpty;
    final contactoOk = ratio != null && ratio >= 0.5;
    if (hopOk && oficioOk && contactoOk) {
      return _Luz(
        const Color(0xFF16A34A),
        'Salto $med días, oficios cubiertos y al menos la mitad de las búsquedas tuvo contacto.',
      );
    }
    final partes = <String>[];
    if (med > 7) partes.add('salto $med días');
    if (oficios.isEmpty) {
      partes.add('sin búsquedas');
    } else if (faltan.isNotEmpty) {
      partes.add('faltan prestadores completos');
    }
    if (ratio == null) {
      partes.add('sin búsquedas para medir contacto');
    } else if (ratio < 0.5) {
      partes.add('contacto ${(ratio * 100).round()}%');
    }
    final malo = med > 14 || faltan.isNotEmpty || (ratio != null && ratio < 0.25);
    return _Luz(
      malo ? const Color(0xFFDC2626) : const Color(0xFFD97706),
      partes.isEmpty ? 'Todavía no cierra el semáforo.' : partes.join(' · '),
    );
  }
}

class _Luz {
  const _Luz(this.color, this.motivo);
  final Color color;
  final String motivo;
}

class _Zona {
  _Zona({
    required this.busquedas,
    required this.contactos,
    required this.saltoDias,
    required this.oficiosBuscados,
    required this.stockOficio,
  });

  final int busquedas;
  final int contactos;
  final List<int> saltoDias;
  final Map<String, int> oficiosBuscados;
  final Map<String, int> stockOficio;

  static _Zona fromMap(Map<String, dynamic> m) {
    return _Zona(
      busquedas: _n(m['busquedas']),
      contactos: _n(m['contactos']),
      saltoDias: _ints(m['salto_dias']),
      oficiosBuscados: _map(m['oficios_buscados']),
      stockOficio: _map(m['stock_completos_por_oficio']),
    );
  }
}

class _Dia {
  _Dia({
    required this.ymd,
    required this.altas,
    required this.activos,
    required this.busquedas,
    required this.contactos,
    required this.comprobantes,
    required this.zonas,
  });

  final String ymd;
  final int altas;
  final int activos;
  final int busquedas;
  final int contactos;
  final int comprobantes;
  final Map<String, _Zona> zonas;

  static _Dia fromDoc(QueryDocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    final raw = m['zonas'];
    final zonas = <String, _Zona>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is Map) {
          zonas[k.toString()] = _Zona.fromMap(Map<String, dynamic>.from(v));
        }
      });
    }
    return _Dia(
      ymd: (m['ymd'] ?? doc.id).toString(),
      altas: _n(m['altas']),
      activos: _n(m['activos']),
      busquedas: _n(m['busquedas']),
      contactos: _n(m['contactos']),
      comprobantes: _n(m['comprobantes_confirmados']),
      zonas: zonas,
    );
  }
}

int _n(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

List<int> _ints(dynamic v) {
  if (v is! List) return const [];
  return v.map(_n).toList();
}

Map<String, int> _map(dynamic v) {
  if (v is! Map) return const {};
  final out = <String, int>{};
  v.forEach((k, val) => out[k.toString()] = _n(val));
  return out;
}

int _median(List<int> values) {
  final nums = List<int>.from(values)..sort();
  if (nums.isEmpty) return 0;
  final mid = nums.length ~/ 2;
  if (nums.length.isOdd) return nums[mid];
  return ((nums[mid - 1] + nums[mid]) / 2).round();
}

String _sumarDias(String ymd, int delta) {
  if (ymd.length != 8) return '';
  final d = DateTime.utc(
    int.parse(ymd.substring(0, 4)),
    int.parse(ymd.substring(4, 6)),
    int.parse(ymd.substring(6, 8)),
  ).add(Duration(days: delta));
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}$m$day';
}

String _fmt(String ymd) {
  if (ymd.length != 8) return ymd;
  return '${ymd.substring(6, 8)}/${ymd.substring(4, 6)}';
}
