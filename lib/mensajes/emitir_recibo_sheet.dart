import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../mis_numeros/ui/thousands_formatter.dart';
import '../theme/prox_sounds.dart';
import '../user_session.dart';
import 'mensajes_service.dart';

class _Sugerencia {
  final String uid;
  final String nombre;
  final String origen; // conversacion | contacto
  const _Sugerencia({
    required this.uid,
    required this.nombre,
    this.origen = 'conversacion',
  });
}

class EmitirReciboSheet extends StatefulWidget {
  /// Si ya estás en un hilo / tarjeta, pasá la contraparte.
  final String? contraparteUidFijo;
  final String? contraparteNombre;

  const EmitirReciboSheet({
    super.key,
    this.contraparteUidFijo,
    this.contraparteNombre,
  });

  @override
  State<EmitirReciboSheet> createState() => _EmitirReciboSheetState();
}

class _EmitirReciboSheetState extends State<EmitirReciboSheet> {
  final _uidCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  final _uidFocus = FocusNode();
  String _concepto = 'sena';
  bool _loading = false;
  String? _error;
  String? _nombreResuelto;
  /// UID real de la contraparte (el TextField muestra el nombre legible).
  String? _selectedUid;

  List<_Sugerencia> _todas = [];
  List<_Sugerencia> _filtradas = [];
  bool _cargandoSugerencias = false;
  bool _mostrarLista = false;

  static const _conceptos = [
    ('sena', 'Seña'),
    ('anticipo', 'Anticipo'),
    ('saldo', 'Saldo'),
    ('pago_total', 'Pago total'),
    ('otro', 'Otro'),
  ];

  bool get _fijo =>
      widget.contraparteUidFijo != null &&
      widget.contraparteUidFijo!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_fijo) {
      _selectedUid = widget.contraparteUidFijo!.trim();
      _nombreResuelto = widget.contraparteNombre?.trim();
      if (_nombreResuelto != null && _nombreResuelto!.isNotEmpty) {
        _uidCtrl.text = _nombreResuelto!;
      } else {
        _uidCtrl.text = ''; // se completa al resolver nombre
        _resolverNombre(_selectedUid!);
      }
    } else {
      _uidFocus.addListener(() {
        if (_uidFocus.hasFocus) {
          setState(() => _mostrarLista = true);
        }
      });
      _cargarSugerencias();
    }
  }

  Future<void> _cargarSugerencias() async {
    final myUid = UserSession().uid;
    if (myUid == null || myUid.isEmpty) return;
    setState(() => _cargandoSugerencias = true);

    final seen = <String>{};
    final list = <_Sugerencia>[];

    try {
      // 1) Conversaciones existentes (recibos / evaluaciones)
      try {
        final snap = await FirebaseFirestore.instance
            .collection('conversaciones')
            .where('participantes', arrayContains: myUid)
            .orderBy('last_event_at', descending: true)
            .limit(25)
            .get();

        for (final doc in snap.docs) {
          final data = doc.data();
          final other = MensajesService.otherParticipantUid(
            myUid: myUid,
            convId: doc.id,
            data: data,
          );
          if (other == null || other.isEmpty || other == myUid) continue;
          if (seen.contains(other)) continue;
          seen.add(other);

          String? nombre;
          for (final key in [
            'other_display_name',
            'contraparte_nombre',
            'cliente_nombre',
            'prestador_nombre',
          ]) {
            final v = (data[key] ?? '').toString().trim();
            if (v.isNotEmpty) {
              nombre = v;
              break;
            }
          }
          nombre ??= await MensajesService.instance.resolveDisplayName(other);
          list.add(_Sugerencia(
            uid: other,
            nombre: nombre,
            origen: 'conversacion',
          ));
        }
      } catch (e) {
        debugPrint('EmitirReciboSheet conversaciones: $e');
      }

      // Prestadores que yo contacté (soy cliente)
      try {
        final yoCliente = await FirebaseFirestore.instance
            .collection('contactos')
            .where('cliente_uid', isEqualTo: myUid)
            .limit(40)
            .get();
        for (final doc in yoCliente.docs) {
          final data = doc.data();
          final other = (data['prestador_uid'] ?? '').toString().trim();
          if (other.isEmpty || other == myUid) continue;
          if (seen.contains(other)) continue;
          seen.add(other);
          final hint = (data['prestador_nombre'] ?? '').toString().trim();
          final nombre = hint.isNotEmpty
              ? hint
              : await MensajesService.instance.resolveDisplayName(other);
          list.add(_Sugerencia(
            uid: other,
            nombre: nombre,
            origen: 'contacto',
          ));
        }
      } catch (e) {
        debugPrint('EmitirReciboSheet contactos cliente: $e');
      }

      // 2) Contactos de la app (WA / llamada hacia mí como prestador)
      try {
        final cSnap = await FirebaseFirestore.instance
            .collection('contactos')
            .where('prestador_uid', isEqualTo: myUid)
            .limit(40)
            .get();

        for (final doc in cSnap.docs) {
          final data = doc.data();
          final other = (data['cliente_uid'] ?? '').toString().trim();
          if (other.isEmpty || other == myUid) continue;
          if (seen.contains(other)) continue;
          seen.add(other);

          final nombre =
              await MensajesService.instance.resolveDisplayName(other);
          list.add(_Sugerencia(
            uid: other,
            nombre: nombre,
            origen: 'contacto',
          ));
        }
      } catch (e) {
        debugPrint('EmitirReciboSheet contactos: $e');
      }

      if (!mounted) return;
      setState(() {
        _todas = list;
        _filtradas = list;
        _cargandoSugerencias = false;
      });
    } catch (e) {
      debugPrint('EmitirReciboSheet._cargarSugerencias: $e');
      if (!mounted) return;
      setState(() => _cargandoSugerencias = false);
    }
  }

  void _filtrar(String raw) {
    final q = raw.trim().toLowerCase();
    // Al tipear se invalida la selección previa (nombre visible ≠ uid).
    _selectedUid = null;
    if (q.isEmpty) {
      setState(() {
        _filtradas = _todas;
        _nombreResuelto = null;
        _mostrarLista = true;
      });
      return;
    }
    final match = _todas.where((s) {
      return s.nombre.toLowerCase().contains(q) ||
          s.uid.toLowerCase().contains(q);
    }).toList();
    setState(() {
      _filtradas = match;
      _mostrarLista = true;
      _nombreResuelto = null;
    });
    // Si parece un UID pegado (largo, sin espacios), resolvemos nombre.
    if (q.length > 20 && !q.contains(' ')) {
      _selectedUid = raw.trim();
      _resolverNombre(raw.trim());
    }
  }

  void _elegir(_Sugerencia s) {
    _selectedUid = s.uid;
    // Mostrar nombre legible; el UID queda solo en _selectedUid.
    final label = s.nombre.trim().isNotEmpty ? s.nombre.trim() : s.uid;
    _uidCtrl.text = label;
    setState(() {
      _nombreResuelto = label;
      _mostrarLista = false;
      _error = null;
    });
    _uidFocus.unfocus();
  }

  Future<void> _resolverNombre(String uid) async {
    final n = await MensajesService.instance.resolveDisplayName(uid);
    if (!mounted) return;
    setState(() {
      _nombreResuelto = n;
      // En modo fijo, el campo también muestra el nombre (no el UID).
      if (_fijo && n.trim().isNotEmpty) {
        _uidCtrl.text = n;
      }
    });
  }

  @override
  void dispose() {
    _uidCtrl.dispose();
    _montoCtrl.dispose();
    _notaCtrl.dispose();
    _uidFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final uid = (_selectedUid ?? _uidCtrl.text).trim();
      final monto = ThousandsFormatter.parse(_montoCtrl.text);
      if (uid.isEmpty) {
        throw StateError('Elegí a quién le pagaste.');
      }
      // Si el campo tiene un nombre (no un UID) y no hay selección, pedir elegir de la lista.
      final pareceUid = uid.length > 20 && !uid.contains(' ');
      if (_selectedUid == null && !pareceUid && !_fijo) {
        throw StateError('Elegí una persona de la lista (o pegá su UID).');
      }
      if (monto == null || monto <= 0) throw StateError('Monto inválido');

      final res = await MensajesService.instance.emitirRecibo(
        contraparteUid: _selectedUid ?? uid,
        monto: monto,
        concepto: _concepto,
        nota: _notaCtrl.text,
        origen: _fijo ? 'tarjeta' : 'mensajes',
      );
      if (!mounted) return;
      ProxSounds.playConfirm();
      // Snackbar antes del pop: el context del sheet se invalida al cerrar.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Comprobante enviado · esperando confirmación de la otra parte',
          ),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context, res);
    } catch (e) {
      setState(() {
        _error = e
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('StateError: ', '')
            .replaceFirst('FirebaseFunctionsException: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final paraLabel = (_nombreResuelto != null && _nombreResuelto!.isNotEmpty)
        ? _nombreResuelto!
        : (_fijo ? 'Cargando…' : null);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Doy un pago',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Registrás un comprobante de pago. Quien lo recibe lo confirma. '
              'No reemplaza factura. Queda sellado y no se puede editar.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            if (_fijo) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F7FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF28B5CD).withOpacity(0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, color: Color(0xFF1A8FA3)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Le pagás a',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            paraLabel ?? widget.contraparteUidFijo!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              TextField(
                controller: _uidCtrl,
                focusNode: _uidFocus,
                decoration: InputDecoration(
                  labelText: 'A quién le pagaste',
                  hintText: 'Buscá por nombre…',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person_search_outlined),
                  suffixIcon: _cargandoSugerencias
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : (_uidCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _uidCtrl.clear();
                                setState(() {
                                  _selectedUid = null;
                                  _nombreResuelto = null;
                                  _filtradas = _todas;
                                  _mostrarLista = true;
                                });
                              },
                            )
                          : null),
                ),
                onChanged: _filtrar,
                onTap: () => setState(() => _mostrarLista = true),
              ),
              if (_nombreResuelto != null &&
                  _nombreResuelto!.isNotEmpty &&
                  !_mostrarLista) ...[
                const SizedBox(height: 8),
                Text(
                  'Para: $_nombreResuelto',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A8FA3),
                  ),
                ),
              ],
              if (_mostrarLista) ...[
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: _filtradas.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            _todas.isEmpty
                                ? 'Todavía no hay contactos. '
                                    'Abrí la tarjeta del prestador y tocá WhatsApp o Doy un pago. '
                                    'También podés pegar el UID (está en su tarjeta).'
                                : 'Sin coincidencias. Probá otro nombre o pegá el UID.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              height: 1.35,
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _filtradas.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            color: Color(0xFFE2E8F0),
                          ),
                          itemBuilder: (context, i) {
                            final s = _filtradas[i];
                            final initial = s.nombre.isNotEmpty
                                ? s.nombre[0].toUpperCase()
                                : '?';
                            final tag = s.origen == 'contacto'
                                ? 'Contacto app'
                                : 'Conversación';
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                    const Color(0xFF28B5CD).withOpacity(0.15),
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1A8FA3),
                                  ),
                                ),
                              ),
                              title: Text(
                                s.nombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                tag,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              onTap: () => _elegir(s),
                            );
                          },
                        ),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                'Aparecen prestadores que contactaste, clientes que te contactaron y conversaciones. '
                'También podés pegar un UID.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _montoCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                ThousandsFormatter(allowDecimal: true),
              ],
              decoration: const InputDecoration(
                labelText: 'Monto (ARS)',
                prefixText: r'$ ',
                hintText: '15.000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Concepto', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _conceptos.map((c) {
                final id = c.$1;
                final label = c.$2;
                final sel = _concepto == id;
                return ChoiceChip(
                  label: Text(label),
                  selected: sel,
                  onSelected: (_) => setState(() => _concepto = id),
                  selectedColor: const Color(0xFF28B5CD).withOpacity(0.2),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notaCtrl,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF28B5CD),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Registrar comprobante',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
